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


unit TrTexrex;


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
  Crt,
  DateUtils,
  SimpleIpc,
  TrVersionInfo,
  TrUtilities,
  TrData,
  TrFile,
  TrReader,
  TrWriter,
  TrWorker,
  TrQueues;


type

  ETrTexrex = class(Exception);

  TTrApplication = class;

  {$I statswatcher_h.inc}

  TTrApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FIpcServer : TSimpleIPCServer;
    FIpcClient : TSimpleIPCClient;
    FIpcId : String;
    FIpcInstance : String;
    FJobname : String;
    FComment : String;
    FShutdownMagicNumber : Integer;
    FRnfgreRtt : Boolean;
    FZlsNibevgr : String;
    FStatsWatcher : TTrStatsWatcher;
    FStatsInterval : Integer;
    FIni : TIniFile;
    FSilent : Boolean;
    FInQSize : Integer;
    FOutQSize : Integer;
    FInQueue : TTrDocumentQueue;
    FOutQueue : TTrDocumentQueue;
    FReaderPool : TTrReaderPool;
    FWorkerPool : TTrWorkerPool;
    FWriterPool : TTrWriterPool;
    FInterrupt : Boolean;
    FStarted : TDateTime;

    // If this is true, worker threads will be reduced or increased
    // if the in queue is filled more/less than in the prefered quartile.
    FWorkerManagement : Boolean;
    FPreferedInQueueQUartile : Integer;
    FCurrentQuartileLow : Integer;
    FCurrentQuartileHigh : Integer;
    FLastManagementCheck : TDateTime;
    FMangementInterval : Integer;

    // Whether the stats checker should check immediately.
    FForceStats : Boolean;

    procedure SetPreferedInQueueQuartile(const AQuartile : Integer);
    procedure SetDebug(ADebug : Boolean);
    function GetDebug : Boolean;

    procedure DoRun; override;

    // The following methods are in INC files.

    // Interpret and react to ACommand. If AIpcServerId != '', then
    // response will be sent to IPC server with AIpcServerId instead
    // of local terminal.
    procedure Interpret(const ACommand : String; AIsIpc : Boolean);
    procedure ShowHelp;
    procedure ZPress;
    function Dash : String;
    function Mooo : String;
    procedure SetZlsNibevgr(const AThing : String);
    procedure SWrite(const ALine : String = ''); inline;
    procedure SWriteln(const ALine : String = ''); inline;

  published
    property Jobname : String read FJobname write FJobname;
    property Comment : String read FComment write FComment;
    property Silent : Boolean read FSilent write FSilent
      default true;
    property InQSize : Integer read FInQSize write FInQSize
      default 1000;
    property OutQSize : Integer read FOutQSize write FOutQSize
      default 1000;
    property StatsInterval : Integer read FStatsInterval
      write FStatsInterval default 60;
    property WorkerManagement : Boolean read FWorkerManagement
      write FWorkerManagement default false;
    property PreferedInQueueQUartile : Integer
      read FPreferedInQueueQUartile write SetPreferedInQueueQUartile
      default 2;
    property MangementInterval : Integer read FMangementInterval
      write FMangementInterval default 60;
    property Debug : Boolean read GetDebug write SetDebug
      default true;
    property ZlsNibevgr : String read FZlsNibevgr
      write SetZlsNibevgr;
  end;



implementation


{$I statswatcher.inc}


const
  OptNum=2;
  OptionsShort : array[0..OptNum] of Char = ('h', 'v', 'j');
  OptionsLong : array[0..OptNum] of String = ('help', 'version', 'job');

const
  TrCommHelp =
