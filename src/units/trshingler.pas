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


unit TrShingler;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  StrUtils,
  SysUtils,
  Classes,
  Math,
  IniFiles,
  TrUtilities,
  TrData,
  TrRabinHash,
  TrDocumentProcessor;


type

  ETrShingler = class(Exception);

  TTrShingler = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;
    destructor Destroy; override;
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FNGramSize : Integer;
    FHashesNumber : Integer;
    FHashProvider : TTrHashProvider;
  published
    property NGramSize : Integer read FNGramSize write FNGramSize
      default 5;
    property HashesNumber : Integer read FHashesNumber
      write FHashesNumber default 100;
  end;


implementation


constructor TTrShingler.Create(const AIni : TIniFile);
begin
  inherited Create(AIni);

  // Create a deterministic hash provider. Must come AFTER inherited,
  // or FHashesNumber is not known.
  FHashProvider := TTrHashProvider.Create(FHashesNumber, true);
end;


destructor TTrShingler.Destroy;
begin
  FreeAndNil(FHashProvider);
  inherited Destroy;
end;


procedure TTrShingler.Process(const ADocument : TTrDocument);
var
  i, j : Integer;
  LCurrentNGram : String;
  LCurrentHash : QWord;
  LNGramNumber : Integer;
  LNGramList : TStringArray;
  LMinHash : QWord;
begin
  inherited;

  // Calculate how many n-grams we can build.
  LNGramNumber := ADocument.TypeTokenData.TokenCount - FNGramSize + 1;

  // If there really were no usable types, processing would lead
  // to range check errors etc. - and waste time.
  if LNGramNumber < 1
  then Exit;

  SetLength(LNGramList, LNGramNumber);

  // Construct all n-grams from token list.
  for i := 0 to LNGramNumber - 1
  do begin

    // Construct N-gram.
    LCurrentNGram := '';
    for j := 0 to FNGramSize - 1
    do LCurrentNGram += ADocument.TypeTokenData.TokenSequence[i+j];

    // Pad N-gram to hashable size.
    if Length(LCurrentNGram) < 9
    then LCurrentNGram := PadLeft(LCurrentNGram, 9);

    LNGramList[i] := LCurrentNGram;
  end;

  // Now go through list and hash n times, always keeping Min.
  ADocument.FingerprintSize := FHashesNumber;
  for i := 0 to FHashesNumber - 1
  do begin

    // Set LMinHash to maximum possible value.
    LMinHash := High(QWord);
    for j := 0 to Length(LNGramList) - 1
    do begin
      LCurrentHash := FHashProvider.Hash(LNGramList[j], i);
      if LCurrentHash < LMinHash
      then LMinHash := LCurrentHash;
    end;
    ADocument.Fingerprint[i] := LMinHash;
  end;

end;


class function TTrShingler.Achieves : TTrPrerequisites;
begin
  Result := [];
end;


class function TTrShingler.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8,trpreTokenized];
end;


end.
