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


unit TrMetaExtractor;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  Classes,
  IniFiles,
  TrUtilities,
  TrData,
  IcuWrappers,
  TrDocumentProcessor;


type

  ETrMetaExtractor = class(Exception);

  // A document filter which takes only very basic metrics into
  // consideration.
  TTrMetaExtractor = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;
    destructor Destroy; override;

    // This only sets Valid := false, never := true.
    // If already = false, then doc is ignored anyway.
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;

  protected
    FExtractTitle : Boolean;
    FExtractKeywords : Boolean;
    FExtractAuthor : Boolean;
    FExtractDescription : Boolean;
    FExtractRobots : Boolean;

    // For the actual regex matching.
    FTitleIcu :  TIcuRegex;
    FKeywordsIcu :  TIcuRegex;
    FAuthorIcu : TIcuRegex;
    FDescriptionIcu : TIcuRegex;
    FRobotsIcu : TIcuRegex;

  published
    property ExtractKeywords : Boolean read FExtractKeywords
      write FExtractKeywords default true;
    property ExtractTitle : Boolean read FExtractTitle
      write FExtractTitle default true;
    property ExtractAuthor : Boolean read FExtractAuthor write FExtractAuthor
      default true;
    property ExtractDescription : Boolean read FExtractDescription
      write FExtractDescription default true;
    property ExtractRobots : Boolean read FExtractRobots write FExtractRobots
      default true;
  end;



implementation


const
  TitleRegex = '^.*<title>(.+)</title>.*$';
  KeywordsRegex = '^.*<meta name=[''"]keywords[''"][^>]*content=[''"]([^''"]+)[''"].*$';
  AuthorRegex = '^.*<meta name=[''"]author[''"][^>]*content=[''"]([^''"]+)[''"].*$';
  DescriptionRegex = '^.*<meta name=[''"]description[''"][^>]*content=[''"]([^''"]+)[''"].*$';
  RobotsRegex = '^.*<meta name=[''"]robots[''"][^>]*content=[''"]([^''"]+)[''"].*$';

  MetaReplace = '$1';



constructor TTrMetaExtractor.Create(const AIni : TIniFile);
begin
  FTitleIcu := TIcuRegex.Create(TitleRegex, UREGEX_CASE_INSENSITIVE);
  FKeywordsIcu :=  TIcuRegex.Create(KeywordsRegex, UREGEX_CASE_INSENSITIVE);
  FAuthorIcu :=  TIcuRegex.Create(AuthorRegex, UREGEX_CASE_INSENSITIVE);
  FDescriptionIcu :=  TIcuRegex.Create(DescriptionRegex,
    UREGEX_CASE_INSENSITIVE);
  FRobotsIcu :=  TIcuRegex.Create(RobotsRegex, UREGEX_CASE_INSENSITIVE);
  inherited Create(AIni);
end;


destructor TTrMetaExtractor.Destroy;
begin
  FreeAndNil(FAuthorIcu);
  FreeAndNil(FDescriptionIcu);
  FreeAndNil(FRobotsIcu);
  FreeAndNil(FTitleIcu);
  FreeAndNil(FKeywordsIcu);
  inherited Destroy;
end;


procedure TTrMetaExtractor.Process(
  const ADocument : TTrDocument);
begin
  inherited;

  if FExtractTitle
  and FTitleIcu.Match(ADocument.RawHeader, true, true)
  then begin
    ADocument.AddMeta('title', FTitleIcu.Replace(ADocument.RawHeader,
      MetaReplace, false, true));
  end;

  if FExtractKeywords
  and FKeywordsIcu.Match(ADocument.RawHeader, true, true)
  then begin
    ADocument.AddMeta('keywords',
      FKeywordsIcu.Replace(ADocument.RawHeader, MetaReplace, false,
      true));
  end;

  if FExtractAuthor
  and FAuthorIcu.Match(ADocument.RawHeader, true, true)
  then begin
    ADocument.AddMeta('author',
      FAuthorIcu.Replace(ADocument.RawHeader, MetaReplace, false,
      true));
  end;

  if FExtractDescription
  and FDescriptionIcu.Match(ADocument.RawHeader, true, true)
  then begin
    ADocument.AddMeta('description',
      FDescriptionIcu.Replace(ADocument.RawHeader, MetaReplace, false,
      true));
  end;

  if FExtractRobots
  and FRobotsIcu.Match(ADocument.RawHeader, true, true)
  then begin
    ADocument.AddMeta('robots',
      FRobotsIcu.Replace(ADocument.RawHeader, MetaReplace, false,
      true));
  end;

end;


class function TTrMetaExtractor.Achieves : TTrPrerequisites;
begin
  Result := [];
end;


class function TTrMetaExtractor.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8];
end;


end.
