

constructor TTrFileOut.Create(const APrefix: String;
  const ASuffix : String; AAutoSplitSize : Integer = 0;
  AGzip : Boolean = true);
begin
  FStream := nil;
  FBufferPosition := 0;
  FBytes := 0;
  FFileName := '';
  FPrefix := APrefix;
  FSuffix := ASuffix;
  FCounter := 0;
  FAutoSplitSize := AAutoSplitSize;
  FGzip := AGzip;

  // Create the first file.
  CreateNextFile;
end;


constructor TTrFileOut.Create(const ASingleFileName: String;
  AGzip : Boolean = true); overload;
begin
  FStream := nil;
  FBufferPosition := 0;
  FBytes := 0;
  FFileName := '';
  FPrefix := '';
  FSuffix := '';
  FSingleFilename := ASingleFileName;
  FCounter := 0;
  FAutoSplitSize := 0;
  FGzip := AGzip;
  CreateNextFile;
end;


destructor TTrFileOut.Destroy;
begin
  Flush;
  FreeAndNil(FStream);
  inherited;
end;


procedure TTrFileOut.WriteChar(const AChar : Char); inline;
begin
  if FBufferPosition >= GBufferSize - 1
  then Flush;
  FBuffer[FBufferPosition] := AChar;
  Inc(FBufferPosition);
  Inc(FBytes);

  // Check if we need to create a new file.
  if ( FAutoSplitSize > 0 )
  and ( Position > FAutoSplitSize )
  then CreateNextFile;
end;


procedure TTrFileOut.WriteString(const AString : String);
begin

  // For WriteString, the buffer is not used. So, flush first.
  Flush;

  // Write the string.
  FStream.WriteBuffer(AString[1], Length(AString));

  // Increment byte counter.
  Inc(FBytes, Length(AString));

  // This automatically checks whether a new file split is in order.
  WriteChar(#10);
end;


procedure TTrFileOut.CreateNextFile;
var
  LCounterString : String = '';
  LTime : String = '';
begin

  // Flush and close old file stream.
  Flush;
  FreeAndNil(FStream);

  if FSingleFilename = ''
  then begin
    // Increase the file name counter.
    Inc(FCounter);
    LCounterString := Format('%10.10d', [FCounter]);

    // Format a time string (=> virtually never duplicate file names).
    LTime := FormatDateTime('YYYY-MM-DD_hh-nn-z', Now);

    // Put together new file name.
    FFileName := FPrefix + '_' + LCounterString + '_' + LTime + FSuffix;
  end
  else FFileName := FSingleFilename;

  // Try to open new file as either normal or Gzip file stream.
  if not FileExists(FFileName)
  then begin
    if FGzip
    then FStream := TGZFileStream.Create(FFileName, gzOpenWrite)
    else FStream := TFileStream.Create(FFileName, fmCreate);
  end else raise ETrFile.Create('Output file already exists.' +
    #10#13 + FFileName);
end;


procedure TTrFileOut.Flush;
begin

  // Simply write the out buffer as far as it has been filled.
  if FBufferPosition > 0
  then FStream.WriteBuffer(FBuffer, FBufferPosition);
  FBufferPosition := 0;
end;


function TTrFileOut.GetPosition : Integer;
begin
  Result := (-1);   // Undetermined.

  // Stream position plus unwritten buffer.
  if Assigned(FStream)
  then Result := FStream.Position + FBufferPosition;
end;
