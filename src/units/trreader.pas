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


unit TrReader;

{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  SysUtils,
  SyncObjs,
  Classes,
  StrUtils,
  IniFiles,
  IcuWrappers,
  TrUtilities,
  TrData,
  TrFile,
  TrQueues;

type
  ETrReader = class(Exception);


  // These modes are used in TTrArcReader.ScanNextDocument to keep track
  // which state it is in.
  TTrDocumentReadMode = (
    tdrmSearching,
    tdrmReading,
    tdrmDone
  );

  // Forward declaration because the Reader needs to be aware of this type.
  TTrReaderPool = class;

  // This uses a file reader to scan the stream for documents.
  // It replaces some of the core functionality of the old TTrParser.
  // The idea is to have one scanner which feeds a queue or an ouput
  // module. The scanner does not do any cleaning per se.
  TTrReader = class(TThread)
  public
    constructor Create(const APool : TTrReaderPool); virtual; overload;
    destructor Destroy; override;
  protected
    FPool : TTrReaderPool;
    FReader : TTrFileIn;              // The reader object to read from.

    // To minimize communication with the queues, this buffers documents
    // when done.
    FDocumentBuffer : TTrDocumentArray;
    FDocumentBufferIndex : Integer;

    // If a document starts illegally, this backs up the first line.
    FPutBack : String;

    procedure ScanNextDocument;
    procedure Execute; override;

    // These have to be implemented by descendants to do the actual document
    // detection and meta extraction from headers.
    function IsBegin(const ALine : String) : Boolean; virtual; abstract;
    function IsHeaderEnd(const ALine : String) : Boolean; virtual; abstract;
    procedure HeaderExtract(const ALine : String; const ADocument : TTrDocument;
      const IsFirst : Boolean = false);
      virtual; abstract;
  end;
  TTrReaderClass = class of TTrReader;
  TTrReaderArray = array of TTrReader;



  TTrArcReader = class(TTrReader)
  public
    constructor Create(const APool : TTrReaderPool); override;
    destructor Destroy; override;
  protected
    FDocumentStartIcu : TIcuRegex;
    FHeaderStopIcu : TIcuRegex;
    FHeaderEncodingIcu : TIcuRegex;  // To get all info from first ARC line.
    FMetaMatcher : TTrMetaMatcher;   // Whether a line matches the header meta.

    function IsBegin(const ALine : String) : Boolean; override;
    function IsHeaderEnd(const ALine : String) : Boolean; override;
    procedure HeaderExtract(const ALine : String; const ADocument : TTrDocument;
      const IsFirst : Boolean = false); override;
  end;


  TTrWarcReader = class(TTrReader)
  public
    constructor Create(const APool : TTrReaderPool); override;
    destructor Destroy; override;
  protected
    FHeaderStopIcu : TIcuRegex;
    FHeaderEncodingIcu : TIcuRegex;  // To get all info from first ARC line.
    FMetaMatcher : TTrMetaMatcher;   // Whether a line matches the header meta.

    FHeaderIpIcu : TIcuRegex;
    FHeaderUrlIcu : TIcuRegex;

    function IsBegin(const ALine : String) : Boolean; override;
    function IsHeaderEnd(const ALine : String) : Boolean; override;
    procedure HeaderExtract(const ALine : String; const ADocument : TTrDocument;
      const IsFirst : Boolean = false); override;
  end;



  // The pool also keeps the list of input files, from which reader
  // threads pull their consecutive file names.
  TTrReaderPool = class(TPersistent)
  public
    constructor Create(const AQueue : TTrDocumentQueue;
      const AIni : TIniFile);
    destructor Destroy; override;
    procedure TerminateAll;
    procedure AddThread;
    procedure RemoveThread;
  protected

    // Low-level structure and desired/corrected number of threads.
    FReaders : TTrReaderArray;

    FIni : TIniFile;
    FQueue : TTrDocumentQueue;

    FFileList : TStringList;
    FFilesTotal : QWord;

    // Statistics.
    FDocumentsRead : QWord;
    FBytesRead : QWord;

    // This protects reads (= pops) from the FFileList.
    FLock : TCriticalSection;

    // Whether we should give up on all documents
    // (intended to keep threads from trying to push documents after
    // shutdown).
    FGiveUp : Boolean;

    // Streamables.
    FMaxDocSize : Integer;         // How large can a single doc be?
    FMinDocSize : Integer;         // How large must a doc be for passing on?
    FRetryWait : Integer;          // How many ms between push retries?
    FDocumentBufferSize : Integer;
    FFileName : String;
    FReaderNumber : Integer;
    FCrawlHeaderExtract : String;
    FExternalGzipPath : String;

    // Which kind of reader do we use. This is a class reference.
    FReaderClass : TTrReaderClass;

    function GetActiveThreads : Integer;
    function GetFilesProcessed : QWord;

    // Internally, bits are used, but setting/getting is in KB.
    procedure SetMinDocSize(const ADocSize : Integer);
    procedure SetMaxDocSize(const ADocSize : Integer);
    function GetMinDocSize : Integer;
    function GetMaxDocSize : Integer;

    // Only threads defined here do this. Returns false if list empty.
    function GetNextFileName(var AFileName : String): Boolean;
    procedure ReturnFileName(const AFileName : String);

    function GetReaderClass : String;
    procedure SetReaderClass(const AReaderClass : String);

  public
    property ActiveThreads : Integer read GetActiveThreads;
    property DocumentsRead : QWord read FDocumentsRead;
    property BytesRead : QWord read FBytesRead;
    property FilesProcessed : QWord read GetFilesProcessed;
    property FilesTotal : QWord read FFilesTotal;
  published
    property ExternalGzipPath : String read FExternalGzipPath
      write FExternalGzipPath;
    property MinDocSize : Integer read GetMinDocSize
      write SetMinDocSize default 2;
    property MaxDocSize : Integer read GetMaxDocSize
      write SetMaxDocSize default 256;
    property RetryWait : Integer read FRetryWait write FRetryWait
      default 5;
    property DocumentBufferSize : Integer read FDocumentBufferSize
      write FDocumentBufferSize default 10;
    property FileName : String read FFileName write FFileName;
    property ReaderNumber : Integer read FReaderNumber
      write FReaderNumber default 1;
    property CrawlHeaderExtract : String read FCrawlHeaderExtract
      write FCrawlHeaderExtract;
    property ReaderClass : String read GetReaderClass write SetReaderClass;
  end;


implementation




{ *** TTrWarcReader *** }


constructor TTrWarcReader.Create(const APool : TTrReaderPool);
const
  HeaderStop : Utf8String = '^ *<';
  HeaderEnc  : Utf8String = '^Content-type: .*charset=([-0-9A-Za-z]+)(?:$|,|;| )';
  HeaderIp   : Utf8String = '^WARC-IP-Address: (.+)$';
  HeaderUrl  : Utf8String = '^WARC-Target-URI: (.+)$';
begin
  inherited Create(APool);

  FHeaderStopIcu := TIcuRegex.Create(HeaderStop, UREGEX_CASE_INSENSITIVE);
  FHeaderEncodingIcu := TIcuRegex.Create(HeaderEnc, UREGEX_CASE_INSENSITIVE);
  FHeaderIpIcu := TIcuRegex.Create(HeaderIp, UREGEX_CASE_INSENSITIVE);
  FHeaderUrlIcu := TIcuRegex.Create(HeaderUrl, UREGEX_CASE_INSENSITIVE);
  FMetaMatcher := TTrMetaMatcher.Create(FPool.CrawlHeaderExtract,
      '^', ' *: *(.+) *$');
end;


destructor TTrWarcReader.Destroy;
begin
  FreeAndNil(FHeaderIpIcu);
  FreeAndNil(FHeaderUrlIcu);
  FreeAndNil(FHeaderStopIcu);
  FreeAndNil(FHeaderEncodingIcu);
  FreeAndNil(FMetaMatcher);
  inherited Destroy;
end;


function TTrWarcReader.IsBegin(const ALine : String) : Boolean; inline;
const
  LStarter : String = 'WARC/1.0';
begin
  Result := ALine = LStarter;
end;


function TTrWarcReader.IsHeaderEnd(const ALine : String) : Boolean; inline;
begin
  Result := FHeaderStopIcu.Match(ALine, false, true);
end;


procedure TTrWarcReader.HeaderExtract(const ALine : String; const ADocument :
  TTrDocument; const IsFirst : Boolean = false); inline;
var
  LMatchPack : TTrMatchPack;
  LMetaExtract : String = '';
begin
  if FHeaderIpIcu.Match(ALine, true, true)
  then begin
    LMetaExtract := FHeaderIpIcu.Replace(ALine, '$1', true, true);
    ADocument.Ip := LMetaExtract;
  end

  else if FHeaderUrlIcu.Match(ALine, true, true)
  then begin
    LMetaExtract := FHeaderUrlIcu.Replace(ALine, '$1', true, true);
    ADocument.Url := LMetaExtract;
  end

  else if FHeaderEncodingIcu.Match(ALine, true, true)
  then begin
    LMetaExtract := FHeaderEncodingIcu.Replace(ALine, '$1', true, true);
    ADocument.SourceCharset := LMetaExtract;
  end

  else if FMetaMatcher.Match(ALine, LMatchPack)
  then ADocument.AddMeta(LMatchPack.Id, LMatchPack.Content);
end;





{ *** TTrArcReader *** }


constructor TTrArcReader.Create(const APool : TTrReaderPool);
const
  DocumentStart   : Utf8String = '^(http://[^ ]+) (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) ([0-9]+) (.+) ([0-9]+)$';
  HeaderStop      : Utf8String = '^ *<';
  HeaderEncoding  : Utf8String = '^Content-type: .*charset=([-0-9A-Za-z]+)(?:$|,|;| )';
begin
  inherited Create(APool);

  // Compile the regex for document starts.
  FDocumentStartIcu := TIcuRegex.Create(DocumentStart,
    UREGEX_CASE_INSENSITIVE);
  FHeaderStopIcu := TIcuRegex.Create(HeaderStop,
    UREGEX_CASE_INSENSITIVE);
  FHeaderEncodingIcu := TIcuRegex.Create(HeaderEncoding,
    UREGEX_CASE_INSENSITIVE);
  FMetaMatcher := TTrMetaMatcher.Create(FPool.CrawlHeaderExtract,
      '^', ' *: *(.+) *$');
end;


destructor TTrArcReader.Destroy;
begin
  FreeAndNil(FHeaderStopIcu);
  FreeAndNil(FHeaderEncodingIcu);
  FreeAndNil(FMetaMatcher);
  FreeAndNil(FDocumentStartIcu);
  inherited Destroy;
end;


function TTrArcReader.IsBegin(const ALine : String) : Boolean; inline;
begin
  Result := (Length(ALine) > 0) and (ALine[1] = 'h')
  and FDocumentStartIcu.Match(ALine, false, true);
end;


function TTrArcReader.IsHeaderEnd(const ALine : String) : Boolean; inline;
begin
  Result := FHeaderStopIcu.Match(ALine, false, true);
end;


procedure TTrArcReader.HeaderExtract(const ALine : String; const ADocument :
  TTrDocument; const IsFirst : Boolean = false); inline;
var
  LMatchPack : TTrMatchPack;
  LMetaExtract : String = '';
const
  LDocReplace  : Utf8String = '$1';
  LIpReplace   : Utf8String = '$2';
  LDateReplace : Utf8String = '$3';
  LMimeReplace : Utf8String = '$4';
  LSizeReplace : Utf8String = '$5';
begin

  // In ARC, the first line contains a lot of relevant information. Otherwise,
  // the encoding is essential (not stored as generic meta), the rest is normal
  // meta. Hence, three cases.
  if IsFirst
  then begin
    LMetaExtract := FDocumentStartIcu.Replace(ALine, LDocReplace, false, true);
    ADocument.Url := LMetaExtract;
    LMetaExtract := FDocumentStartIcu.Replace(ALine, LIpReplace, false, true);
    ADocument.Ip := LMetaExtract;
    LMetaExtract := FDocumentStartIcu.Replace(ALine, LDateReplace, false, true);
    ADocument.AddMeta('date', LMetaExtract);
    LMetaExtract := FDocumentStartIcu.Replace(ALine, LMimeReplace, false, true);
    ADocument.AddMeta('mime', LMetaExtract);
    LMetaExtract := FDocumentStartIcu.Replace(ALine, LSizeReplace, false, true);
    ADocument.AddMeta('size', LMetaExtract);
  end else if FHeaderEncodingIcu.Match(ALine, true, true)
  then begin
    LMetaExtract := FHeaderEncodingIcu.Replace(ALine, '$1', true, true);
    ADocument.SourceCharset := LMetaExtract;
  end else if FMetaMatcher.Match(ALine, LMatchPack)
  then ADocument.AddMeta(LMatchPack.Id, LMatchPack.Content);
end;



{ *** TTrReader *** }


constructor TTrReader.Create(const APool : TTrReaderPool);
begin
  inherited Create(false);

  // The reader will be created and re-filled in Execute. Nil for
  // safety.
  FReader := nil;
  FPool := APool;

  // Empty means that there was no first line encountered.
  FPutBack := '';

  SetLength(FDocumentBuffer, FPool.FDocumentBufferSize);
  FDocumentBufferIndex := 0;
  Priority := tpHigher;
end;


destructor TTrReader.Destroy;
begin
  FreeAndNil(FReader);
  inherited Destroy;
end;


procedure TTrReader.ScanNextDocument;
var
  LLine : String;
  LDocument : TTrDocument = nil;
  LMode : TTrDocumentReadMode = tdrmSearching;
  LHeaderStop : Boolean = false;
  LReaderBytes : QWord;
begin

  // To get the bytes delta later, save stream postion.
  LReaderBytes := FReader.Bytes;
  LDocument := TTrDocument.Create;

  while (LMode = tdrmSearching)
  or (LMode = tdrmReading)
  do begin

    // There might be a line we had to put back, which must be reused.
    // In that case, use the backup as LLine and null the backup.
    if FPutBack <> ''
    then begin
      LLine := FPutBack;
      FPutBack := '';
    end else FReader.ReadLine(LLine);

    // If we're not yet saving, we must check whether this is a start.
    if (LMode = tdrmSearching)
    and IsBegin(LLine)
    then begin
      LMode := tdrmReading;
      LDocument.AddMeta('arcfile', FReader.CurrentFileName);
      LDocument.AddMeta('arcoffset', IntToStr(FReader.Position-Length(LLine)-1));
      HeaderExtract(LLine, LDocument, true);
    end

    // ... or we might be at the end, in case we are reading.
    else if (LMode = tdrmReading)
    and IsBegin(LLine)
    then begin
      LMode := tdrmDone;
      FPutBack := LLine;
    end;

    // If normal read or this is the last line, then write line.
    // But if we had to put it back, we must not write it, because
    // it will be written in next pass into next document.
    if ((LMode = tdrmReading)
      or (LMode = tdrmDone))
    and (FPutBack = '')
    then begin

      // While we are reading headers, check for extraction.
      // And possibly set LHeaderStop.
      if not LHeaderStop
      then begin
        HeaderExtract(LLine, LDocument);
        LHeaderStop := IsHeaderEnd(LLine);
      end;

      // Actual line write or break if document too large now.
      if (LDocument.RawSize+Length(LLine)+1) < FPool.FMaxDocSize

      then LDocument.AddRaw(LLine + ' ')
      else begin
        LMode := tdrmDone;
        LDocument.CleanRaw;
      end;
    end;

    // If stream is exhausted, also quit.
    if FReader.Eos
    then LMode := tdrmDone;
  end;

  if (LDocument.RawSize > 0)
  then Inc(FPool.FDocumentsRead);

  // Add document to the internal buffer.
  if (LDocument.RawSize > FPool.FMinDocSize)
  then begin

    // Write final meta information.
    LDocument.AddMeta('arclength',
      IntToStr(FReader.Position - StrToQword(LDocument.GetMetaByKey('arcoffset'))
      - Length(LLine) - 1));
    FDocumentBuffer[FDocumentBufferIndex] := LDocument;
    Inc(FDocumentBufferIndex);
  end
  else FreeAndNil(LDocument);

  // Finally, write the consumed bytes.
  LReaderBytes := FReader.Bytes-LReaderBytes;
  if LReaderBytes > 0
  then Inc(FPool.FBytesRead, LReaderBytes)
end;


procedure TTrReader.Execute;

  procedure BufferWrite; inline;
  begin

    // We now try to push any non-empty document to the receiver.
    if (FDocumentBufferIndex >= High(FDocumentBuffer))
    then begin

      // The queue might be in a threaded environment and reject the
      // document. We retry according to policy. If the queue is gone
      // we quit for good.
      while Assigned(FPool.FQueue)
      and (not FPool.FGiveUp)
      and (not FPool.FQueue.PushDocuments(FDocumentBuffer,
        FDocumentBufferIndex+1))
      do Sleep(FPool.FRetryWait);

      // Start writing the buffer again.
      FDocumentBufferIndex := 0;
    end;
  end;

var
  LNextFileName : String;
begin

  // This thread will terminate automatically if FReader is exhausted.
  while (not Terminated)
  and   (not FPool.FGiveUp)
  do begin
    try

      // Try to reload if no reader is active.
      // If files are exhausted, just self-terminate.
      if not Assigned(FReader)
      or FReader.Eos
      then begin

        // If there are no more file names, just quit.
        if not FPool.GetNextFileName(LNextFileName)
        then Break

        // If there was a file name, try creating a reader for it.
        else begin

          // Create new reader.
          FreeAndNil(FReader);
          FReader := TTrFileIn.Create(LNextFileName, true,
            FPool.FExternalGzipPath);

          // Try again if nothing could be done.
          if not Assigned(FReader)
          then Continue;
        end;
      end;
    except
      TrDebug(ClassName, Exception(ExceptObject));
    end;

    // This encapsulates all the actual processing.
    try
      ScanNextDocument;
      BufferWrite;
    except
      TrDebug(ClassName, Exception(ExceptObject));
    end;

  end;

  // Try giving back the file if we aren't done yet.
  if Assigned(FReader)
  and not FReader.Eos
  then FPool.ReturnFileName(LNextFileName);

  try
    BufferWrite;
  except
      TrDebug(ClassName, Exception(ExceptObject));
  end;

  // When we are done, just terminate.
  Terminate;
end;



{ *** TTrReaderPool *** }


constructor TTrReaderPool.Create(const AQueue : TTrDocumentQueue;
  const AIni : TIniFile);
var
  Info : TSearchRec;
  i : Integer;
begin
  if not Assigned(AIni)
  then raise ETrReader.Create('Ini not assigned.');
  if not Assigned(AQueue)
  then raise ETrReader.Create('Queue not assigned.');

  FLock := TCriticalSection.Create;
  FGiveUp := false;
  FIni := AIni;
  FQueue := AQueue;
  FDocumentsRead := 0;
  FBytesRead := 0;
  FExternalGzipPath := '';

  // Call the helper which loads this object's properties with the
  // values from INI.
  TrReadProps(self, FIni);

  FFileList := TStringList.Create;

  // Create threads and assign them their file lists.
  if DirectoryExists(FFileName)
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
    if FileExists(FFileName)
    then FFileList.Add(FFileName);
  end;

  FFilesTotal := FFileList.Count;

  if FFileList.Count < 1
  then raise ETrReader.Create('No file found to process.');

  // Make sure FileList is sorted.
  FFileList.Sort;

  // Create readers.
  if FFileList.Count <= FReaderNumber
  then FReaderNumber := FFileList.Count;
  SetLength(FReaders, FReaderNumber);
  for i := 0 to FReaderNumber-1
  do FReaders[i] := FReaderClass.Create(self);
end;


destructor TTrReaderPool.Destroy;
begin
  TerminateAll;
  FreeAndNil(FLock);
  FreeAndNil(FFileList);
  inherited Destroy;
end;


procedure TTrReaderPool.TerminateAll;
var
  i : Integer;
begin
  FGiveUp := true;

  for i := 0 to High(FReaders)
  do begin
    if  Assigned(FReaders[i])
    then begin
      FReaders[i].Terminate;
      FReaders[i].WaitFor;
      FreeAndNil(FReaders[i]);
    end;
  end;
end;


procedure TTrReaderPool.AddThread;
begin

  // If we add one, the list will always get longer; never reuse
  // thread indexes.
  SetLength(FReaders, Length(FReaders)+1);
  FReaders[High(FReaders)] := FReaderClass.Create(self);
end;


procedure TTrReaderPool.RemoveThread;
var
  i : Integer;
begin

  // We go through the list and find the first to retire.
  for i := High(FReaders) downto 0
  do begin
    if  Assigned(FReaders[i])
    then begin
      FReaders[i].Terminate;
      FReaders[i].WaitFor;
      FreeAndNil(FReaders[i]);
      SetLength(FReaders, i);

      // Once we have removed one, just exit.
      Exit;
    end;
  end;
end;


function TTrReaderPool.GetActiveThreads : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FReaders)
  do if (Assigned(FReaders[i]))
    and (not FReaders[i].Terminated)
    then Inc(Result);
