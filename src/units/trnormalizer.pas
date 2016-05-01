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


unit TrNormalizer;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  Classes,
  IcuWrappers,
  IniFiles,
  TrUtilities,
  TrData,
  TrDocumentProcessor;


type

  ETrNormalizer = class(Exception);

  TTrReplacement = record
    Lhs : String;
    Rhs : String;
  end;
  TTrReplacementArray = array of TTrReplacement;

  // This is an abstract class that takes a TTrDocument and
  // processes it. All strippers, cleaners etc. inherit from this.
  TTrNormalizer = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;
    destructor Destroy; override;
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FReplacementFile : String;
    FReplacements : TTrReplacementArray;
    FSweepCodepoints : Boolean;
    FSweepIcu : TIcuRegex;
    FNilIcu : TIcuRegex;

    procedure SetReplacementFile(const AFile : String);
    procedure Metarator(var AKey : String; var AValue : String);
  published
    property SweepCodepoints : Boolean read FSweepCodepoints
      write FSweepCodepoints default true;
    property ReplacementFile : String read FReplacementFile
      write SetReplacementFile;
  end;



implementation



constructor TTrNormalizer.Create(const AIni : TIniFile);
const
  Illegal : Utf8String =
    '[\u0000-\u001f\u007f-\u009f\ud800-\udfff\ue000-\uf8ff\ufdd0-\ufdef\ufffd-\uffff\ufeff-\ufeff]';
begin
  inherited Create(AIni);
  FSweepIcu := TIcuRegex.Create(Illegal);
  FNilIcu := TIcuRegex.Create('^ *$');
end;


destructor TTrNormalizer.Destroy;
begin
  SetLength(FReplacements, 0);
  FreeAndNil(FSweepIcu);
  FreeAndNil(FNilIcu);
  inherited Destroy;
end;


procedure TTrNormalizer.Metarator(var AKey : String; var AValue : String);
var
  j : Integer;
begin
  for j := 0 to High(FReplacements)
  do AValue := StringReplace(AValue, FReplacements[j].Lhs,
      FReplacements[j].Rhs, [rfReplaceAll]);

  if FSweepCodepoints
  then AValue := FSweepIcu.Replace(AValue, ' ', true, false);
end;


procedure TTrNormalizer.Process(const ADocument : TTrDocument);
var
  i, j : Integer;
  Tmp : String;
begin
  inherited;

  // Normalize the paragraphs.
  for i := 0 to ADocument.Number-1
  do begin
    if not ADocument[i].Valid
    then Continue;

    for j := 0 to High(FReplacements)
    do ADocument[i].Text := StringReplace(ADocument[i].Text,
        FReplacements[j].Lhs, FReplacements[j].Rhs, [rfReplaceAll]);

    // All illegal codepoints that remain cannot be saved. Clean!
    if FSweepCodepoints
    then ADocument[i].Text := FSweepIcu.Replace(ADocument[i].Text, ' ', true,
      false);

    // This is important, or other processors might crash. Empty divs are
    // invalidated.
    if FNilIcu.Match(ADocument[i].Text, true, false)
    then ADocument[i].Valid := false;
  end;

  // Normalize metas.
  ADocument.Meta.Iterate(@self.Metarator);
end;


procedure TTrNormalizer.SetReplacementFile(const AFile : String);
var
  LLines : TStringArray;
  i, j : Integer;
  LSplit : TStringArray;
  LIsDouble : Boolean;
begin

  // Non-breaking space and zero-width space should always be deleted.
  SetLength(FReplacements, 2);
  with FReplacements[0]
  do begin
    Lhs := Utf8String(#194#160);
    Rhs := '';
  end;
  with FReplacements[1]
  do begin
    Lhs := Utf8String(#226#128#139);
    Rhs := '';
  end;

  FReplacementFile := AFile;

  // If file does not exist, just leave rules empty.
  if not TrFindFile(FReplacementFile)
  then begin
    TrDebug('Normalization file ' + FReplacementFile + ' not found.');
    Exit;
  end;

  TrLoadLinesFromFile(FReplacementFile, LLines);

  for i := 0 to High(LLines)
  do begin
    if  (Length(LLines[i]) > 0)
    and (LLines[i][1] <> '#')
    then begin
      LSplit := TrExplode(LLines[i], [#9]);

      // Only operate on lines with exactly 2 fields, ignore the rest.
      if (Length(LSplit) = 2)
      then begin

        // Check whether the LHS already exists.
        LIsDouble := false;
        for j := 0 to High(FReplacements)
        do LIsDouble := LIsDouble or (FReplacements[j].Lhs = LSplit[0]);

        if not LIsDouble
        then begin
          SetLength(FReplacements, Length(FReplacements)+1);
          with FReplacements[High(FReplacements)]
          do begin
            Lhs := LSplit[0];
            Rhs := LSplit[1];
          end;
        end;
      end;
    end;
  end;
end;



class function TTrNormalizer.Achieves : TTrPrerequisites;
begin
  Result := [];
end;


class function TTrNormalizer.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8];
end;


end.
