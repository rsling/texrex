
constructor TTrStatsWatcher.Create(const AApplication :
  TTrApplication);
begin
  if AApplication = nil
  then raise ETrTexrex.Create('Cannot create a stats watcher ' +
    'thread with nil application.');

  inherited Create(false);

  FApplication := AApplication;
  FLastCheckTime := 0;

  FStatsWriter := TTrFileOut.Create(FApplication.FJobname, '.log', 0,
    false);
end;


destructor TTrStatsWatcher.Destroy;
begin
  FreeAndNil(FStatsWriter);
  inherited Destroy;
end;


procedure TTrStatsWatcher.Execute;
var
  LNow : TDateTime;

  procedure WriteCurrent;
  var
    LArray : String;
  begin
    LArray := DateTimeToStr(FTime) + #9
      + IntToStr(FSecsUpNow) + #9
      + IntToStr(FReaders) + #9
      + IntToStr(FWorkers) + #9
      + IntToStr(FWriters) + #9
      + IntToStr(FDocsRead) + #9
      + IntToStr(FDocsRPerSec) + #9
      + IntToStr(FBRead) + #9
      + IntToStr(FBRPerSec) + #9
      + IntToStr(FDocsWritten) + #9
      + IntToStr(FDocsWPerSec) + #9
      + FloatToStrF(FDocRatio, ffGeneral, 6, 4) + #9
      + IntToStr(FBWritten) + #9
      + IntToStr(FBWPerSec) + #9
      + FloatToStrF(FBRatio, ffGeneral, 6, 4) + #9
      + IntToStr(FLinks) + #9
      + FloatToStrF(FAvgLinksPDoc, ffGeneral, 6, 4) + #9
      + IntToStr(FFilesTotal) + #9
      + IntToStr(FFilesDone) + #9
      + FloatToStrF(FAvgDocBad, ffGeneral, 6, 4) + #9
      + FloatToStrF(FLowestBad, ffGeneral, 6, 4) + #9
      + FloatToStrF(FHighestBad, ffGeneral, 6, 4) + #9
      + FloatToStrF(FAvgTokC, ffGeneral, 6, 4) + #9
      + IntToStr(FLowestTokC) + #9
      + IntToStr(FHighestTokC) + #9

      + IntToStr(FInvStripper) + ','
      + IntToStr(FInvDupDet) + ','
      + IntToStr(FInvCharConv) + ','
      + IntToStr(FInv2Pass) + ','
      + IntToStr(FInvUtf8Val) + ','
      + IntToStr(FInvDocFilt) + ','
      + IntToStr(FInvDeboiler) + ','
      + IntToStr(FInvTokenizer) + ','
      + IntToStr(FInvTAss) + ','
      + IntToStr(FInvShingler) + ','
      + IntToStr(FInvNorm) + ','
      + IntToStr(FInvGeoloc)
      ;
    FStatsWriter.WriteString(LArray);
  end;

