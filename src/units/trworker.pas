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

unit TrWorker;

{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  Classes,
  Contnrs,
  SyncObjs,
  SysUtils,
  CTypes,
  IniFiles,
  TrUtilities,
  TrQueues,
  TrData,
  TrDocumentProcessor,
  TrHtmlStripper,
  TrGeolocator,
  TrDuplicateDetector,
  TrCharsetConverter,
  TrSecondPass,
  TrUtf8Validator,
  TrDeboilerplater,
  TrSimpleDocumentFilter,
  TrUnicodeLetterRangeTokenizer,
  TrRabinHash,
  TrShingler,
  TrTextAssessment,
  TrNormalizer,
  TrDivDeduplicator,
  TrMetaExtractor,
  TrNfcNormalizer;



type

  ETrWorker = class(Exception);

  TTrWorkerPool = class;

  TTrWorker = class(TThread)
  public
    constructor Create(const APool : TTrWorkerPool;
      const AFromQueue : TTrDocumentQueue;
      const AToQueue : TTrDocumentQueue;
      const AIni : TIniFile);
    destructor Destroy; override;

  protected
    FPool : TTrWorkerPool;
    FIni : TIniFile;
    FFromQueue : TTrDocumentQueue;
    FToQueue : TTrDocumentQueue;

    // Internal buffers to minimize communication with queues.
    FInBuffer : TTrDocumentArray;
    FOutBuffer : TTrDocumentArray;

    // Processors.
    FStripper : TTrHtmlStripper;
    FGeolocator : TTrGeolocator;
    FDuplicates : TTrDuplicateDetector;
    FCharsetConverter : TTrCharsetConverter;
    FSecondPass : TTrSecondPass;
    FUtf8Validator : TTrUtf8Validator;
    FDeboilerplater : TTrDeboilerplater;
    FSimpleDocumentFilter : TTrSimpleDocumentFilter;
    FUnicodeLetterRangeTokenizer : TTrUnicodeLetterRangeTokenizer;
    FShingler : TTrShingler;
    FTextAssessment : TTrTextAssessment;
    FTextAssessmentMulti : TTrTextAssessmentMulti;
    FNfcNormalizer : TTrNfcNormalizer;
    FDivDeduplicator : TTrDivDeduplicator;
    FNormalizer : TTrNormalizer;
    FMetaExtractor : TTrMetaExtractor;

    procedure Execute; override;
  end;

  TTrWorkerArray = array of TTrWorker;

  // A class that controls a pool of workers and runs entirely in main
  // thread itself.
  TTrWorkerPool = class(TPersistent)
  public
    constructor Create(const AFromQueue : TTrDocumentQueue;
      const AToQueue : TTrDocumentQueue; AIni : TIniFile);
    destructor Destroy; override;
    procedure TerminateAll;
    function GetActiveThreads : Integer;
    procedure RemoveThread;
    procedure AddThread;

  protected
    FWorkers : TTrWorkerArray;
    FIni : TIniFile;
    FFromQueue : TTrDocumentQueue;
    FToQueue   : TTrDocumentQueue;

    // For the threads.
    FBufferSize : Integer;
    FPopSleep : Integer;
    FPushSleep : Integer;
    FPushLimit : Integer;
    FWorkerNumber : Integer;
    FMaxWorkerNumber : Integer;
    FMinWorkerNumber : Integer;
    FBloomErrorRate : Real;
    FGeoBlocksFile : String;
    FGeoLocationsFile : String;

    // (De)activate processors.
    FUseGeolocator : Boolean;
    FUseDuplicateDetector : Boolean;
    FUseSimpleFilter : Boolean;
    FUseUtf8Validator : Boolean;
    FUseDeboilerplater : Boolean;
    FUseTextAssessment : Boolean;
    FUseTextAssessmentMulti : Boolean;
    FUseShingler : Boolean;
    FUseNormalizer : Boolean;
    FUseDivDeduplicator : Boolean;
    FUseNfcNormalizer : Boolean;
    FUseMetaExtractor : Boolean;

    // Statistics.
    FInvalidAfterStripper : QWord;
    FInvalidAfterGeolocator : QWord;
    FInvalidAfterDuplicateDetector : QWord;
    FInvalidAfterCharsetConverter : QWord;
    FInvalidAfterSecondPass : QWord;
    FInvalidAfterUtf8Validator : QWord;
    FInvalidAfterSimpleDocumentFilter : QWord;
    FInvalidAfterDeboilerplater : QWord;
    FInvalidAfterTokenizer : QWord;
    FInvalidAfterShingler : QWord;
    FInvalidAfterTextAssessment : QWord;
    FInvalidAfterNormalizer : QWord;
    FInvalidAfterDivDeduplicator : QWord;
    FInvalidAfterMetaExtractor : QWord;

    // Some statistics.
    FAllBadness : QWord;
    FAllUsableDocuments : QWord;
    FLowestBadness : Real;
    FHighestBadness : Real;
    FAllTokenCount : QWord;
    FLowestTokenCount : Integer;
    FHighestTokenCount : Integer;

  public
    property ActiveThreads : Integer read GetActiveThreads;
    property AllBadness : QWord read FAllBadness;
    property AllUsableDocuments : QWord read FAllUsableDocuments;
    property LowestBadness : Real read FLowestBadness;
    property HighestBadness : Real read FHighestBadness;
    property AllTokenCount : QWord read FAllTokenCount;
    property LowestTokenCount : Integer read FLowestTokenCount;
    property HighestTokenCount : Integer read FHighestTokenCount;

    property InvalidAfterStripper : QWord
      read FInvalidAfterStripper;
    property InvalidAfterGeolocator : QWord
      read FInvalidAfterGeolocator;
    property InvalidAfterDuplicateDetector : QWord
      read FInvalidAfterDuplicateDetector;
    property InvalidAfterCharsetConverter : QWord
      read FInvalidAfterCharsetConverter;
    property InvalidAfterSecondPass : QWord
      read FInvalidAfterSecondPass;
    property InvalidAfterUtf8Validator : QWord
      read FInvalidAfterUtf8Validator;
    property InvalidAfterSimpleDocumentFilter : QWord
      read FInvalidAfterSimpleDocumentFilter;
    property InvalidAfterDeboilerplater : QWord
      read FInvalidAfterDeboilerplater;
    property InvalidAfterTokenizer : QWord read FInvalidAfterTokenizer;
    property InvalidAfterTextAssessment : QWord
      read FInvalidAfterTextAssessment;
    property InvalidAfterShingler : QWord read FInvalidAfterShingler;
    property InvalidAfterNormalizer : QWord
      read FInvalidAfterNormalizer;
    property InvalidAfterMetaExtractor : QWord
      read FInvalidAfterMetaExtractor;

  published
    property UseGeolocator : Boolean read FUseGeolocator
      write FUseGeolocator default false;
    property UseDuplicateDetector : Boolean read FUseDuplicateDetector
      write FUseDuplicateDetector default true;
    property UseSimpleFilter : Boolean read FUseSimpleFilter
      write FUseSimpleFilter default true;
    property UseUtf8Validator : Boolean read FUseUtf8Validator
      write FUseUtf8Validator default true;
    property UseDeboilerplater : Boolean read FUseDeboilerplater
      write FUseDeboilerplater default true;
    property UseTextAssessmentMulti : Boolean read FUseTextAssessmentMulti
      write FUseTextAssessmentMulti default false;
    property UseTextAssessment : Boolean read FUseTextAssessment
      write FUseTextAssessment default true;
    property UseShingler : Boolean read FUseShingler
      write FUseShingler default true;
    property UseNormalizer : Boolean read FUseNormalizer
      write FUseNormalizer default true;
    property UseDivDeduplicator : Boolean
      read FUseDivDeduplicator write FUseDivDeduplicator
      default true;
    property UseNfcNormalizer : Boolean read FUseNfcNormalizer
      write FUseNfcNormalizer default true;
    property UseMetaExtractor : Boolean
      read FUseMetaExtractor write FUseMetaExtractor
      default true;
    property BufferSize : Integer read FBufferSize write FBufferSize
      default 10;
    property PopSleep : Integer read FPopSleep write FPopSleep
      default 5;
    property PushSleep : Integer read FPushSleep write FPushSleep
      default 5;
    property PushLimit : Integer read FPushLimit write FPushLimit
      default 999999;
    property WorkerNumber : Integer read FWorkerNumber
      write FWorkerNumber default 1;
    property MaxWorkerNumber : Integer read FMaxWorkerNumber
      write FMaxWorkerNumber default 4;
    property MinWorkerNumber : Integer read FMinWorkerNumber
      write FMinWorkerNumber default 1;
    property BloomErrorRate : Real read FBloomErrorRate
      write FBloomErrorRate;
    property GeoBlocksFile : String read FGeoBlocksFile
      write FGeoBlocksFile;
    property GeoLocationsFile : String read FGeoLocationsFile
      write FGeoLocationsFile;
  end;



implementation



constructor TTrWorker.Create(const APool : TTrWorkerPool;
  const AFromQueue : TTrDocumentQueue;
  const AToQueue : TTrDocumentQueue;
  const AIni : TIniFile);
begin

  // Call the inherited create for non-suspended and with default
  // stack size.
  inherited Create(false);

  if (not Assigned(APool))
  or (not Assigned(AFromQueue))
  or (not Assigned(AToQueue))
  or (not Assigned(AIni))
  then Terminate
  else begin
    FIni := AIni;
    FPool := APool;
    FFromQueue := AFromQueue;
    FToQueue   := AToQueue;
  end;

  // Create processor chain.

  if FPool.FUseDuplicateDetector
  then FDuplicates := TTrDuplicateDetector.Create(FIni);

  FStripper := TTrHtmlStripper.Create(FIni);
  FCharsetConverter := TTrCharsetConverter.Create(FIni);
  FSimpleDocumentFilter := TTrSimpleDocumentFilter.Create(FIni);

  if FPool.FUseMetaExtractor
  then FMetaExtractor := TTrMetaExtractor.Create(FIni);

  FSecondPass := TTrSecondPass.Create(FIni);

  if FPool.FUseUtf8Validator
  then FUtf8Validator := TTrUtf8Validator.Create(FIni);

  if FPool.FUseDeboilerplater
  then FDeboilerplater := TTrDeboilerplater.Create(FIni);

  if FPool.FUseShingler
  or FPool.FUseTextAssessment
  or FPool.FUseTextAssessmentMulti
  then FUnicodeLetterRangeTokenizer :=
    TTrUnicodeLetterRangeTokenizer.Create(FIni);

  if FPool.FUseTextAssessment
  then FTextAssessment := TTrTextAssessment.Create(FIni);

  if FPool.FUseTextAssessmentMulti
  then FTextAssessmentMulti := TTrTextAssessmentMulti.Create(FIni);

  if FPool.FUseShingler
  then FShingler := TTrShingler.Create(FIni);

  if FPool.FUseNormalizer
  then FNormalizer := TTrNormalizer.Create(FIni);

  if FPool.FUseDivDeduplicator
  then FDivDeduplicator := TTrDivDeduplicator.Create(FIni);

  if FPool.FUseNfcNormalizer
  then FNfcNormalizer := TTrNfcNormalizer.Create(FIni);

  if FPool.FUseGeolocator
  then FGeolocator := TTrGeolocator.Create(FIni);

  // END creation of processor chain.

  // For the internal buffer.
  SetLength(FInBuffer, FPool.FBufferSize);
  SetLength(FOutBuffer, FPool.FBufferSize);

end;


destructor TTrWorker.Destroy;
begin

  FreeAndNil(FDuplicates);
  FreeAndNil(FStripper);
  FreeAndNil(FCharsetConverter);
  FreeAndNil(FSimpleDocumentFilter);
  FreeAndNil(FMetaExtractor);
  FreeAndNil(FSecondPass);
  FreeAndNil(FUtf8Validator);
  FreeAndNil(FDeboilerplater);
  FreeAndNil(FUnicodeLetterRangeTokenizer);
  FreeAndNil(FTextAssessment);
  FreeAndNil(FTextAssessmentMulti);
  FreeAndNil(FShingler);
  FreeAndNil(FNormalizer);
  FreeAndNil(FDivDeduplicator);
  FreeAndNil(FNfcNormalizer);
  FreeAndNil(FGeolocator);

  inherited Destroy;
end;


procedure TTrWorker.Execute;
var
  LDocuments : TTrDocumentArray;
  i : Integer;
  l : QWord;
  LMetaExtract : String;

  // This exectues the processing in a try environment and frees the
  // document if an exception occurs.
  function TryProc(const AProc : TTrDocProc;
    const ADoc : TTrDocument; const AIdent : String) : Boolean;
    inline;
  begin
    Result := true;
    try
      AProc(ADoc);
    except
      Result := false;
      FreeAndNil(LDocuments[i]);
      TrDebug(ClassName + ' in ' + AIdent, Exception(ExceptObject));
    end;
  end;

begin
  while not Terminated
  do begin

    // It the queue is gone, we exit for good.
    if Assigned(FFromQueue)
    then LDocuments := FFromQueue.PopDocuments(FPool.FBufferSize)
    else Exit;

    // Retry for as long as instructed to get a document.
    if (Length(LDocuments) < 1)
    then begin
      Sleep(FPool.FPopSleep);
      Continue;
    end;

    // Terminate if after all retries, nothing was returned.
    for i := 0 to High(LDocuments)
    do begin
      if Assigned(LDocuments[i])
      then begin

        if FPool.FUseDuplicateDetector
        then begin
          if not TryProc(@FDuplicates.Process, LDocuments[i],
            'DuplicateDetector')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterDuplicateDetector);
            Continue;
          end;
        end;

        if not TryProc(@FStripper.Process, LDocuments[i], 'Stripper')
        then Continue;
        if (not LDocuments[i].Valid)
        then begin
          FreeAndNil(LDocuments[i]);
          Inc(FPool.FInvalidAfterStripper);
          Continue;
        end;

        if not TryProc(@FCharsetConverter.Process, LDocuments[i],
          'CharsetConverter')
        then Continue;
        if (not LDocuments[i].Valid)
        then begin
          FreeAndNil(LDocuments[i]);
          Inc(FPool.FInvalidAfterCharsetConverter);
          Continue;
        end;

        if FPool.FUseSimpleFilter
        then begin
          if not TryProc(@FSimpleDocumentFilter.Process, LDocuments[i],
            'SimpleDocumentFilter')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterSimpleDocumentFilter);
            Continue;
          end;
        end;

        if FPool.FUseMetaExtractor
        then begin
          if not TryProc(@FMetaExtractor.Process, LDocuments[i],
            'MetaExtractor')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterMetaExtractor);
            Continue;
          end;
        end;

        if not TryProc(@FSecondPass.Process, LDocuments[i],
          'SecondPass')
        then Continue;
        if (not LDocuments[i].Valid)
        then begin
          FreeAndNil(LDocuments[i]);
          Inc(FPool.FInvalidAfterSecondPass);
          Continue;
        end;

        if FPool.FUseUtf8Validator
        then begin
          if not TryProc(@FUtf8Validator.Process, LDocuments[i],
            'Utf8Validator')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterUtf8Validator);
            Continue;
          end;
        end;

        if FPool.FUseDeboilerplater
        then begin
          if FPool.FUseDeboilerplater
          then begin
            if not TryProc(@FDeboilerplater.Process, LDocuments[i],
              'Deboilerplater')
            then Continue;
          end;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterDeboilerplater);
            Continue;
          end;
        end;

        if FPool.FUseShingler
        or FPool.FUseTextAssessment
        or FPool.FUseTextAssessmentMulti
        then begin
          if not TryProc(@FUnicodeLetterRangeTokenizer.Process,
            LDocuments[i], 'UnicodeLetterRangeTokenizer')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterTokenizer);
            Continue;
          end;
        end;

        if FPool.FUseTextAssessment
        then begin
          if not TryProc(@FTextAssessment.Process, LDocuments[i],
            'TestAssessment')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterTextAssessment);
            Continue;
          end;
        end;

        if FPool.FUseTextAssessmentMulti
        then begin
          if not TryProc(@FTextAssessmentMulti.Process, LDocuments[i],
            'TestAssessmentMulti')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterTextAssessment);
            Continue;
          end;
        end;

        if FPool.FUseShingler
        then begin
          if not TryProc(@FShingler.Process, LDocuments[i], 'Shingler')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterShingler);
            Continue;
          end;
        end;

        if FPool.FUseNormalizer
        then begin
          if not TryProc(@FNormalizer.Process, LDocuments[i],
            'Normalizer')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterNormalizer);
            Continue;
          end;
        end;

        if FPool.FUseNfcNormalizer
        then begin
          if not TryProc(@FNfcNormalizer.Process, LDocuments[i],
            'NfcNormalizer')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Continue;
          end;
        end;

        if FPool.FUseDivDeduplicator
        then begin
          if not TryProc(@FDivDeduplicator.Process, LDocuments[i],
            'DivDeduplicator')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterDivDeduplicator);
            Continue;
          end;
        end;

        if FPool.FUseGeolocator
        then begin
          if not TryProc(@FGeolocator.Process, LDocuments[i],
            'Geolocator')
          then Continue;
          if (not LDocuments[i].Valid)
          then begin
            FreeAndNil(LDocuments[i]);
            Inc(FPool.FInvalidAfterGeolocator);
            Continue;
          end;
        end;

        // Collect statistics if doc is valid and all.
        with FPool
        do begin
          Inc(FAllUsableDocuments);
          Inc(FAllBadness, Round(LDocuments[i].Badness));
          if LDocuments[i].Badness > FHighestBadness
          then FHighestBadness := LDocuments[i].Badness;
          if LDocuments[i].Badness < FLowestBadness
          then FLowestBadness := LDocuments[i].Badness;
          Inc(FAllTokenCount, LDocuments[i].TypeTokenData.TokenCount);
          if LDocuments[i].TypeTokenData.TokenCount > FHighestTokenCount
          then FHighestTokenCount :=
            LDocuments[i].TypeTokenData.TokenCount;
          if LDocuments[i].TypeTokenData.TokenCount < FLowestTokenCount
          then FLowestTokenCount :=
            LDocuments[i].TypeTokenData.TokenCount;
        end;

      end;

      // Extract these after all processors have done their work or hosts WITH
      // www will become urlblank.
      LMetaExtract := TrExtractHost(LDocuments[i].Url);
      LDocuments[i].AddMeta('host', LMetaExtract);
      LMetaExtract := TrExtractTld(LMetaExtract);
      LDocuments[i].AddMeta('tld', LMetaExtract);
    end;

    // Try to get rid of the current documents.
    // If the queue is gone, we just quit.
    l := 0;
    while (l < FPool.FPushLimit)
    and   Assigned(FToQueue)
    do begin
      if FToQueue.PushDocuments(LDocuments, Length(LDocuments))
      then Break;
      Sleep(FPool.FPushSleep);
      Inc(l);
    end;

  end;

  // Check if we own documents which must be freed.
  for i := 0 to High(LDocuments)
  do FreeAndNil(LDocuments[i]);
