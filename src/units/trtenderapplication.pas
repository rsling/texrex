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


unit TrTenderApplication;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  CustApp,
  Classes,
  Contnrs,
  SysUtils,
  StrUtils,
  TrVersionInfo,
  TrUtilities,
  TrFile,
  TrShingleHelpers;


type

  ETrTenderApplication = class(Exception);

  TTrTenderPhase = (
    ttspSortShingles,   // Threaded.
    ttspMergeToDocDoc,  // Threaded. Shingle merging + doc-doc creation
    ttspDocDocToBlacklist
  );

const
  TTrTenderPhaseStr :
    array[ttspSortShingles..ttspDocDocToBlacklist] of String = (
      '01.sortedshingles',
      '02.sorteddocdocpairs',
      '03.blacklist'
    );

type
  TTrTenderApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FInFileMask : String;
    FOutFilePrefix : String;

    // This is used to exclude documents from previous blacklistings,
    // i.e., if tender is run in subsequent steps in a divide strategy.
    FBlacklist : TFPHashList;

    // Time string to be added to file names.
    FTime : String;

    // Which phase of the process we are currently performing.
    FPhase : TTrTenderPhase;

    // Notice that the TTrFileIn readers free these when done.
    FInFiles : TStringList;             // Shingle files from texrex.
    FSortedShingleFiles : TStringList;  // Filled in ttspSortShingles.
    FDocDocFiles : TStringList;         // Filled in ttspMergeToDocDoc.

    FGzip : Boolean;
    FDebug : Boolean;

    // Shingles are already sorted.
    FSorted : Boolean;

    // Number of allowed parallel sorter threads.
    FThreadNumber : Integer;
    FSortSize : Integer;
    FDocDocSize : Integer;

    FThreshold : Integer;              // Shared shingle threshold.
    FMaxShingle : Integer;             // Maximal shingle redundancy threshold.

    FExternalGzip : String;

    procedure SortShingles;
    procedure MergeShinglesToDocDoc;
    procedure MergeDocDocToBlacklist;

    function NextFileName : String;
    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;


implementation



const
  OptNum = 12;
  OptionsShort : array[0..OptNum] of Char = ('i', 'o', 't',
    'l', 'm', 'h', 'g', 's', 'p', 'f', 'd', 'b', 'z');
  OptionsLong : array[0..OptNum] of String = ('input', 'output',
    'threads', 'limit', 'max', 'help', 'gzip', 'size', 'presort',
    'full', 'ddsize', 'blacklist', 'gzbin');


constructor TTrTenderApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FSorted := false;
  FGzip := false;
  FThreadNumber := 1;
  FSortSize := 6000000;
  FDocDocSize :=  2000000;
  FThreshold := 5;
  FMaxShingle := 200;
end;


destructor TTrTenderApplication.Destroy;
begin
  FreeAndNil(FSortedShingleFiles);
  FreeAndNil(FDocDocFiles);
  FreeAndNil(FBlacklist);
end;


procedure TTrTenderApplication.Initialize;
var
  LOptionError : String;
  LBlackFile : String;
  LBlacklistFiles : TStringList;