begin
  FStatsWriter.WriteString(
    'DateTime'#9'UpTimeSec'#9'ReadersNo'#9'WorkersNo'#9'WritersNo'#9+
    'DocsReadNo'#9'DocsReadPerS'#9'BytesRead'#9'BytesReadPerSec'#9+
    'DocsWrittenNo'#9'DocsWrittenPerSec'#9+
    'DocsReadWriteRatio'#9'BytesWritten'#9'BytesWrittenPerSec'#9+
    'BytesReadWriteRatio'#9'LinksNo'#9'AvgLinksPerDoc'#9+
    'InputFilesTotal'#9'InputFilesDone'#9'AvgBadness'#9+
    'LowestDocBad'#9'HighestDocBad'#9'AvgTokenCount'#9+
    'LowestTokenCount'#9'HighestTokenCount'#9'InvalidAfter'
  );

  while not Terminated
  do begin
    LNow := Now;

    if FApplication.FForceStats
    or (SecondsBetween(LNow, FLastCheckTime) >
      FApplication.FStatsInterval)
    or (FLastCheckTime = 0)
    then begin
      try
        FTime         := LNow;
        FSecsUpNow    := SecondsBetween(LNow, FApplication.FStarted);
        if FSecsUpNow < 1
        then FSecsUpNow := 1;

        FReaders      := FApplication.FReaderPool.ActiveThreads;
        FWorkers      := FApplication.FWorkerPool.ActiveThreads;
        FWriters      := FApplication.FWriterPool.ActiveThreads;

        FDocsRead     := FApplication.FReaderPool.DocumentsRead;
        if FDocsRead < 1
        then FDocsRead := 1;
        FDocsRPerSec  := Round(FDocsRead / FSecsUpNow);

        FDocsWritten  := FApplication.FWriterPool.DocumentsWritten;
        if FDocsWritten < 1
        then FDocsWritten := 1;
        FDocsWPerSec  := Round(FDocsWritten / FSecsUpNow);

        FDocRatio     := FDocsRead / FDocsWritten;

        FBRead        := FApplication.FReaderPool.BytesRead;
        FBRPerSec     := Round(FBRead / FSecsUpNow);

        FBWritten     := FApplication.FWriterPool.BytesWritten;
        if FBWritten < 1
        then FBWritten := 1;
        FBWPerSec     := Round(FBWritten / FSecsUpNow);

        FBRatio       := FBRead / FBWritten;

        FLinks        := FApplication.FWriterPool.LinksWritten;

        FAvgLinksPDoc := FLinks / FDocsWritten;

        FFilesTotal   := FApplication.FReaderPool.FilesTotal;
        FFilesDone    := FApplication.FReaderPool.FilesProcessed;

        if FApplication.FWorkerPool.AllUsableDocuments > 0
        then FAvgDocBad := (FApplication.FWorkerPool.AllBadness /
          FApplication.FWorkerPool.AllUsableDocuments)
        else FAvgDocBad := -1;

        FLowestBad    := FApplication.FWorkerPool.LowestBadness;
        FHighestBad   := FApplication.FWorkerPool.HighestBadness;
        if FApplication.FWorkerPool.AllUsableDocuments > 0
        then FAvgTokC := FApplication.FWorkerPool.AllTokenCount /
          FApplication.FWorkerPool.AllUsableDocuments
        else FAvgTokC := -1;
        FLowestTokC   := FApplication.FWorkerPool.LowestTokenCount;
        FHighestTokC  := FApplication.FWorkerPool.HighestTokenCount;

        FInvStripper := FApplication.FWorkerPool.InvalidAfterStripper;
        FInvDupDet :=
          FApplication.FWorkerPool.InvalidAfterDuplicateDetector;
        FInvCharConv :=
          FApplication.FWorkerPool.InvalidAfterCharsetConverter;
        FInv2Pass := FApplication.FWorkerPool.InvalidAfterSecondPass;
        FInvUtf8Val :=
          FApplication.FWorkerPool.InvalidAfterUtf8Validator;
        FInvDocFilt :=
          FApplication.FWorkerPool.InvalidAfterSimpleDocumentFilter;
        FInvDeboiler :=
          FApplication.FWorkerPool.InvalidAfterDeboilerplater;
        FInvTokenizer := FApplication.FWorkerPool.InvalidAfterTokenizer;
        FInvShingler := FApplication.FWorkerPool.InvalidAfterShingler;
        FInvTAss := FApplication.FWorkerPool.InvalidAfterTextAssessment;
        FInvNorm := FApplication.FWorkerPool.InvalidAfterNormalizer;
        FInvGeoloc := FApplication.FWorkerPool.InvalidAfterGeolocator;

        // Reset statistics enforcer.
        FApplication.FForceStats := false;

        // Set interval checker.
        FLastCheckTime := LNow;

        // Write results to log.
        WriteCurrent;
      except
        FApplication.FForceStats := false;
        TrDebug(ClassName, Exception(ExceptObject));
      end;

    end;
    Sleep(5);
  end;
end;