end;


{ *** TTrWorkerPool *** }


constructor TTrWorkerPool.Create(const AFromQueue : TTrDocumentQueue;
  const AToQueue : TTrDocumentQueue; AIni : TIniFile);
var
  i : Integer;
begin
  if (not Assigned(AFromQueue))
  then raise ETrWorker.Create('Input queue is nil.');
  if (not Assigned(AToQueue))
  then raise ETrWorker.Create('Output queue is nil.');
  if (not Assigned(AIni))
  then raise ETrWorker.Create('INI is nil.');

  FIni := AIni;
  FFromQueue := AFromQueue;
  FToQueue   := AToQueue;

  // This should absolutely pass all Exceptions up (ultimately to main thread).
  // We do not want to run if there are errors in streamed properties.
  TrReadProps(self, FIni);

  FInvalidAfterStripper := 0;
  FInvalidAfterDuplicateDetector := 0;
  FInvalidAfterCharsetConverter := 0;
  FInvalidAfterSecondPass := 0;
  FInvalidAfterUtf8Validator := 0;
  FInvalidAfterSimpleDocumentFilter := 0;
  FInvalidAfterDeboilerplater := 0;
  FInvalidAfterTokenizer := 0;
  FInvalidAfterTextAssessment := 0;
  FInvalidAfterShingler := 0;
  FInvalidAfterNormalizer := 0;

  FAllBadness := 0;
  FAllUsableDocuments := 1;
  FLowestBadness := 1000000;
  FHighestBadness := 0;
  FAllTokenCount := 0;
  FLowestTokenCount := High(Integer);
  FHighestTokenCount := 0;

  // This must be finished before the threads start trying to use the
  // database. It creates a common resource to lookup geo information.
  if FUseGeolocator
  then TrInitGeodata(FGeoBlocksFile, FGeoLocationsFile);

  if FUseDuplicateDetector
  then TrInitDuplicateDetector(FBloomErrorRate);

  if FUseDivDeduplicator
  then TrInitDivDeduplicator;

  // Start threads.
  SetLength(FWorkers, FWorkerNumber);
  for i := 0 to High(FWorkers)
  do FWorkers[i] := TTrWorker.Create(self, FFromQueue, FToQueue, FIni);
