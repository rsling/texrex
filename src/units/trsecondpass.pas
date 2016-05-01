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



unit TrSecondPass;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  StrUtils,
  Classes,
  IniFiles,
  IcuWrappers,
  TrDocumentProcessor,
  TrData,
  TrEntityConverters,
  TrUtilities;


type
  ETrSecondPass = class(Exception);


  TTrSecondPass = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;

    // The call which cleans exactly one paragraph. Strings are assumed
    // to be UTF-8!
    destructor Destroy; override;
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected

    // The converter for entities.
    FEntityConverter : TTrUtf8EntityConverter;

    FCleanseTags : Boolean;
    FCleanseEmail : Boolean;
    FCleanseUri : Boolean;
    FCleanseHashtag : Boolean;

    FEmailReplacer : String;
    FUriReplacer : String;
    FHashtagReplacer : String;

    // Used internally for regexes in deep cleanser.
    FMatchTagIcu : TIcuRegex;
    FMatchEmailIcu : TIcuRegex;
    FMatchUriIcu : TIcuRegex;
    FMatchHashtagIcu : TIcuRegex;

    FMatchMultiSpaceIcu : TIcuRegex;

    FDoubleWashEntities : Boolean;

    procedure SetEmailReplacer(const AReplacer : String);
    procedure SetUriReplacer(const AReplacer : String);
    procedure SetHashtagReplacer(const AReplacer : String);

    // The refactored procedure which runs the regex-based replacements.
    // Returns the numbers of replacements in the out parameters.
    function Cleanse(const AIn : String;
      out ATagCount : Integer; out AEmailCount : Integer;
      out AUriCount : Integer; out AHashTagCount : Integer) : String;

    procedure Metarator(var AKey : String; var AValue : String);

  published
    property CleanseTags : Boolean read FCleanseTags
      write FCleanseTags default true;
    property CleanseEmail : Boolean read FCleanseEmail
      write FCleanseEmail default false;
    property CleanseUri : Boolean read FCleanseUri write FCleanseUri
       default false;
    property CleanseHashtag : Boolean read FCleanseHashtag
      write FCleanseHashtag default false;
    property EmailReplacer : String read FEmailReplacer
      write SetEmailReplacer;
    property UriReplacer : String read FUriReplacer
      write SetUriReplacer;
    property HashtagReplacer : String read FHashtagReplacer
      write SetHashtagReplacer;
    property DoubleWashEntities : Boolean read FDoubleWashEntities
      write FDoubleWashEntities default true;
  end;



implementation



var

  // These are quasi-constants, because there is no use making them
  // configurable: This component strips tags, emails and URIs.
  // Also, the deboilerplater depends on the way this is done.
  MatchTag     : Utf8String = ' *<[A-Za-z!?/][^>]*> *';
  MatchEmail   : Utf8String = ' *[\p{L}0-9._-]+\@[\p{L}0-9._-]+\.[\p{L}]{2,8} *';
  MatchUri     : Utf8String = ' *\p{L}{2,6}://[\p{L}\p{N}_/%$&,=?~#.+:;-]+[\p{L}\p{N}_/%$=?~#-] *| *www\.[\p{L}\p{N}_/%$&,=?~#.+:;-]+[\p{L}\p{N}_/%$=?~#-] *';
  MatchHashtag : Utf8String = ' *#[\p{L}\p{N}]*[\p{L}][\p{L}\p{N}]* *';

  MatchMultiSpace : Utf8String = '\s{2,}';


constructor TTrSecondPass.Create(const AIni : TIniFile);
begin

  // Pre-compile the regexes.
  FMatchTagIcu := TIcuRegex.Create(MatchTag, UREGEX_CASE_INSENSITIVE);
  FMatchEmailIcu := TIcuRegex.Create(MatchEmail,
    UREGEX_CASE_INSENSITIVE);
  FMatchUriIcu := TIcuRegex.Create(MatchUri, UREGEX_CASE_INSENSITIVE);
  FMatchHashtagIcu := TIcuRegex.Create(MatchHashtag,
    UREGEX_CASE_INSENSITIVE);

  FMatchMultiSpaceIcu := TIcuRegex.Create(MatchMultiSpace,
    UREGEX_CASE_INSENSITIVE);

  FEntityConverter := TTrUtf8EntityConverter.Create;

  inherited Create(AIni);