end;


function TTrReaderPool.GetFilesProcessed : QWord;
begin
  if Assigned(FFileList)
  then Result := FFilesTotal-FFileList.Count
  else Result := 0;
end;


procedure TTrReaderPool.SetMinDocSize(const ADocSize : Integer);
begin
  FMinDocSize := ADocSize * 1024;
end;


procedure TTrReaderPool.SetMaxDocSize(const ADocSize : Integer);
begin
  FMaxDocSize := ADocSize * 1024;
end;


function TTrReaderPool.GetMinDocSize : Integer;
begin
  Result := FMinDocSize div 1024;
end;


function TTrReaderPool.GetMaxDocSize : Integer;
begin
  Result := FMaxDocSize div 1024;
end;


function TTrReaderPool.GetNextFileName(var AFileName : String) :
  Boolean;
begin
  FLock.Enter;
  AFileName := '';
  try
    Result := true;
    if FFileList.Count > 0
    then begin
      while (AFileName = '')
      and (FFileList.Count > 0)
      do begin

        // "Pop" the top item from the list.
        AFileName := FFileList[FFileList.Count-1];
        FFileList.Delete(FFileList.Count-1);
      end;
    end else begin
      Result := false;
    end;
  finally
    FLock.Leave;
  end;
end;


procedure TTrReaderPool.ReturnFileName(const AFileName : String);
begin
  FLock.Enter;
  try
    FFileList.Add(AFileName);
  finally
    FLock.Leave;
  end;
end;


function TTrReaderPool.GetReaderClass : String;
begin
  if Assigned(FReaderClass)
  then Result := FReaderClass.ClassName
  else Result := '';
end;


procedure TTrReaderPool.SetReaderClass(const AReaderClass : String);
begin
  case AReaderClass of
    'TTrArcReader'  : FReaderClass := TTrArcReader;
    'TTrWarcReader' : FReaderClass := TTrWarcReader;
  else
    raise ETrReader.Create('Invalid reader class specified.');
  end;
end;

end.