end;


destructor TTrWorkerPool.Destroy;
begin
  TerminateAll;
  inherited Destroy;
end;


procedure TTrWorkerPool.TerminateAll;
var
  i : Integer;
begin
  for i := 0 to High(FWorkers)
  do begin
    if  Assigned(FWorkers[i])
    then begin
      FWorkers[i].Terminate;
      FWorkers[i].WaitFor;
      FreeAndNil(FWorkers[i]);
    end;
  end;
end;


procedure TTrWorkerPool.AddThread;
begin

  // We respect the min/max numbers.
  if ActiveThreads >= FMaxWorkerNumber
  then Exit;

  // If we add one, the list will always get longer; never reuse
  // thread indexes.
  SetLength(FWorkers, Length(FWorkers)+1);
  FWorkers[High(FWorkers)] :=
    TTrWorker.Create(self, FFromQueue, FToQueue, FIni);

  // Check for exceptions that occurred in thread creation.
  if Assigned(FWorkers[High(FWorkers)].FatalException)
  then raise FWorkers[High(FWorkers)].FatalException;
end;


procedure TTrWorkerPool.RemoveThread;
var
  i : Integer;
begin

  // We respect the min/max numbers.
  if ActiveThreads <= FMinWorkerNumber
  then Exit;

  // We go through the list and find the first to retire.
  for i := High(FWorkers) downto 0
  do begin
    if  Assigned(FWorkers[i])
    then begin
      FWorkers[i].Terminate;
      FWorkers[i].WaitFor;
      FreeAndNil(FWorkers[i]);
      SetLength(FWorkers, i);

      // Once we have removed one, just exit.
      Exit;
    end;
  end;
end;


function TTrWorkerPool.GetActiveThreads : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FWorkers)
  do if (Assigned(FWorkers[i]))
    and (not FWorkers[i].Terminated)
    then Inc(Result);
end;


end.
