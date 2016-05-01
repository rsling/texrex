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


unit TrCharsetConverter;

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
  TrUtilities;


type

  ETrCharsetConverter = class(Exception);

  TTrCharsetConverter = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;
    destructor Destroy; override;
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FIcuDetector : TIcuDetector;
    FIcuConverter : TIcuConverter;
    FIso88591IsWin1252 : Boolean;
  published
    property Iso88591IsWin1252 : Boolean read FIso88591IsWin1252
      write FIso88591IsWin1252 default true;
  end;


implementation


constructor TTrCharsetConverter.Create(const AIni : TIniFile);
begin
  FIcuDetector := TIcuDetector.Create;
  FIcuConverter := TIcuConverter.Create;

  inherited Create(AIni);
end;


destructor TTrCharsetConverter.Destroy;
begin
  FreeAndNil(FIcuDetector);
  FreeAndNil(FIcuConverter);
  inherited Destroy;
end;


procedure TTrCharsetConverter.Process(const ADocument : TTrDocument);
var
  LDetection : TIcuDetectionResults;
  LMaxCompare : Integer = 32768;
  i : Integer;
begin
  inherited;

  // Detect charset if necessary.
  // Incl.: Detect whether ICU knows this charset.
  if (ADocument.SourceCharset = '')
  or (not FIcuDetector.TestCharset(ADocument.SourceCharset))
  then begin

    // Clamp the maximal comparison range.
    if LMaxCompare > Length(ADocument.RawText)-1
    then LMaxCompare := Length(ADocument.RawText)-1;

    FIcuDetector.DetectCharsets(ADocument.RawText, LDetection,
      LMaxCompare);
    ADocument.SourceCharset := UpCase(LDetection[0].Charset);
  end;

  if (ADocument.SourceCharset <> 'UTF-8')
  and (ADocument.SourceCharset <> 'UTF8')
  then begin

    // Win1252 declared as ISO-8859-1
    if FIso88591IsWin1252
    then begin
      if (ADocument.SourceCharset = 'ISO-8859-1')
      or (ADocument.SourceCharset = 'ISO8859-1')
      or (ADocument.SourceCharset = 'ISO-88591')
      or (ADocument.SourceCharset = 'ISO88591')
      or (ADocument.SourceCharset = 'ISO8859')
      then ADocument.SourceCharset := 'WINDOWS-1252';
    end;

    // Convert the stripped paragraphs.
    for i := 0 to ADocument.Number-1
    do begin
      try
        ADocument[i].Text := FIcuConverter.ConvertFromTo(
          ADocument[i].Text, ADocument.SourceCharset, 'UTF-8');
      except
        ADocument[i].Valid := false;
      end;
    end;

    // Convert the header for meta extraction.
    ADocument.RawHeader := FIcuConverter.ConvertFromTo(
      ADocument.RawHeader, ADocument.SourceCharset, 'UTF-8');

  end;
end;


class function TTrCharsetConverter.Achieves : TTrPrerequisites;
begin
  Result := [trpreIsUtf8];
end;


class function TTrCharsetConverter.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped];
end;


end.
