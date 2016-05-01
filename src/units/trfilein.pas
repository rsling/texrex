
constructor TTrFileIn.Create(const AFileName: String;
  AAutoAdvanceFile : Boolean = true;
  const AExternalGzip : String = '');
var
  Info : TSearchRec;
begin

  // Careful: Some redundant code in the two constructors!

  FExternalGzip := AExternalGzip;

  FStream := nil;
  FBufferPosition := 0;
  FBufferLimit := 0;
  FBytes := 0;

  // EOS needs to be false initially because we havent loaded anything.
  // This changed with the introduction of possible manual file advance.
  FEos := true;
  FPosition := 0;

  FFileName := AFileName;
  FAutoAdvanceFile := AAutoAdvanceFile;
  FCurrentFile := (-1);

  FFileList := TStringList.Create;

  // We check whether the input file was specified as a directory.
  if DirectoryExists(FFileName)
  then FDirectoryMode := true
  else FDirectoryMode := false;

  if DirectoryMode
  then begin

    // In directory mode, we must build a full file list.
    {$IFDEF WINDOWS}
      if RightStr(FFileName, 1) <> '\'
      then FFileName += '\';
    {$ELSE}
      if RightStr(FFileName, 1) <> '/'
      then FFileName += '/';
    {$ENDIF}

    if (FindFirst(FFileName + '*', LongInt(0), Info) = 0)
    then begin
      FFileList.Add(FFileName + Info.Name);
      while FindNext(Info) = 0
      do FFileList.Add(FFileName + Info.Name);
    end;

    FindClose(Info);
  end else begin

    // Non-directory mode = only 1 file.
    if FileExists(FFileName)
    then FFileList.Add(FFileName);
  end;

  if FFileList.Count < 1
  then raise ETrFile.Create('No file found to process.');

  // Make sure FileList is sorted.
  FFileList.Sort;

  if FAutoAdvanceFile
  then Fill;
end;


constructor TTrFileIn.Create(const AFileList: TStringList;
  AAutoAdvanceFile : Boolean = true;
  const AExternalGzip : String = '');
begin

  // Careful: Some redundant code in the two constructors!

  FExternalGzip := AExternalGzip;

  FStream := nil;
  FBufferPosition := 0;
  FBufferLimit := 0;
  FBytes := 0;

  // EOS needs to be false initially because we havent loaded anything.
  // This changed with the introduction of possible manual file advance.
  FEos := true;
  FPosition := 0;

  FFileName := '__LIST__';
  FAutoAdvanceFile := AAutoAdvanceFile;
  FCurrentFile := (-1);

  FFileList := AFileList;

  // DirectoryMode is an outdated word. Should be MultifileMode.
  FDirectoryMode := true;

  if FFileList.Count < 1
  then raise ETrFile.Create('No file found to process.');

  // Make sure FileList is sorted.
  FFileList.Sort;

  if FAutoAdvanceFile
  then Fill;

  FLinePeeked := false;
end;


destructor TTrFileIn.Destroy;
begin

  // In case we use TProcess, the stream will be freed by that.
  if not (FStream is TInputPipeStream)
  then FreeAndNil(FStream);

  FreeAndNil(FProcess);
  FreeAndNil(FFileList);
  inherited Destroy;
end;


function TTrFileIn.ReadChar(out AChar : Char) : Boolean;
begin
  if FBufferPosition < FBufferLimit
  then begin
    AChar := FBuffer[FBufferPosition];
    Inc(FBufferPosition);
    Result := true;
  end else begin
    Fill;
    if FBufferLimit > 0
    then begin
      AChar := FBuffer[FBufferPosition];
      Inc(FBufferPosition);
      Result := true;
    end else Result := false;
  end;

  if Result
  then Inc(FPosition);

end;


function TTrFileIn.PeekChar(out AChar : Char) : Boolean;
begin
  if FBufferPosition < FBufferLimit
  then begin
    AChar := FBuffer[FBufferPosition];
    Result := true;
  end else begin
    Fill;
    if FBufferLimit > 0
    then begin
      AChar := FBuffer[FBufferPosition];
      Result := true;
    end else Result := false;
  end;
end;


function TTrFileIn.ReadLine(out ALine : String) : Boolean;
var
  Success : Boolean = false;
  LChar : Char;
  LPeekChar : Char;
  Eol : Boolean = false;
  LIndex : Integer = 1;