'This texcomm server knows the following commands (long/short version):'#10#10#13 +
'bye           b       Exit texcomm (does not shutdown texrex).'#10#13 +
'shutdown [M]  s [M]   Shutdown texrex. Pass magic number as M.'#10#13 +
'                      Without M, the magic number will be shown.'#10#13 +
'dash [force]  d [f]   Show dashboard. "force" for fresh calculations.'#10#13 +
'peek          p       Show a processed recent document (plain text'#10#13 +
'                      prior to final normalization in XMLWriter).'#10#13 +
'reader +|-    r  +|-  Add (+) or remove (-) a reader thread.'#10#13 +
'worker +|-    wo +|-  Add (+) or remove (-) a worker thread.'#10#13 +
'writer +|-    wr +|-  Add (+) or remove (-) a writer thread.'#10#13 +
'inqueue N     iq N    Set "in" queue size to N.'#10#13 +
'outqueue N    oq N    Set "out" queue size to N.'#10#13 +
'manage        ma      Toggle dynamic worker management.'#10#13 +
'conf S        c       Print (original!) configuration section S.'#10#13 +
'                      Pass no parameter to see the list of sections.'#10#13 +
'ident         i       Identify this server.'#10#13 +
'silence       si      Toggle silent mode.'#10#13 +
'help          h       Show help.'#10#13;



{ *** TTrApplication *** }


constructor TTrApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
end;


destructor TTrApplication.Destroy;
begin
  FreeAndNil(FIpcClient);
  FreeAndNil(FIpcServer);
  FreeAndNil(FIni);
  inherited Destroy;
end;


procedure TTrApplication.Initialize;
var
  LJobIniFileName : String;
  LOptionError : String;