begin
  inherited Initialize;

  Writeln(#10#13, 'tender from ', TrName, '-', TrCode, ' (', TrVersion,
    ')', #10#13, TrMaintainer, #10#13);

  LOptionError := CheckOptions(OptionsShort, OptionsLong);
  if LOptionError <> ''
  then begin
    SayError(LOptionError);
    Exit;
  end;

  if HasOption('h', 'help')
  then begin
    ShowHelp;
    Terminate;
    Exit;
  end;

  if not HasOption('i', 'input')
  then begin
    SayError('No input file mask specified.');
    Exit;
  end;

  if not HasOption('o', 'output')
  then begin
    SayError('No output file name prefix specified.');
    Exit;
  end;

  FInFileMask := GetOptionValue('i', 'input');
  FOutFilePrefix := GetOptionValue('o', 'output');

  // Try to create input file list.
  TrBuildFileList(FInFileMask, FInFiles);
  if (FInFiles.Count < 1)
  then begin
    SayError('No files were found which match the pattern.');
    Exit;
  end;

  // Read facultative options.

  // Try loading blacklist file.
  FBlacklist := nil;
  LBlacklistFiles := nil;
  if HasOption('b', 'black')
  then begin
    Write('Reading blacklist... ');
    LBlackFile := GetOptionValue('b', 'black');
    try
      TrBuildFileList(LBlackFile, LBlacklistFiles);
      TrLoadHashListFromFiles(LBlacklistFiles, FBlacklist);
    except
      SayError('could not be loaded!');
    end;

    if Assigned(FBlacklist)
    then Writeln(FBlacklist.Count, ' entries.')
    else Writeln('not assigned.');
  end;

  if HasOption('g', 'gzip')
  then FGzip := true;

  if HasOption('p', 'presort')
  then FSorted := true;

  if HasOption('f', 'full')
  then FDebug := true;

  if HasOption('t', 'threads')
  then begin
    if not TryStrToInt(GetOptionValue('t', 'threads'), FThreadNumber)
    then begin
      SayError('Thread number must be an integer.');
      Exit;
    end;
  end;

  if HasOption('s', 'size')
  then begin
    if not TryStrToInt(GetOptionValue('s', 'size'), FSortSize)
    then begin
      SayError('Sort split size must be an integer.');
      Exit;
    end;
  end;

  if HasOption('d', 'ddsize')
  then begin
    if not TryStrToInt(GetOptionValue('d', 'ddsize'), FDocDocSize)
    then begin
      SayError('Doc-doc split size must be an integer.');
      Exit;
    end;
  end;

  if HasOption('l', 'limit')
  then begin
    if not TryStrToInt(GetOptionValue('l', 'limit'), FThreshold)
    then begin
      SayError('Shared shingle threshold must be an integer.');
      Exit;
    end;
  end;

  if HasOption('m', 'max')
  then begin
    if not TryStrToInt(GetOptionValue('m', 'max'), FMaxShingle)
    then begin
      SayError('Maximal overlap must be an integer.');
      Exit;
    end;
  end;

  // By default, no external gzip.
  FExternalGzip := '';
  if HasOption('z', 'gzbin')
  then begin
    FExternalGzip := GetOptionValue('z', 'gzbin');
    if not FileExists(FExternalGzip)
    then begin
      SayError('External gzip program does not exist.');
      Exit;
    end;
  end;

  FTime := FormatDateTime('YYYY-MM-DD_hh-nn-z', Now);
  FSortedShingleFiles := TStringList.Create;
  FDocDocFiles := TStringList.Create;
end;


procedure TTrTenderApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


function TTrTenderApplication.NextFileName : String;
begin

  // Create the common part of the file name.
  Result :=
    FOutFilePrefix + '_' + FTime + '.' +
    TTrTenderPhaseStr[FPhase] + '.';

  // Increase counter and save file name.
  case FPhase
  of

    ttspSortShingles : begin
      Result += TrPad(12, IntToStr(FSortedShingleFiles.Count));
      if FGzip
      then Result += '.gz';
      FSortedShingleFiles.Add(Result);
    end;

    ttspMergeToDocDoc : begin
      Result += TrPad(12, IntToStr(FDocDocFiles.Count));
      if FGzip
      then Result += '.gz';
      FDocDocFiles.Add(Result);
    end;

    else begin
      Result := '';
      Exit;
    end;
  end;
end;


procedure TTrTenderApplication.SortShingles;
var
  LSorterPack : TTrSorterPack = nil;
  LLine : String;
  LReader : TTrFileIn;
  LSorterPackQueue : TTrSorterPackQueue;
  LSorters : TTrSorters;
  i : Integer;
  LLastReport : QWord = 0;
begin

  LSorterPackQueue := TTrSorterPackQueue.Create;
  LReader := TTrFileIn.Create(FInFiles, true, FExternalGzip);

  // Create the sorters.
  Write('Creating sorter threads... ');
  SetLength(LSorters, FThreadNumber);
  for i := 0 to FThreadNumber-1
  do LSorters[i] := TTrSorter.Create(LSorterPackQueue, FGzip);
  Writeln('done.');

  try

    // Read lines and feed in packages to queue.
    repeat

      // Show some activity.
      if ((LReader.Bytes - LLastReport) > 10485760)
      then begin
        Write(#13, 'Reading: ', LReader.CurrentFileName, ' (',
          TrBytePrint(LReader.Bytes), ')');
        LLastReport := LReader.Bytes;
      end;

      // Create a new list if necessary.
      if (not Assigned(LSorterPack))
      then LSorterPack := TTrSorterPack.Create(NextFileName);

      // Just continue filling a healthy and non-full list.
      LReader.ReadLine(LLine);

      if (Length(LLine) = ShingleLineLength)
      then begin
        if ( not Assigned(FBlacklist) )
        or ( not Assigned(
          FBlacklist.Find(AnsiMidStr(LLine, DocIdOffset,
          DocIdLength))) )
        then LSorterPack.Strings.Add(LLine)
      end else Writeln('Warning! A line had the wrong length: '#10#13,
        LLine);

      // Push a full list onto the queue, or a non-full one when
      // EOS was reached.
      if (LSorterPack.Strings.Count >= FSortSize)
      or LReader.Eos
      then begin

        // We only push as many objects as there are threads to control
        // memory usage.
        while (LSorterPackQueue.Count >= FThreadNumber)
        or (not LSorterPackQueue.PushTS(LSorterPack))
        do Sleep(100);

        LSorterPack := nil;
      end;
    until LReader.Eos;
    Writeln(#13);

    Write('Waiting for the sort pack queue to empty... ');

    // Wait for the queue top empty.
    while LSorterPackQueue.Count > 0
    do Sleep(100);

    Writeln('done.');
    Write('Terminating sorter threads... ');

    // Now we wait for the sorters to finish.
    for i := 0 to High(LSorters)
    do LSorters[i].Terminate;
    Writeln('done.');

    Write('Waiting for sorter threads to finish... ');
    for i := 0 to High(LSorters)
    do LSorters[i].WaitFor;
    Writeln('done.');

  finally
    Write('Freeing sort resources... ');
    FreeAndNil(LSorterPackQueue);
    FreeAndNil(LReader);
    for i := 0 to FThreadNumber-1
    do FreeAndNil(LSorters[i]);
    SetLength(LSorters, 0);
    Writeln('done.');
  end;
end;


procedure TTrTenderApplication.MergeShinglesToDocDoc;
var
  LMerger : TTrMerger;
  LLine : String;
  k : Integer = 0;
  i : Integer;
  LCreators : TTrDocDocCreators;
  LSorterPack : TTrSorterPack = nil;
  LSorterPackQueue : TTrSorterPackQueue;
  LFiles : TStringList;
begin

  if FSorted
  then LFiles := FInFiles
  else LFiles := FSortedShingleFiles;

  Write('Creating merger object for ', LFiles.Count,
    ' files... ');
  LMerger := TTrMerger.Create(LFiles);
  Writeln('done.');

  LSorterPackQueue := TTrSorterPackQueue.Create;

  Write('Creating doc-doc pair creator threads... ');
  SetLength(LCreators, FThreadNumber);
  for i := 0 to FThreadNumber-1
  do LCreators[i] := TTrDocDocCreator.Create(LSorterPackQueue,
    FMaxShingle, FGzip);
  Writeln('done.');

  try
    Writeln('Merging files and sending them to doc-doc pair creators.');

    // Read sorted lines from merger object and pass those block with
    // identical shingle value to the permuters.
    while (LMerger.NextLine(LLine) >= 0)
    do begin

      // Report something to the console to keep user calm.
      if (k mod 10000 = 0)
      then Write(#13, 'Merged ', k, ' lines (Q: ',
        LSorterPackQueue.Count, ').');
      Inc(k);

      // If we have reached the maximal portion of shingles to create
      // doc-doc pairs from - AND - this is a new shingle, then
      // send the current package to the queue and create a new one.

      // Create a new list to be passed to permuters if necessary.
      if (not Assigned(LSorterPack))
      then LSorterPack := TTrSorterPack.Create(NextFileName)

      // There already is a list. If it is "full", create new one.
      else if (LSorterPack.Strings.Count >= FDocDocSize)
      and (AnsiLeftStr(LLine, ShingleLength) <>
        AnsiLeftStr(LSorterPack.Strings[LSorterPack.Strings.Count-1],
        ShingleLength))
      then begin

        // We only push as many objects as there are threads to control
        // memory usage.
        while (LSorterPackQueue.Count >= FThreadNumber)
        or (not LSorterPackQueue.PushTS(LSorterPack))
        do Sleep(100);

        LSorterPack := nil;
        LSorterPack := TTrSorterPack.Create(NextFileName);
      end;

      // We now definitely have an appropriate (new) list. Add line.
      LSorterPack.Strings.Add(LLine);

    end;
    Writeln(#13, 'Merged ', k, ' lines.                              ');

    // Push last pack.
    while not LSorterPackQueue.PushTS(LSorterPack)
    do Sleep(100);

    // Wait for the queue top empty.
    Write('Waiting for the sort pack queue to empty... ');
    while LSorterPackQueue.Count > 0
    do Sleep(100);

    Writeln('done.');
    Write('Terminating sorter threads... ');

    // Now we wait for the sorters to finish.
    for i := 0 to High(LCreators)
    do LCreators[i].Terminate;
    Writeln('done.');

    Write('Waiting for sorter threads to finish... ');
    for i := 0 to High(LCreators)
    do LCreators[i].WaitFor;
    Writeln('done.');

  finally
    Write('Freeing sort resources... ');
    FreeAndNil(LSorterPackQueue);
    for i := 0 to High(LCreators)
    do FreeAndNil(LCreators[i]);
    FreeAndNil(LMerger);
    if FSorted
    then FreeAndNil(FInFiles);
    Writeln('done.');
  end;
end;


procedure TTrTenderApplication.MergeDocDocToBlacklist;
var
  LMerger : TTrMerger;
  LWriter : TTrFileOut;
  LDebugWriter : TTrFileOut;
  LFileName : String;
  LDebugFileName : String = '';
  LLine : String;
  k : Integer = 0;
  LCurrentLine : String = '';
  LCurrentCount : Integer = 0;
  LBlacklistItem : String = '';
  LLastBlacklisted : String = '';
begin

  // This is basically just a run-length encoding.

  Write('Creating merger object for ', FDocDocFiles.Count,
    ' files... ');
  LMerger := TTrMerger.Create(FDocDocFiles);
  Writeln('done.');

  LFileName := FOutFilePrefix + '_' + FTime + '.' +
    TTrTenderPhaseStr[FPhase];
  if FGzip
  then LFileName += '.gz';
  Writeln('Creating blacklist file ', LFileName, '.');
  LWriter := TTrFileOut.Create(LFileName, FGzip);

  if FDebug
  then begin
    LDebugFileName := FOutFilePrefix + '_' + FTime + '.' +
      TTrTenderPhaseStr[FPhase] + '-full';
    if FGzip
    then LDebugFileName += '.gz';
    Writeln('Creating blacklist file ', LDebugFileName, '.');
    LDebugWriter := TTrFileOut.Create(LDebugFileName, FGzip);
  end;

  try
    Writeln('Merging files and doing run-length encoding.');
    while (LMerger.NextLine(LLine) >= 0)
    do begin

      // Report something to the console to keep user happy.
      if (k mod 1000 = 0)
      then Write(#13, 'Merged/counted ', k, ' lines.');
      Inc(k);

      // If this line is like the last line, we keep counting.
      if (LLine = LCurrentLine)
      then Inc(LCurrentCount)

      // If not, then we blacklist the left (=shorter) document id
      // if the threshold is exceeded. Also, reset the current RLE
      // line and reset the counter.
      else begin
        if (LCurrentCount >= FThreshold)
        then begin
          LBlacklistItem := AnsiLeftStr(LCurrentLine, DocIdLength);
          if not (LBlacklistItem = LLastBlacklisted)
          then LWriter.WriteString(LBlacklistItem);
          LLastBlacklisted := LBlacklistItem;

          if FDebug
          then LDebugWriter.WriteString(LCurrentLine + ' ' +
            TrPad(4, IntToStr(LCurrentCount)));
        end;

        LCurrentLine := LLine;
        LCurrentCount := 1;
      end;
    end;
    Writeln(#13, 'Merged/counted ', k, ' lines.');

  finally
    Write('Freeing merge/RLE resources... ');
    FreeAndNil(LMerger);
    FreeAndNil(LWriter);
    if FDebug
    then FreeAndNil(LDebugWriter);
    Writeln('done.'#10#13);
  end;
end;


procedure TTrTenderApplication.DoRun;
begin

  // There is no master loop. We run through this only once, then
  // terminate. This is really just a script kind of program.
  if not Terminated
  then try

    if not FSorted
    then begin
      Writeln('Sorting shingles.');
      FPhase := ttspSortShingles;
      SortShingles;
    end;

    Writeln('Merging shingles.');
    FPhase := ttspMergeToDocDoc;
    MergeShinglesToDocDoc;

    Writeln('Merging doc-doc pairs, counting overlap/blacklisting.');
    FPhase := ttspDocDocToBlacklist;
    MergeDocDocToBlacklist;

  finally
    Terminate;
  end;
end;


procedure TTrTenderApplication.ShowHelp;
begin
  Writeln(#10#13'Usage:  tender OPTIONS');
  Writeln;
  Writeln('Options without default in square brackets are obligatory.');
  Writeln('S stands for a string argument, I for an integer argument.');
  Writeln;
  Writeln(' --help    -h   Print this help and exit.');
  Writeln(' --input   -i S File name mask defining input (wildcards allowed).');
  Writeln(' --output  -o S Output file prefix.');
  Writeln(' --black   -b S Use previous blacklists (wildcards allowed).');
  Writeln(' --gzip    -g   Use gzip compression for temp/output files. [no]');
  Writeln(' --threads -t I Maximal number of parallel sorting threads. [1]');
  Writeln(' --size    -s I How many lines to sort in one split. [6000000]');
  Writeln(' --ddsize  -d I How many lines to send to doc-doc pair creator. [2000000]');
  Writeln(' --presort -p   Shingle files are already pre-sorted. [no]');
  Writeln(' --limit   -l I Shared shingle threshold for blacklisting. [5]');
  Writeln(' --max     -m I Maximal overlap to process (performance hack). [200]');
  Writeln(' --full    -f   Write full doc-doc ID pairs of duplicates. [no]');
  Writeln(' --gzbin   -z S External gzip command.');
  Writeln;
  Writeln('Note: Enclose file name patterns with wildcards in "" or '''' to');
  Writeln('      keep your shell from expanding them.');
  Writeln;
  Writeln('Note: Tools like GNU sort are kind of faster than tender. If you use');
  Writeln('      the -s option on pre-sorted files, you can save time. Also,');
  Writeln('      merging them (even partially) might help. Cf. texrex manual.');
  Writeln;
end;


procedure TTrTenderApplication.SayError(const AError : String);
begin
  Writeln(#10#13, 'Error: ', AError);
  Writeln('Use "tender -h" or "tender --help" to get help.', #10#13);
  Terminate;
end;


end.