end;


destructor TTrSecondPass.Destroy;
begin
  FreeAndNil(FMatchTagIcu);
  FreeAndNil(FMatchEmailIcu);
  FreeAndNil(FMatchUriIcu);
  FreeAndNil(FMatchHashtagIcu);
  FreeAndNil(FEntityConverter);

  FreeAndNil(FMatchMultiSpaceIcu);

  inherited Destroy;
end;


function TTrSecondPass.Cleanse(const AIn : String;
  out ATagCount : Integer; out AEmailCount : Integer;
  out AUriCount : Integer; out AHashTagCount : Integer) : String;
begin
  Result := AIn;

  if FCleanseTags
  then begin
    ATagCount := FMatchTagIcu.MatchCount(Result, true);
    if ATagCount > 0
    then Result := FMatchTagIcu.Replace(Result, ' ', true, false);
  end;

  if FCleanseEmail
  then begin
    AEmailCount := FMatchEmailIcu.MatchCount(Result, true);
    if AEmailCount > 0
    then Result := FMatchEmailIcu.Replace(Result, FEmailReplacer, true,
      false);
  end;

  if FCleanseUri
  then begin
    AUriCount := FMatchUriIcu.MatchCount(Result, true);
    if AUriCount > 0
    then Result := FMatchUriIcu.Replace(Result, FUriReplacer, true,
      false);
  end;

  if FCleanseHashtag
  then begin
    AHashTagCount := FMatchHashtagIcu.MatchCount(Result, true);
    if AHashTagCount > 0
    then Result := FMatchHashtagIcu.Replace(Result, FHashtagReplacer,
      true, false);
  end;

end;


procedure TTrSecondPass.Metarator(var AKey : String; var AValue : String);
var
  i : Integer;
begin
  AValue := FEntityConverter.ConvertString(AValue);
  try
    AValue := Cleanse(AValue, i, i, i, i);
    AValue := Trim(AValue);
    AValue := FMatchMultiSpaceIcu.Replace(AValue, ' ', true, false);
  except
    AValue := '';
  end;
end;



procedure TTrSecondPass.Process(const ADocument : TTrDocument);
var
  i : Integer;
  LTagCount, LEmailCount, LUriCount, LHashTagCount : Integer;
begin

  // Iterate over divisions.
  for i := 0 to ADocument.Number-1
  do begin
    if Assigned(ADocument[i])
    and ADocument[i].Valid
    then begin

      // Convert entities with new, clean and simple function.
      ADocument[i].Text :=
        FEntityConverter.ConvertString(ADocument[i].Text);

      // Double wash means that we catch stuf like: &amp;acirc;
      if FDoubleWashEntities
      then ADocument[i].Text :=
        FEntityConverter.ConvertString(ADocument[i].Text);
      try

        // Do the cleansing.
        ADocument[i].Text := Cleanse(ADocument[i].Text, LTagCount,
          LEmailCount, LUriCount, LHashTagCount);

        // Record the metrics (by-product from cleansing).
        ADocument[i].CleansedTags     := LTagCount;
        ADocument[i].CleansedEmails   := LEmailCount;
        ADocument[i].CleansedUris     := LUriCount;
        ADocument[i].CleansedHashTags := LHashTagCount;

      except

        // Exceptions from ICU mean there were faulty characters (non-
        // UTF8), so kill document.
        ADocument.Valid := false;
        Exit;
      end;
    end;

    // Empty paragraphs can be deleted.
    if ADocument[i].Text = ''
    then ADocument[i].Valid := false;
  end;

  // Check metas.
  ADocument.Meta.Iterate(@self.Metarator);
end;


procedure TTrSecondPass.SetEmailReplacer(const AReplacer : String);
begin
  FEmailReplacer := ' ' + AReplacer + ' ';
end;


procedure TTrSecondPass.SetUriReplacer(const AReplacer : String);
begin
  FUriReplacer := ' ' + AReplacer + ' ';
end;


procedure TTrSecondPass.SetHashtagReplacer(const AReplacer : String);
begin
  FHashtagReplacer := ' ' + AReplacer + ' ';
end;


class function TTrSecondPass.Achieves : TTrPrerequisites;
begin
  Result := [trpreEntityFree, trpreIdentifierBlanked];
end;


class function TTrSecondPass.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8];
end;


end.