begin
  inherited Initialize;

  Randomize;
  FShutdownMagicNumber := Random(999);

  CaseSensitiveOptions := false;
  {$IFDEF DEBUG}
    StopOnException := true;
  {$ELSE}
    StopOnException := false;
  {$ENDIF}

  LOptionError := CheckOptions(OptionsShort, OptionsLong);
  if LOptionError <> ''
  then begin
    Writeln(#10#13'Error: ', LOptionError, #10#13);
    Terminate;
    Exit;
  end;

  if (HasOption('v', 'version'))
  then begin
    Writeln(#10#13, TrName, '-', TrCode, ' (', TrVersion, ')');
    Writeln(#13, TrMaintainer);
    Writeln;
    Terminate;
    Exit;
  end;

  if (HasOption('h', 'help'))
  then begin
    ShowHelp;
    Terminate;
    Exit;
  end;

  // Check passed parameter(s) and INI file.
  if not (HasOption('j', 'job'))
  then begin
    ShowHelp;
    Writeln(#10#13'Error: Job configuration INI was not specified.'#10#13);
    Terminate;
    Exit;
  end;

  LJobIniFileName := GetOptionValue('j', 'job');
  if not FileExists(LJobIniFileName)
  then begin
    ShowHelp;
    Writeln(#10#13'Error: Job configuration INI not found.'#10#13);
    Terminate;
    Exit;
  end;

  FIni := TIniFile.Create(LJobIniFileName);
  if not Assigned(FIni)
  then begin
    ShowHelp;
    Writeln(#10#13'Error: Job did not initialize.'#10#13);
    Terminate;
    Exit;
  end;

  FForceStats := false;
  FInterrupt := false;
  FRnfgreRtt := false;

  // Call the helper which loads this object's properties with the
  // values from INI.
  TrReadProps(self, FIni);

  FStarted := Now;
  FLastManagementCheck := FStarted;

  // If we are here, we can actually start up.

  SWriteln(#10#13 + TrName + '-' + TrCode + ' (' + TrVersion + ')' +
    #10#13 + TrMaintainer);

  // TODO RS LOW PRIORITY – see whether we can fix this otherwise.
  SWriteln(#10#13 + 'NOTE! If you get FANN errors, set LC_ALL=C.');

  SWriteln(#10#13 + 'Job name: ' + FJobname);
  SWriteln('Comment: ' + FComment);
  SWriteln(#10#13 + 'Creating queues: InQueue: ' + IntToStr(FInQSize));
  FInQueue := TTrDocumentQueue.Create(FInQSize, 'InQueue');
  SWriteln('Creating queues: OutQueue: ' + IntToStr(FOutQSize)  );
  FOutQueue := TTrDocumentQueue.Create(FOutQSize, 'OutQueue');

  // Processing will begin right away, these are started in resumed
  // state.
  SWrite('Creating reader pool...');
  try
    FReaderPool := TTrReaderPool.Create(FInQueue, FIni);
  except
    TrDebug(ClassName, Exception(ExceptObject));
    Terminate;
    Exit;
  end;
  SWriteln(' done.');

  SWrite('Creating worker pool (possibly with geolocator init)... ');
    try
    FWorkerPool := TTrWorkerPool.Create(FInQueue, FOutQueue, FIni);
  except
    TrDebug(ClassName, Exception(ExceptObject));
    Terminate;
    Exit;
  end;
  SWriteln(' done.');

  SWrite('Creating writer pool... ');
  try
    FWriterPool := TTrWriterPool.Create(FOutQueue, FIni);
  except
    TrDebug(ClassName, Exception(ExceptObject));
    Terminate;
    Exit;
  end;
  SWriteln(' done.');

  SWrite('Creating statistics watcher.');
  try
    FStatsWatcher := TTrStatsWatcher.Create(self);
  except
    TrDebug(ClassName, Exception(ExceptObject));
    Terminate;
    Exit;
  end;
  SWriteln(' done.');

  SWrite('Creating IPC server... ');
  FIpcServer := TSimpleIPCServer.Create(nil);

  // TODO RS Re-enable with FPC 2.8 or later.
  // FIpcServer.Global := true;

  if Assigned(FIpcServer)
  then begin
    FIpcServer.ServerId := 'texrex';
    FIpcServer.StartServer;
    FIpcId := FIpcServer.ServerId;
    FIpcInstance := FIpcServer.InstanceId;
    SWriteln('OK: ' + FIpcId + ' ' + FIpcInstance);
  end else SWriteln('FAILED!');

  SWrite('Creating IPC client... ');
  FIpcClient := TSimpleIPCClient.Create(nil);
  if Assigned(FIpcClient)
  then SWriteln('OK.')
  else SWriteln('FAILED!');

  SWriteln('Entering main loop.');
  SWriteln;
  SWriteln('Press the Z key to enter texcomm console.');
  SWriteln('Or use the texcomm IPC client and connect to: ' +
    FIpcId + ' ' + FIpcInstance);
  SWriteln;
end;


procedure TTrApplication.DoRun;
begin
  if not Terminated
  then begin

    // Currently, we do not synchronize. But this is a good sleep
    // alternative anyway.
    CheckSynchronize(10);

    // Check for command from IPC.
    if not FInterrupt
    then begin
      if FIpcServer.PeekMessage(10, true)
      then Interpret(FIpcServer.StringMessage, true);
    end;

    // Check whether a shutdown is requested from CLI.
    if KeyPressed
    and not FInterrupt
    then ZPress;

    // Do queue/worker control if requested.
    if FWorkerManagement
    and (SecondsBetween(FLastManagementCheck, Now) > FMangementInterval)
    then begin
      FLastManagementCheck := Now;

      // Calculate boundaries for prefered quartile.
      FCurrentQuartileLow := Round((FInQueue.MaxLength / 4) *
        (FPreferedInQueueQuartile-1));
      FCurrentQuartileHigh := Round((FInQueue.MaxLength / 4) *
        FPreferedInQueueQuartile);

      if FInQueue.Length >= FCurrentQuartileHigh-10
      then FWorkerPool.AddThread
      else if FInQueue.Length <= FCurrentQuartileLow+10
      then FWorkerPool.RemoveThread;
    end;

    // Print status report.
    SWrite(Format(
      #13'InQ: %0:6D  OutQ: %1:6D  Threads: %2:3D %3:3D %4:3D',
      [FInQueue.Length, FOutQueue.Length,
      FReaderPool.ActiveThreads,
      FWorkerPool.ActiveThreads,
      FWriterPool.ActiveThreads]));

    // Check whether we are done.
    if  FInterrupt
    or ( (FInQueue.Length = 0)
      and (FOutQueue.Length = 0)
      and (FReaderPool.ActiveThreads < 1) )
    then begin
      SWrite(#13 + StringOfChar(' ', 72));
      SWriteln(#13'Terminating.'#10#13);

      SWriteln('Terminating all reader threads.');
      FReaderPool.TerminateAll;
      SWriteln('Terminating all worker threads.');
      FWorkerPool.TerminateAll;
      SWriteln('Terminating all writer threads.');
      FWriterPool.TerminateAll;


      FForceStats := true;
      while FForceStats
      do Sleep(100);

      SWrite('Terminating statistics watcher... ');
      FStatsWatcher.Terminate;
      SWriteln(IntToStr(FStatsWatcher.WaitFor));


      FreeAndNil(FStatsWatcher);
      FreeAndNil(FReaderPool);
      FreeAndNil(FWriterPool);
      FreeAndNil(FWorkerPool);

      SWriteln('Closing queues.');
      FreeAndNil(FInQueue);
      FreeAndNil(FOutQueue);

      Terminate;

      Exit;
    end;
  end;
end;


procedure TTrApplication.ShowException(E: Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


procedure TTrApplication.SetPreferedInQueueQuartile(
  const AQuartile : Integer);
begin
  FPreferedInQueueQUartile := AQuartile;
  if FPreferedInQueueQuartile > 4
  then FPreferedInQueueQuartile := 4
  else if FPreferedInQueueQuartile < 1
  then FPreferedInQueueQuartile := 1;
end;


procedure TTrApplication.SetDebug(ADebug : Boolean);
begin
  TrSetDebug(ADebug);
end;


function TTrApplication.GetDebug : Boolean;
begin
  Result := TrGetDebug;
end;


procedure TTrApplication.ZPress;
var
  LCliChar : Char;
  LComm : String;
begin

  // Allow going to texcomm.
  LCliChar := ReadKey;

  // This is strange, but it's the way to read on for scancodes.
  if LCliChar = #0
  then LCliChar := ReadKey;

  if (LCliChar = 'z')
  or (LCliChar = 'Z')
  then begin

    // Stop IPC server while in local console.
    FIpcServer.Active := false;

    Writeln;
    Writeln;
    Writeln('texcomm (core) for ', TrName, '-', TrCode, ' ',
      TrVersion);
    Writeln('Use "help" to display command overview, "bye" to exit.');
    Writeln('While texcomm core is open, texcomm IPC cannot connect.');
    Writeln('Worker management is inactive while texcomm core is open.');
    Writeln;

    while true
    do begin
      Write('texcomm $ ');

      Readln(LComm);

      if  ( (Length(LComm) = 3) and (LComm = 'bye') )
      or  ( (Length(LComm) = 1) and (LComm = 'b') )
      then begin

       // Re-activate IPC server.
        FIpcServer.Active := true;
        Break;
      end else if (Length(LComm) > 0)
      then Interpret(LComm, false);

      // If as result of interpreting we're closing, force exit.
      if FInterrupt
      then Break;
    end;
  end;
end;


procedure TTrApplication.Interpret(const ACommand : String;
  AIsIpc : Boolean);
var
  LParsed : TStringArray;
  LResponse : String;
  LStrings : TStringList;
  LDocument : TTrDocument;
  i : Integer;
  LTmp : Integer;
begin

  // Parse command line into segments by spaces.
  LParsed := TrExplode(DelSpace1(ACommand), [' ']);

  // Connect backchannel if IPC.
  if AIsIpc
  then begin

    // Connect
    try
      FIpcClient.ServerId := LParsed[High(LParsed)-1];
      FIpcClient.ServerInstance := LParsed[High(LParsed)];
      FIpcClient.Active := true;
    except
      Writeln('An IPC request could not be replied to.');
      Exit;
    end;

    // Shorten the remotely sent command parse by two connection
    // parameters.
    if (Length(LParsed) < 3)
    then begin
      FIpcClient.SendStringMessage('No proper command was sent.');
      FIpcClient.Active := false;
      Exit;
    end else SetLength(LParsed, Length(LParsed)-2);
  end;


  // Perform the actual action.
  case LParsed[0]
  of

    'help', 'h' : begin
      if (Length(LParsed) = 1)
      then LResponse := TrCommHelp
      else LResponse := 'Illegal argument(s) to "help" command.';
    end;

    'shutdown', 's' : begin
      if  (Length(LParsed) > 1)
      and (LParsed[1] = IntToStr(FShutdownMagicNumber))
      then begin
        LResponse := 'texrex will be shut down.';
        FInterrupt := true;
      end else LResponse := 'Command "shutdown" was challenged.' +
        #10#13'Pass ' +  IntToStr(FShutdownMagicNumber) +
        ' as argument for shutdown WITHOUT further confirmation.';
    end;

    'dash', 'd' : begin
      if (Length(LParsed) = 1)
      then LResponse := Dash
      else if (Length(LParsed) = 2)
      and ( (LParsed[1] = 'force') or (LParsed[1] = 'f') )
      then begin
        FForceStats := true;
        Sleep(100);
        LResponse := Dash;
      end else LResponse := 'Illegal argument(s) to "dash" command.';
    end;

    'mooo' : begin
      if FRnfgreRtt
      then LResponse := Mooo
      else LResponse := 'You need to find the eggshell-colored key ' +
        'to open this barn door.';
    end;

    'reader', 'r' : begin
      if Length(LParsed) = 2
      then begin
        if LParsed[1] = '+'
        then begin
          FReaderPool.AddThread;
          LResponse := #10#13'Reader/Worker/Writer now: ' +
            IntToStr(FReaderPool.ActiveThreads) + '/' +
            IntToStr(FWorkerPool.ActiveThreads) + '/' +
            IntToStr(FWriterPool.ActiveThreads) + #10#13;
        end else if LParsed[1] = '-'
        then begin
          FReaderPool.RemoveThread;
          LResponse := #10#13'Reader/Worker/Writer now: ' +
            IntToStr(FReaderPool.ActiveThreads) + '/' +
            IntToStr(FWorkerPool.ActiveThreads) + '/' +
            IntToStr(FWriterPool.ActiveThreads) + #10#13;
        end else LResponse := 'Illegal argument(s) to "reader" command.';
      end else LResponse := 'Illegal argument(s) to "reader" command.';
    end;

    'worker', 'wo' : begin
      if Length(LParsed) = 2
      then begin
        if LParsed[1] = '+'
        then begin
          FWorkerPool.AddThread;
          LResponse := #10#13'Reader/Worker/Writer now: ' +
            IntToStr(FReaderPool.ActiveThreads) + '/' +
            IntToStr(FWorkerPool.ActiveThreads) + '/' +
            IntToStr(FWriterPool.ActiveThreads) + #10#13;
        end else if LParsed[1] = '-'
        then begin
          FWorkerPool.RemoveThread;
          LResponse := #10#13'Reader/Worker/Writer now: ' +
            IntToStr(FReaderPool.ActiveThreads) + '/' +
            IntToStr(FWorkerPool.ActiveThreads) + '/' +
            IntToStr(FWriterPool.ActiveThreads) + #10#13;
        end else LResponse := 'Illegal argument(s) to "worker" command.';
      end else LResponse := 'Illegal argument(s) to "worker" command.';
    end;

    'writer', 'wr' : begin
      if Length(LParsed) = 2
      then begin
        if LParsed[1] = '+'
        then begin
          FWriterPool.AddThread;
          LResponse := #10#13'Reader/Worker/Writer now: ' +
            IntToStr(FReaderPool.ActiveThreads) + '/' +
            IntToStr(FWorkerPool.ActiveThreads) + '/' +
            IntToStr(FWriterPool.ActiveThreads) + #10#13;
        end else if LParsed[1] = '-'
        then begin
          FWriterPool.RemoveThread;
          LResponse := #10#13'Reader/Worker/Writer now: ' +
            IntToStr(FReaderPool.ActiveThreads) + '/' +
            IntToStr(FWorkerPool.ActiveThreads) + '/' +
            IntToStr(FWriterPool.ActiveThreads) + #10#13;
        end else LResponse := 'Illegal argument(s) to "writer" command.';
      end else LResponse := 'Illegal argument(s) to "writer" command.';
    end;

    'inqueue', 'iq' : begin
      if (Length(LParsed) = 2)
      and TryStrToInt(LParsed[1], LTmp)
      then begin
        FInQueue.MaxLength := LTmp;
        LResponse := '"In" queue now has maximal length: ' +
          IntToStr(FInQueue.MaxLength);
      end else LResponse := 'Illegal argument(s) to "inqueue" command.';
    end;

    'outqueue', 'oq' : begin
      if (Length(LParsed) = 2)
      and TryStrToInt(LParsed[1], LTmp)
      then begin
        FOutQueue.MaxLength := LTmp;
        LResponse := '"Out" queue now has maximal length: ' +
          IntToStr(FOutQueue.MaxLength);
      end else LResponse := 'Illegal argument(s) to "outqueue" command.';
    end;

    'manage', 'ma' : begin
      if Length(LParsed) = 1
      then begin
        FWorkerManagement := not FWorkerManagement;
        if FWorkerManagement
        then LResponse := 'Worker Management is now on.'
        else LResponse := 'Worker Management is now off.'
      end else LResponse := 'Illegal argument(s) to "conf" command.';
    end;

    'conf', 'c' : begin
      if Length(LParsed) = 1
      then begin
        LStrings := TStringList.Create;
        FIni.ReadSections(LStrings);
        LResponse := #10#13 + LStrings.Text;
        FreeAndNil(LStrings);
      end else if Length(LParsed) =2
      then begin
        if FIni.SectionExists(LParsed[1])
        then begin
          LStrings := TStringList.Create;
          FIni.ReadSectionRaw(LParsed[1], LStrings);
          LResponse := #10#13 + LStrings.Text;
          FreeAndNil(LStrings);
        end else LResponse := 'Section does not exist.';
      end else LResponse := 'Illegal argument(s) to "conf" command.';
    end;

    'peek', 'p' : begin
      i := 0;
      while (not FOutQueue.PopDocument(LDocument))
      and (i < 1000)
      do begin
        Sleep(5);
        Inc(i);
      end;

      if Assigned(LDocument)
      then begin
        LResponse := #10#13 + LDocument.Url + #10#13;
        for i := 0 to LDocument.Number-1
        do LResponse += #10#13 + LDocument[i].Text;
        LResponse += #10#13;

        i := 0;
        while (not FOutQueue.PushDocument(LDocument))
        and (i > 1000)
        do begin
          Sleep(5);
          Inc(i);
        end;
      end else LResponse := 'There was a problem popping a document.';
    end;

    'silence', 'si' : begin
      if Length(LParsed) = 1
      then begin
        FSilent := not FSilent;
        if FSilent
        then LResponse := 'Silent mode is now ON.'
        else LResponse := 'Silent mode is now OFF.';
      end else LResponse := 'Illegal argument(s) to "silence" command.';
    end;

    'ident', 'i' : begin
      if Length(LParsed) = 1
      then LResponse := 'This is texcomm server: ' +
        FIpcId + ' ' + FIpcInstance
      else LResponse := 'Illegal argument(s) to "ident" command.';
    end;

    '42' : if FRnfgreRtt
      then FInterrupt := true
      else LResponse := 'Once you do know what the question actually ' +
        'is, you''ll know what the answer means...';

    else LResponse := 'Command not understood.';
  end;

  if AIsIpc
  then begin
    FIpcClient.SendStringMessage(LResponse);
    FIpcClient.SendStringMessage('<<<texcomm:eom>>>');

    // Disconnect backchannel if IPC.
    FIpcClient.Active := false;
  end else Writeln(LResponse);
end;


function TTrApplication.Dash : String;
begin
  with FStatsWatcher
  do begin
    Result :=
      #10#13'--------------------------------------------------------------' +
      #10#10#13'texrex Dashboard at ' + DateTimeToStr(Now) +

      #10#13'Started: ' + DateTimeToStr(FStarted) + ', uptime: ' +
      FormatDateTime('hh:nn:ss', Now-FStarted) +

      #10#13'Job: ' + FJobname + #10#13'Comment: ' + FComment +

      #10#13'Queue length (in/out): ' + IntToStr(FInQueue.Length) + '/' +
        IntToStr(FOutQueue.Length) +

      #10#10#13'Active readers/workers/writers: ' +
      IntToStr(FReaders) + '/' + IntToStr(FWorkers) + '/' +
      IntToStr(FWriters)+

      #10#13'Input files done (incl. current)/total: ' +
      IntToStr(FFilesDone) + '/' + IntToStr(FFilesTotal) +
      ' (' + FloatToStrF(FFilesDone/FFilesTotal*100, ffGeneral, 4, 2)
      + '%)' +

      #10#13'Documents read/written: ' +
      IntToStr(FDocsRead) + '/' + IntToStr(FDocsWritten) + ' ('+
      FloatToStrF(FDocRatio, ffGeneral, 6, 2) + ':1)' +

      #10#13'Documents read/written per second: ' +
      IntToStr(FDocsRPerSec) + '/' + IntToStr(FDocsWPerSec) +

      #10#13'Data read/written: ' +
      TrBytePrint(FBRead) + '/' + TrBytePrint(FBWritten) + ' (' +
      FloatToStrF(FBRatio, ffGeneral, 6, 2) + ':1)' +

      #10#13'Data read/written per second: ' +
      TrBytePrint(FBRPerSec) + '/' + TrBytePrint(FBWPerSec) +

      #10#13'Links written: ' +
      IntToStr(FLinks) + ' (avg. per document ' +
      FloatToStrF(FAvgLinksPDoc, ffGeneral, 6, 4) + ')' +

      #10#10#13'Invalid after processor...' +
      #10#13'  Stripper:         ' + IntToStr(FInvStripper) +
      #10#13'  Deduplicator:     ' + IntToStr(FInvDupDet) +
      #10#13'  CharsetConverter: ' + IntToStr(FInvCharConv) +
      #10#13'  SecondPass:       ' + IntToStr(FInv2Pass) +
      #10#13'  Utf8Validator:    ' + IntToStr(FInvUtf8Val) +
      #10#13'  SimpleDocFilter:  ' + IntToStr(FInvDocFilt) +
      #10#13'  Deboilerplater:   ' + IntToStr(FInvDeboiler) +
      #10#13'  Tokenizer:        ' + IntToStr(FInvTokenizer) +
      #10#13'  TextAssessment:   ' + IntToStr(FInvTAss) +
      #10#13'  Shingler:         ' + IntToStr(FInvShingler) +
      #10#13'  Normalizer:       ' + IntToStr(FInvNorm) +
      #10#13'  Geolocator:       ' + IntToStr(FInvGeoloc) +

      #10#10#13'The following statistics are for retained documents.' +
      #10#10#13'Average document badness: ' +
      FloatToStrF(FAvgDocBad, ffGeneral, 6, 4) +
      #10#13'Lowest/highest document badness: ' +
      FloatToStrF(FLowestBad, ffGeneral, 6, 4) + '/' +
      FloatToStrF(FHighestBad, ffGeneral, 6, 4) +

      #10#13'Average document token count: ' +
      FloatToStrF(FAvgTokC, ffGeneral, 6, 4) +
      #10#13'Lowest/highest document token count: ' +
      IntToStr(FLowestTokC) +  '/' + IntToStr(FHighestTokC) +

      #10#10#13'--------------------------------------------------------------' +
      #10#13;
  end;
end;


procedure TTrApplication.SetZlsNibevgr(const AThing : String);
var
  LGrzc : String;
begin
  LGrzc := AThing;
  TrSecret(LGrzc);
  if LGrzc = 'Green, green grass!'
  then begin
    FRnfgreRtt := true;
    SWriteln(#10#13 + 'A do' + 'or h' + 'as o' + 'pen' + 'ed on' +
      ' the S' + 'eve' + 'n P' + 'ort' + 'als' + '!');
  end
  else FRnfgreRtt := false;
end;


function TTrApplication.Mooo : String;
begin
  Result := StringReplace(
    #10#13'OOOOO0000000000000000000000000000000000000000OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOOO0OOOOOOOOOOOOOOOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOO00OOOOOOOOOO00OOOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOO000OOOOOOOOO000OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOO000OOOOOOOOO000OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOO000OOOOOOOOO000OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOO000OOOOOOOOO000OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOO00O0OOOOOOOOO0O0OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOO000000000000O0O0OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOO000OO000O00000O0OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOO00OOO00000OO000OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOOOOO000OOOOO000OOOO00OOOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOOOO000000O00OO00OOOOO000OOOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOO000OO0000000O00O00OO0000OOOOOOOO00OOOOO'+
    #10#13'OOOOO00OOOO00OOO000O000O00O000O00O00OOOOOOO00OOOOO'+
    #10#13'OOOOO00OOO00OOO00O00OOO000O000O00OO00OOOOOO00OOOOO'+
    #10#13'OOOOO00OOOO000000OO00000O00OOO000OOO00OOOOO00OOOOO'+
    #10#13'OOOOO00OOOO0000OOOOOO0OOOO0000000OOOO00OOOO00OOOOO'+
    #10#13'OOOOO00O0000OOOOOOOOOOOOOOOO00000OOOO00000000OOOOO'+
    #10#13'OOOOO0000OOOOOOOOOOOOOOOOOO000OO0000000000000OOOOO'+
    #10#13'OOOO000OOOOOOOOOOOOOOOOOOOO00OOOOO000O0000000OOOOO'+
    #10#13'OOO00OOOOOOOOOOOOOOOOOOOOOO00OOOOOOOOO0000000OOOOO'+
    #10#13'OO00O0000OOOOOOOOOOOOOOOOOOO0OOOOOOOO00000000OOOOO'+
    #10#13'OO0OO0000OOOOOOOOOOOOOOOOOOO0OOOOOOO000000000OOOOO'+
    #10#13'OO00O0000OO000OOOOOOOOOOOOOO0OOOOOOO000000000OOOOO'+
    #10#13'OO00OO00OOO0000OOOOOOOOOOOOO0OOOOOOO000000000OOOOO'+
    #10#13'OOO00OOOOOO0000OOOOOOOOO0OOO0OOOOOOO000000000OOOOO'+
    #10#13'OOOO000OOOO000OOOOOOOO000OO00OOOOOOOO00000000OOOOO'+
    #10#13'OOOOO0000OOOOOOOOOOOO000OO00OOOOOOOOOO0000000OOOOO'+
    #10#13'OOOOO0000000OOOOO00000OOO00OOOOOOOOOOOO000000OOOOO'+
    #10#13'OOOOO00OOO000000000OO00000OOOOOOOOOOOOO000000OOOOO'+
    #10#13'OOOOO00OOOOOOO000000000OOOOOOOOOOOOOO00000000OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOOOOO00OOOOOOOOOOOOO000000000OOOOO'+
    #10#13'OOOOO00OOOOOOOOOOOOOO00OOOOOOOOOOO00000000000OOOOO'+
    #10#13'OOOOO0000000000000000000000000000000000000000OOOOO',
    'O', ' ', [rfReplaceAll]);
end;


procedure TTrApplication.SWrite(const ALine : String = '');
begin
  if not FSilent
  then Write(ALine);
end;


procedure TTrApplication.SWriteln(const ALine : String = '');
begin
  if not FSilent
  then Writeln(ALine);
end;


procedure TTrApplication.ShowHelp;
begin
  Writeln(#10#13'Usage:  texrex --job=FILENAME | -j FILENAME');
  Writeln(#10#13'FILENAME must be the name of a texrex job INI ' +
    'file as specified'#10#13'in the manual.');
  Writeln(#10#13, 'Other options:');
  Writeln(#13, '-v   --version  Display version information and exit.');
  Writeln(#13, '-h   --help     Display this help an exit.');
  Writeln;
end;


end.
