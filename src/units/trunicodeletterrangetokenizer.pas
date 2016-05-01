{
  This file is part of texrex.
  Maintained by Roland Schäfer.
  http://texrex.sourceforge.net/

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

}


unit TrUnicodeLetterRangeTokenizer;

{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  StrUtils,
  SysUtils,
  IniFiles,
  Classes,
  TrUtilities,
  TrData,
  TrDocumentProcessor;


type

  ETrUnicodeLetterRangeTokenizer = class(Exception);

  TTrTokenizerState = (
    ttsSearching,
    ttsReadingToken
  );


  TTrLetterRange = packed record
    Lo : Int64;
    Hi : Int64;
  end;
  TTrLetterRangeArray = array of TTrLetterRange;


  // A tokenizer for UTF8 (!!!) data which tokenizes a document into
  // letter sequences. Every non-letter (sequence) is a separator.
  TTrUnicodeLetterRangeTokenizer = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;
    procedure AddUnicodeLetterRange(const ALow : Int64;
      const AHigh : Int64);
    procedure ResetLetterRanges;

    // Convenience procedures to add Unicode Latin letter ranges.
    procedure AddLatinBase;
    procedure AddLatinSupplement;
    procedure AddLatinExtendedA;
    procedure AddLatinExtendedB;
    procedure AddLatinExtendedC;
    procedure AddLatinExtendedD;
    procedure AddLatinExtendedAdditional;
    procedure AddLatinLigatures;
    procedure AddLatinFullWidth;

    // This only sets Valid := false, never := true.
    // If already = false, then doc is ignored anyway.
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FLetterRanges : TTrLetterRangeArray;
    FCurrentDiv : TTrDiv;
    FOffset : Integer;
    FUtf8Buffer : String;
    FMaxBoilerplate : Real;
    FMinLength : Integer;

    procedure ConsumeNextUtf8Character; inline;
    function IsLetter : Boolean;
  published

    // These set accepatbility levels below which toknization is skipped
    // for a paragraph.
    property MaxBoilerplate : Real read FMaxBoilerplate
      write FMaxBoilerplate;
    property MinLength : Integer read FMinLength write FMinLength
      default 100;
  end;


implementation


constructor TTrUnicodeLetterRangeTokenizer.Create(
  const AIni : TIniFile);
begin
  FMaxBoilerplate := 1;
  ResetLetterRanges;
  AddLatinBase;
  AddLatinSupplement;
  AddLatinExtendedA;
  AddLatinExtendedB;
  AddLatinExtendedC;
  AddLatinExtendedAdditional;
  AddLatinLigatures;

  inherited Create(AIni);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddUnicodeLetterRange(
  const ALow : Int64; const AHigh : Int64);
begin
  if AHigh < ALow
  then Exit;

  SetLength(FLetterRanges, Length(FLetterRanges)+1);
  with FLetterRanges[High(FLetterRanges)]
  do begin
    Lo := ALow;
    Hi := AHigh;
  end;
end;


procedure TTrUnicodeLetterRangeTokenizer.ResetLetterRanges;
begin
  SetLength(FLetterRanges, 0);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinBase;
begin
  AddUnicodeLetterRange($0041, $005A);
  AddUnicodeLetterRange($0061, $007A);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinSupplement;
begin
  AddUnicodeLetterRange($00C0, $00FF);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinExtendedA;
begin
  AddUnicodeLetterRange($0100, $017F);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinExtendedB;
begin
  AddUnicodeLetterRange($0180, $024F);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinExtendedC;
begin
  AddUnicodeLetterRange($2C60, $2C7F);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinExtendedD;
begin
  AddUnicodeLetterRange($A720, $A78E);
  AddUnicodeLetterRange($A790, $A793);
  AddUnicodeLetterRange($A7A0, $A7AA);
  AddUnicodeLetterRange($A7F8, $A7FF);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinExtendedAdditional;
begin
  AddUnicodeLetterRange($1E00, $1EFF);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinLigatures;
begin
  AddUnicodeLetterRange($FB00, $FB06);
end;


procedure TTrUnicodeLetterRangeTokenizer.AddLatinFullWidth;
begin
  AddUnicodeLetterRange($FF21, $FF3A);
  AddUnicodeLetterRange($FF41, $FF5A);
end;


procedure TTrUnicodeLetterRangeTokenizer.Process(
  const ADocument : TTrDocument);
var
  i : Integer;
  LState : TTrTokenizerState = ttsSearching;
  LToken : String;
begin
  inherited;

  // Go through the paragraphs.
  for i := 0 to ADocument.Number-1
  do begin

    if (not ADocument[i].Valid)
    or (ADocument[i].BoilerplateScore > FMaxBoilerplate)
    or (ADocument[i].Size < FMinLength)
    then Continue;

    // Do not use broken paragraphs (Valid; like malformed encoding) or
    // ones which have been marked as boilerplate (Use) etc.
    if (not ADocument[i].Valid)
    then Continue;

    LState := ttsSearching;

    // Set Div.
    FCurrentDiv := ADocument[i];

    // Do not process invalid paragraphs.
    if (not FCurrentDiv.Valid)
    then Continue;

    // Strings are 1-based.
    FOffset := 1;
    while (FOffset <= FCurrentDiv.Size)
    do begin
      ConsumeNextUtf8Character;

      if IsLetter
      then begin

        // If we're searching, start a token, else continue a token.
        if LState = ttsSearching
        then begin
          LToken := FUtf8Buffer;
          LState := ttsReadingToken;
        end else LToken += FUtf8Buffer;

      // ... not a letter.
      end else begin

        // If we are not already reading a token, we ignore this.
        // If we are, we have reached its end.
        if LState = ttsReadingToken
        then begin
          ADocument.TypeTokenData.AddToken(LToken);
          LState := ttsSearching;
          LToken := '';
        end;

      end;

    end;

    // At paragraph end, always end a token in there was still
    // matherial gathered.
    if LToken <> ''
    then ADocument.TypeTokenData.AddToken(LToken);
  end;

  // Udate relative frequencies.
  ADocument.TypeTokenData.UpdateTypes;
end;


procedure TTrUnicodeLetterRangeTokenizer.ConsumeNextUtf8Character;
  inline;
var
  LOffset : Integer;
  LLength : Integer = 0;
  LStillExpecting : Integer = 0;
  LByteType : TUtf8Byte;
begin

  LOffset := FOffset;

  // Now read until valid UTF-8 sequence found.
  repeat

    LByteType := TrUtf8ByteType(FCurrentDiv.Text[FOffset]);

    // We are not expecting a follow-byte.
    if (LStillExpecting = 0)
    then begin
      case LByteType of
        tubOne : Inc(LLength);
        tubTwo :
        begin
          Inc(LLength);
          LStillExpecting := 1;
        end;
        tubThree :
        begin
          Inc(LLength);
          LStillExpecting := 2;
        end;
        tubFour :
        begin
          Inc(LLength);
          LStillExpecting := 3;
        end;
        // If we were not expecting a follow-byte and this was not a
        // starter byte, it is ill-formed. Delete and reset.
        else begin
          LStillExpecting := 0;
          LLength := 0;
        end;
      end; // esac

    // We are still expecting a follow-byte.
    end else begin
      if (LByteType = tubNext)
      then begin
        Dec(LStillExpecting);
        Inc(LLength);
      end

      // We were expecting a follow byte, but didn't find one.
      // Delete and reset.
      else begin
        LStillExpecting := 0;
        LLength := 0;
      end;

    // We can only be a follow-byte or not.
    end;

    // Always moce cursor right after we have examined a byte.
    Inc(FOffset);

  until (LStillExpecting = 0)
  or (FOffset > Length(FCurrentDiv.Text));

  // Write soemthing to the buffer if not empty.
  if LLength > 0
  then FUtf8Buffer := MidStr(FCurrentDiv.Text, LOffset, LLength);

end;


function TTrUnicodeLetterRangeTokenizer.IsLetter : Boolean;
var
  i : Integer;
  LCodepoint : Integer;
begin
  Result := false;
  for i := 0 to High(FLetterRanges)
  do begin
    LCodepoint := TrUtf8Codepoint(FUtf8Buffer);
    if (LCodepoint >= FLetterRanges[i].Lo)
    and (LCodepoint <= FLetterRanges[i].Hi)
    then begin
      Result := true;
      Break;
    end;
  end;
end;


class function TTrUnicodeLetterRangeTokenizer.Achieves :
  TTrPrerequisites;
begin
  Result := [trpreTokenized];
end;


class function TTrUnicodeLetterRangeTokenizer.Presupposes :
  TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8];
end;


end.
