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


unit TrDocumentProcessor;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  Classes,
  IniFiles,
  RttiUtils,
  TrData,
  TrUtilities;


type

  ETrDocumentProcessor = class(Exception);


  // This is an abstract class that takes a TTrDocument and
  // processes it. All strippers, cleaners etc. inherit from this.
  TTrDocumentProcessor = class(TPersistent)
  public

    // It is possible to create a processor with props read from a section
    // by ClasssName or by explicitly passed AName.
    constructor Create(const AIni : TIniFile); virtual;
    constructor Create(const AIni : TIniFile; var AName : String); virtual;

    procedure Process(const ADocument : TTrDocument); virtual;

    // These provide information what kind of processing the class
    // does and requires to be already done.
    class function Achieves : TTrPrerequisites; virtual; abstract;
    class function Presupposes : TTrPrerequisites; virtual; abstract;
  protected
    FIni : TIniFile;
  end;

  TTrDocProc = procedure (const ADocument : TTrDocument) of object;



implementation



constructor TTrDocumentProcessor.Create(const AIni : TIniFile);
begin
  TrAssert(Assigned(AIni), 'INI is assigned.');
  FIni := AIni;
  TrReadProps(self, FIni);
end;


constructor TTrDocumentProcessor.Create(const AIni : TIniFile;
  var AName : String);
begin
  TrAssert(Assigned(AIni), 'INI is assigned.');
  FIni := AIni;
  TrReadProps(self, FIni, AName);
end;

procedure TTrDocumentProcessor.Process(const ADocument : TTrDocument);
begin
  if not Assigned(ADocument)
  then Exit;

  // Documents which have not been properly pre-processed cannot be
  // processed.
  if not (Presupposes <= ADocument.Passed)
  then raise ETrDocumentProcessor.Create(self.ClassName +
      ' precondition was not met.');

  // We add our own processing mark. If it fails, document will be
  // marked as invalid.
  ADocument.Passed := ADocument.Passed + self.Achieves;
end;


end.
