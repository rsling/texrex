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


unit TrClaraxApplication;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  IniFiles,
  CustApp,
  Classes,
  Contnrs,
  SysUtils,
  StrUtils,
  TrVersionInfo,
  TrUtilities,
  TrFile,
  TrWalkers;


type

  ETrClaraxApplication = class(Exception);

  TTrClaraxApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FIni : TIniFile;
    FJobName : String;
    FComment : String;
    FSilent : Boolean;
    FWalkerClassName : String;

    FWalkerClass : TTrWalkerClass;
    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
    procedure Report(const AMessage : String = '';
      const ASuppressLf : Boolean = false);
  published
    property JobName : String read FJobName write FJobName;
    property Comment : String read FComment write FComment;
    property Silent : Boolean read FSilent write FSilent default false;
    property WalkerClassName : String read FWalkerClassName
      write FWalkerClassName;
  end;


implementation



constructor TTrClaraxApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);

end;


destructor TTrClaraxApplication.Destroy;
begin

  inherited Destroy;
end;


procedure TTrClaraxApplication.Initialize;
const
  OptNum=2;
  OptionsShort : array[0..OptNum] of Char = ('h', 'v', 'j');
  OptionsLong : array[0..OptNum] of String = ('help', 'version', 'job');
var
  LOptionError : String;
  LJobIniFileName : String;
begin
  inherited Initialize;

  Randomize;

  CaseSensitiveOptions := false;
  {$IFDEF DEBUG}
    StopOnException := true;
  {$ELSE}
    StopOnException := false;
  {$ENDIF}

  if HasOption('h', 'help')
  then begin
    ShowHelp;
    Exit;
  end;

  LOptionError := CheckOptions(OptionsShort, OptionsLong);
  if LOptionError <> ''
  then SayError(LOptionError);

  if not HasOption('j', 'job')
  then SayError('No job file specified.');

  LJobIniFileName := GetOptionValue('j', 'job');
  if not TrFindFile(LJobIniFileName)
  then SayError('Job configuration INI not found.')
  else begin
    FIni := TIniFile.Create(LJobIniFileName);
    if not Assigned(FIni)
    then SayError('Job did not initialize.');
  end;

  // Do not use Report() before this because "Silent" option will not have been
  // parsed properly.
  TrReadProps(self, FIni);

  FWalkerClass := GetWalkerClass(FWalkerClassName);
  if not Assigned(FWalkerClass)
  then SayError('Unknown walker class specified: ' + FWalkerClassName);

  Report;
  Report('ClaraX from ' + TrName + '-' + TrCode + ' (' + TrVersion + ')');
  Report(TrMaintainer);
  Report;

end;


procedure TTrClaraxApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


procedure TTrClaraxApplication.DoRun;
var
  LWalker : TTrWalker = nil;
begin
  if not Terminated
  then begin
    try
      LWalker := FWalkerClass.Create(FIni, @self.Report);
      LWalker.Run;
    finally
      FreeAndNil(LWalker);
      Terminate;
    end;
  end;
end;


procedure TTrClaraxApplication.ShowHelp;
begin
  Report('Usage:  clarax --job=FILENAME | -j FILENAME');
  Report;
  Report('FILENAME must be the name of a clarax job INI file.');
  Report;
  Report('Other options:');
  Report('-v   --version  Display version information and exit.');
  Report('-h   --help     Display this help an exit.');
  Report;
  Terminate;
end;


procedure TTrClaraxApplication.SayError(const AError : String);
begin
  Report('Error: ' + AError);
  Report('Use clarax -h to get help.');
  Report;
  Terminate;
end;


procedure TTrClaraxApplication.Report(const AMessage : String = '';
  const ASuppressLf : Boolean = false);
begin
  // TODO RS : Route to different outputs.

  if not FSilent
  then if ASuppressLf
    then Write(AMessage)
    else Writeln(AMessage);
end;


end.
