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


unit TrUtf8Validator;

{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  SysUtils,
  Classes,
  IniFiles,
  IcuWrappers,
  TrData,
  TrDocumentProcessor,
  TrUtilities;


type

  ETrUtf8Validator = class(Exception);

  // This iterates over paragraphs and marks those as invalid which
  // have contain UTF-8.
  TTrUtf8Validator = class(TTrDocumentProcessor)
  public
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    procedure Metarator(var AKey : String; var AValue : String);
  end;



implementation


procedure TTrUtf8Validator.Metarator(var AKey : String; var AValue : String);
begin
  if TrUtf8Check(AValue) > 0
  then AValue := '';
end;


procedure TTrUtf8Validator.Process(const ADocument : TTrDocument);
var
  i : Integer;
begin
  inherited;

  // Check the divs.
  for i := 0 to ADocument.Number-1
  do
    if (TrUtf8Check(ADocument[i].Text) > 0)
    then ADocument[i].Valid := false;

  // Check metas.
  ADocument.Meta.Iterate(@self.Metarator);
end;


class function TTrUtf8Validator.Achieves : TTrPrerequisites;
begin
  Result := [trpreIsValidUtf8];
end;


class function TTrUtf8Validator.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8];
end;


end.