begin

  // If a line was peeked, all we need to do is return it.
  if FLinePeeked
  then begin
    ALine := FPeekedLine;
    Result := true;
    FLinePeeked := false;
    Exit;
  end;

  // We allocate the line in chunks of 512 and fill it char-wise.
  SetLength(ALine, 512);

  repeat
    Success := ReadChar(LChar);
    if Success
    and (LChar <> #0)              //  Just do not do anything with #0.
    then begin

      // Line end.
      if (LChar = #10)
      or (LChar = #13)
      then Eol := true;

      // Consume dangling #13 ends when #10 was already found.
      if Eol
      then begin
        if  PeekChar(LPeekChar)
        and (LPeekChar = #13)
        then ReadChar(LPeekChar);
      end

      // If NOT line end, add current buffer to output.
      else begin
        if LIndex >= Length(ALine) - 1
        then SetLength(ALine, Length(ALine) + 512); // Extend line buffer if necessary.
          ALine[LIndex] := LChar;                   // Add the char to line.
        Inc(LIndex);                                // Advance line buffer limit.
      end;

    end;
  until (not Success)  // File is at end, implicit line ending;
  or Eol;               // Normal line ending found.

  // This truncates the buffered line to its actually filled length.
  SetLength(ALine, LIndex - 1);

  if not Success
  then Result := false
  else Result := true;
end;


function TTrFileIn.PeekLine(out ALine : String) : Boolean;
begin

  // If there was already a peeked line, just return it.
  if FLinePeeked
  then begin
    ALine := FPeekedLine;
    Result := true;
    Exit;
  end;

  // Try to peek a new line.
  Result := ReadLine(FPeekedLine);
  if Result
  then ALine := FPeekedLine;
  FLinePeeked := Result;
end;


function TTrFileIn.AdvanceFile : Boolean;
begin

  // Add current bytes total bytes and reset position tracker.
  Inc(FBytes, FPosition);
  FPosition := 0;

  // Make sure old stream is freed. However, if we use the stream
  // from a TProcess, we must not free it.
  if not (FStream is TInputPipeStream)
  then FreeAndNil(FStream);

  // If we use external gunzip, we need to free TProcess.
  FreeAndNil(FProcess);

  // GZIP magic number check and appropriate stream create
  // until some file was loaded or file list is exhausted.
  while (not Assigned(FStream))
  and (FCurrentFile <= FFileList.Count - 2)
  do begin

    // Move to next file. Note that after Create FCurrentFile=(-1).
    Inc(FCurrentFile);

    try
      if TrFileIsGzip(FFileList[FCurrentFile])
      then begin

        // This cannot cope with multi-record Gzip files.
        if (FExternalGzip = '')
//        or (not FileExists(FExternalGzip))
        then FStream :=
          TGZFileStream.Create(FFileList[FCurrentFile], gzOpenRead)

        // This can cope with multi-record Gzip files. Might be slower,
        // and it requires external gunzip. We fill the buffer directly
        // from the pipe connected to the process.
        else begin
          FProcess := TProcess.Create(nil);
          FProcess.Executable := FExternalGzip;
          FProcess.Parameters.Add('-c');
          FProcess.Parameters.Add('-d');
          FProcess.Parameters.Add(FFileList[FCurrentFile]);
          FProcess.Options := [poUsePipes];
          FProcess.Execute;

          // We only do Read operations. So we just pass the the
          // output stream from the TProcess as our stream.
          FStream := FProcess.Output;
        end;

      // Simple text file reading. Nothing to do but create file stream.
      end else
        FStream := TFileStream.Create(FFileList[FCurrentFile],
          fmOpenRead);
    except
      TrDebug('File ' + FFileList[FCurrentFile] +
        ' could not be opened. Moving on.');
    end;

  end;

  // We return a value when a file was loaded.
  Result := Assigned(FStream);
end;


procedure TTrFileIn.Fill;

  procedure FillFromStream;
  begin

    // Try reloading something from stream.
    // The try is to catch exceptions
    // occuring with faulty GZ files (and maybe others).
    if Assigned(FStream)
    then begin

      // Read bytes.
      try
        FBufferLimit := FStream.Read(FBuffer, GBufferSize);
      except
        FBufferLimit := 0;
        Exit;
      end;
      FBufferPosition := 0;
    end else FBufferLimit := 0;
  end;

begin

  // If this is sucessful, the next loop will be skipped completely.
  FillFromStream;

  // Now, if we don't have anything or stream wasn't even assigned,
  // then we must try to load a new stream as long as there
  // is still no data in buffer or there are no more files left.
  while FAutoAdvanceFile
  and   (FBufferLimit = 0)
  and   (FCurrentFile <= FFileList.Count - 2)
  do begin
    if AdvanceFile
    then FillFromStream;
  end;

  // If after fill attempt loop the buffer is empty, we are done.
  // Since GZFileStreams do not allow to get size property, we cannot
  // determine EOS dynamically.
  if FBufferLimit <= 0
  then FEos := true
  else FEos := false;
end;


function TTrFileIn.GetBytes : QWord;
begin
  Result := FBytes + FPosition;
end;


function TTrFileIn.GetFileCount : Integer;
begin
  Result := FFileList.Count;
end;

function TTrFileIn.GetCurrentFileName : String;
begin
  Result := FFileList[FCurrentFile];
end;


function TTrFileIn.GetLastFile : Boolean;
begin
  Result := FileCount <= CurrentFile+1;
end;


function TTrFileIn.GetPeekedLine : String;
begin
  if FLinePeeked
  then Result := FPeekedLine
  else if not PeekLine(Result)
  then Result := #0;
end;
