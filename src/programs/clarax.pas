{
  This file is part of texrex.
  Maintained by Roland Schäfer.
  http://texrex.sourceforge.net/

  See the file COPYING.GPL, included in this distribution, for
  details about the copyright.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}


program ClaraX;


{$MODE OBJFPC}
{$H+}


uses
  {$IFDEF UNIX}
    CThreads,
    CMem,
    CWString,
  {$ENDIF}
  Classes,
  SysUtils,
  TrUtilities,
  TrClaraxApplication;


var
  TrClaraxApp : TTrClaraxApplication;


begin
  TrClaraxApp := TTrClaraxApplication.Create(nil);
  TrClaraxApp.Initialize;
  TrClaraxApp.Run;
  FreeAndNil(TrClaraxApp);
end.
