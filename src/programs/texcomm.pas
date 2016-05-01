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


program texcomm;


{$MODE OBJFPC}
{$H+}


uses
  {$IFDEF UNIX}
    CThreads,
    CMem,
    CWString,
  {$ENDIF}
  Classes,
  StrUtils,
  SysUtils,
  SimpleIpc,
  TrVersionInfo,
  TrUtilities;

var
  CliCom : String;
  TimeOut : Integer = 1000;
  IpcServer : TSimpleIpcServer;
  IpcClient : TSimpleIpcClient;
  TryInt : Integer;
  Parsed : TStringArray;


procedure Send(const AMessage : String);
begin
  if not IpcClient.Active
  then begin
    Writeln('IPC server is not active/connected.');
    Exit;
  end;

  if not IpcClient.ServerRunning
  then begin
    Writeln('The server is not running. Has texrex been shut down?');
    Writeln('You can try to reconnect.');
    Exit;
  end;

  // Send message.
  IpcClient.SendStringMessage(AMessage + ' ' + IpcServer.ServerId + ' '
    + IpcServer.InstanceId);

  // Wait for reply.
  while IpcServer.PeekMessage(TimeOut, true)
  and   (IpcServer.StringMessage <> '<<<texcomm:eom>>>')
  do Writeln(IpcServer.StringMessage);

end;


begin
  Writeln(#10#13, 'texcomm IPC from ', TrName, '-', TrCode, ' (',
    TrVersion, ')', #10#13, TrMaintainer, #10#13);

  Writeln('Use "help" to display command overview, "bye" to exit.',
    #10#13);

  IpcServer := TSimpleIpcServer.Create(nil);

  // TODO RS Re-enable with FPC 2.8 or later.
  // IpcServer.Global := true;

  IpcServer.StartServer;
  if Assigned(IpcServer)
  then begin
    IpcServer.ServerId := 'texcomm';
  end else begin
    Writeln(#10#13'Error creating IPC server. Terminating.'#10#13);
    Exit;
  end;

  IpcClient := TSimpleIpcClient.Create(nil);
  if not Assigned(IpcClient)
  then begin
    Writeln(#10#13'Error creating IPC client. Terminating.'#10#13);
    Exit;
  end;

  try

    // Main loop.
    while true
    do begin
      Write('texcomm $ ');
      Readln(CliCom);

      Parsed := TrExplode(CliCom, [' ']);

      if Length(Parsed) = 0
      then Continue;

      // Commands directly interpreted by the client.
      case Parsed[0]
      of

        'bye', 'b' : Break;

        'timeout', 't' : begin
          if  (Length(Parsed) = 2)
          and TryStrToInt(Parsed[1], TryInt)
          then begin
            TimeOut := TryInt;
            Writeln('Timeout set to : ', TimeOut);
          end else if (Length(Parsed) = 1)
          then Writeln('Timeout is : ', TimeOut)
          else Writeln('Illegal argument(s) to "timeout" command.');
        end;

        'connect', 'co' : begin
          if (Length(Parsed) = 3)
          then begin
            try
              IpcClient.ServerId := Parsed[1];
              IpcClient.ServerInstance := Parsed[2];
              IpcClient.Active := true;
            except
              Writeln('Could not connect to server.');
            end;
          end else Writeln('Illegal argument(s) to "connect" command.');
        end;

        'disconnect', 'di' : begin
          if (Length(Parsed) = 1)
          then IpcClient.Active := false
          else Writeln('Illegal argument(s) to "disconnect" command.')
        end;

        'help', 'h' : begin
          Send(CliCom);
          Writeln(#10#13+
'Additional, locally interpreted commands:'#10#13 +
'timeout N     t N     Set server response timeout to N ms.'#10#13 +
'connect S I   co S I  Connect to server S with instance I.'#10#13 +
'disconnect    di      Close current server connection.'#10#13);
        end;

        else Send(CliCom);

      end;

    end;

  finally
    FreeAndNil(IpcClient);
    FreeAndNil(IpcServer);
  end;
end.
