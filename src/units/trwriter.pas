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


unit TrWriter;


{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  SysUtils,
  StrUtils,
  SyncObjs,
  Classes,
  IniFiles,
  IcuWrappers,
  TrVersionInfo,
  TrFile,
  TrData,
  TrUtilities,
  TrQueues,
  TrWriteTools;


type
  ETrXmlWriter = class(Exception);

  TTrWriterPool = class;

  TTrWriter = class(TThread)
  public
    constructor Create(const APool : TTrWriterPool;
      const AThreadIdx : Integer); overload;
    destructor Destroy; override;

  protected

    // Mother pool holding all relevant variables for processing.
    FPool : TTrWriterPool;

    FThreadIdx : String;

    // The lower-level file writer.
    FFileOut : TTrFileOut;

    // The shingle, etc. file writers.
    FShingleWriter : TTrFileOut;
    FLinkWriter : TTrFileOut;
    FTokenWriter : TTrFileOut;
    FTarcWriter : TTrFileOut;

    procedure Execute; override;
  end;


  TTrWriterArray = array of TTrWriter;


  TTrWriterPool = class(TPersistent)
  public
    constructor Create(const AQueue : TTrDocumentQueue;
      const AIni : TIniFile);
    destructor Destroy; override;
    procedure TerminateAll;
    function GetActiveThreads : Integer;
    procedure RemoveThread;
    procedure AddThread;

  protected
    FIni : TIniFile;

    // Low-level structure holding the threads.
    FWriters : TTrWriterArray;
    FQueue : TTrDocumentQueue;

    FWriterNumber : Integer;
    FPopSleep : Integer;
    FBufferSize : Integer;
    FPrefix : String;
    FWriteDocContainer : TStringArray;
    FWriteDocMeta : TStringArray;
    FWriteDivMeta : TStringArray;
    FWriteDocAttr : TStringArray;
    FWriteDivAttr : TStringArray;
    FWriteText : Boolean;
    FWriteDups : Boolean;
    FDupBlank : String;
    FWriteDivMetrics : Boolean;
    FWriteShingles : Boolean;
    FWriteLinks : Boolean;
    FWriteTokens : Boolean;
    FWriteMaxTokens : Integer;
    FWriteTarc : Boolean;

    FSplitSizeXml : Integer; // INI has MB, this is converted to B already.
    FSplitSizeShingles : Integer;
    FSplitSizeLinks : Integer;
    FSplitSizeTokens : Integer;
    FSplitSizeTarc : Integer;

    FGzipXml : Boolean;
    FGzipShingles : Boolean;
    FGzipLinks : Boolean;
    FGzipTokens : Boolean;
    FGzipTarc : Boolean;

    FXmlSuffix : String;
    FShingleSuffix : String;
    FLinkSuffix : String;
    FTokenSuffix : String;
    FTarcSuffix : String;

    FDocumentsWritten : QWord;
    FLinksWritten : QWord;
    FBytesWritten : QWord;

    procedure SetWriterNumber(const ANumber : Integer);

    function GetDocContainer : String;
    procedure SetDocContainer(const AContainers : String);
    function GetDocMeta : String;
    procedure SetDocMeta(const AMeta : String);
    function GetDivMeta : String;
    procedure SetDivMeta(const AMeta : String);
    function GetDocAttr : String;
    procedure SetDocAttr(const AAttr : String);
    function GetDivAttr : String;
    procedure SetDivAttr(const AAttr : String);

    procedure SetSplitSizeXml(const ASize : Integer);
    function GetSplitSizeXml : Integer;
    procedure SetSplitSizeShingles(const ASize : Integer);
    function GetSplitSizeShingles : Integer;
    procedure SetSplitSizeLinks(const ASize : Integer);
    function GetSplitSizeLinks : Integer;
    procedure SetSplitSizeTokens(const ASize : Integer);
    function GetSplitSizeTokens : Integer;
    procedure SetSplitSizeTarc(const ASize : Integer);
    function GetSplitSizeTarc : Integer;

    procedure SetGzipXml(const AValue : Boolean);
    procedure SetGzipShingles(const AValue : Boolean);
    procedure SetGzipLinks(const AValue : Boolean);
    procedure SetGzipTokens(const AValue : Boolean);
    procedure SetGzipTarc(const AValue : Boolean);

  public
    property ActiveThreads : Integer read GetActiveThreads;
    property DocumentsWritten : QWord read FDocumentsWritten;
    property LinksWritten : QWord read FLinksWritten;
    property BytesWritten : QWord read FBytesWritten;

  published
    property WriterNumber : Integer read FWriterNumber
      write SetWriterNumber default 1;
    property PopSleep : Integer read FPopSleep write FPopSleep
      default 5;
    property BufferSize : Integer read FBufferSize write FBufferSize
      default 10;
    property Prefix : String read FPrefix write FPrefix;
    property WriteDocContainer : String read GetDocContainer
      write SetDocContainer;
    property WriteDocMeta : String read GetDocMeta write SetDocMeta;
    property WriteDivMeta : String read GetDivMeta write SetDivMeta;
    property WriteDocAttr : String read GetDocAttr write SetDocAttr;
    property WriteDivAttr : String read GetDivAttr write SetDivAttr;
    property WriteText : Boolean read FWriteText write FWriteText
      default true;

    property WriteDups : Boolean read FWriteDups write FWriteDups
      default true;
    property DupBlank : String read FDupBlank write FDupBlank;
    property WriteDivMetrics : Boolean read FWriteDivMetrics
      write FWriteDivMetrics default true;

    property WriteShingles : Boolean read FWriteShingles
      write FWriteShingles default true;
    property WriteLinks : Boolean read FWriteLinks write FWriteLinks
      default true;
    property WriteTokens : Boolean read FWriteTokens
      write FWriteTokens default false;
    property WriteTarc : Boolean read FWriteTarc
      write FWriteTarc default false;

    property WriteMaxTokens : Integer read FWriteMaxTokens
      write FWriteMaxTokens default 100;

    property SplitSizeXml : Integer read GetSplitSizeXml
      write SetSplitSizeXml default 1024;
    property SplitSizeShingles : Integer read GetSplitSizeShingles
      write SetSplitSizeShingles default 1024;
    property SplitSizeLinks : Integer read GetSplitSizeLinks
      write SetSplitSizeLinks default 1024;
    property SplitSizeTokens : Integer read GetSplitSizeTokens
      write SetSplitSizeTokens default 1024;
    property SplitSizeTarc : Integer read GetSplitSizeTarc
      write SetSplitSizeTarc default 1024;

    property GzipXml : Boolean read FGzipXml write SetGzipXml
      default false;
    property GzipShingles : Boolean read FGzipShingles
      write SetGzipShingles default true;
    property GzipLinks : Boolean read FGzipLinks write SetGzipLinks
      default true;
    property GzipTokens : Boolean read FGzipTokens write SetGzipTokens
      default true;
    property GzipTarc : Boolean read FGzipTarc write SetGzipTarc
      default true;
  end;



implementation



constructor TTrWriter.Create(const APool : TTrWriterPool;
  const AThreadIdx : Integer);
begin
  if not Assigned(APool)
  then Exit;

  FPool := APool;
  FThreadIdx := TrPad(2, IntToStr(AThreadIdx));

  // Start in resumed state.
  inherited Create(false);

  with FPool
  do begin
    FFileOut := TTrFileOut.Create(FPrefix + '_' + FThreadIdx,
      FXmlSuffix, 0, FGzipXml);

    if FWriteShingles
    then FShingleWriter := TTrFileOut.Create(FPrefix + '_' +
      FThreadIdx, FShingleSuffix, 0, FGzipShingles);

    if FWriteLinks
    then FLinkWriter := TTrFileOut.Create(FPrefix + '_' +
      FThreadIdx, FLinkSuffix, 0, FGzipLinks);

    if FWriteTokens
    then FTokenWriter := TTrFileOut.Create(FPrefix + '_' +
      FThreadIdx, FTokenSuffix, 0, FGzipTokens);

    if FWriteTarc
    then begin
      FTarcWriter := TTrFileOut.Create(FPrefix + '_' +
        FThreadIdx, FTarcSuffix, 0, FGzipTarc);
    end;

  end;
end;


destructor TTrWriter.Destroy;
begin
  FreeAndNil(FFileOut);
  FreeAndNil(FShingleWriter);
  FreeAndNil(FLinkWriter);
  FreeAndNil(FTokenWriter);
  FreeAndNil(FTarcWriter);
  inherited Destroy;
end;



procedure TTrWriter.Execute;
var
  LDocuments : TTrDocumentArray;
  i : Integer;

  procedure FreeDocs;
  var
    l : Integer;
  begin
    for l := 0 to High(LDocuments)
    do FreeAndNil(LDocuments[l]);
  end;

begin

  SetLength(LDocuments, FPool.FBufferSize);

  while (not Terminated)
  do begin

    // If the queue is gone, exit for good.
    if Assigned(FPool.FQueue)
    then LDocuments := FPool.FQueue.PopDocuments(FPool.FBufferSize)
    else Break;

    // Retry for as long as instructed to get a document.
    if (Length(LDocuments) < 1)
    then begin
      Sleep(FPool.FPopSleep);
      Continue;
    end;

    // Process the docs.
    for i := 0 to High(LDocuments)
    do begin
      try

        // This sets meta to be written in WriteDocumentFormatted, so
        // it must be first.
        if FPool.FWriteTarc
        then TrWriteTarc(LDocuments[i], FTarcWriter, FPool.FSplitSizeTarc);

        //WriteDocumentFormatted(LDocuments[i]);
        with FPool
        do Inc(FBytesWritten, TrWriteXmlDoc(LDocuments[i], FWriteDocAttr,
          FWriteDocMeta, FWriteDocContainer, FWriteDivAttr, FWriteDivMeta,
          FWriteDups, FDupBlank, FWriteDivMetrics, FWriteText, FFileOut,
          FSplitSizeXml));
        Inc(FPool.FDocumentsWritten);

        if FPool.FWriteLinks
        then Inc(FPool.FLinksWritten,
          TrWriteLinks(LDocuments[i], FLinkWriter, FPool.FSplitSizeLinks));

        if FPool.FWriteShingles
        then TrWriteShingles(LDocuments[i], FShingleWriter,
          FPool.FSplitSizeShingles);

        if FPool.FWriteTokens
        then TrWriteTokens(LDocuments[i], FPool.WriteMaxTokens, FTokenWriter,
          FPool.FSplitSizeTokens);

      except
        TrDebug(ClassName, Exception(ExceptObject));
      end;
    end;

    // Finally, free the documents.
    FreeDocs;
  end;

end;



{ *** TTrWriterPool *** }


constructor TTrWriterPool.Create(const AQueue : TTrDocumentQueue;
  const AIni : TIniFile);
var
  i : Integer;
begin
  if not Assigned(AIni)
  then raise ETrXmlWriter.Create('Ini not assigned.');
  if not Assigned(AQueue)
  then raise ETrXmlWriter.Create('Queue not assigned.');

  FIni := AIni;
  FQueue := AQueue;
  FDocumentsWritten := 0;
  FLinksWritten := 0;
  FDupBlank := 'dupblank';

  TrReadProps(self, FIni);

  // Create the threads.
  SetLength(FWriters, FWriterNumber);
  for i := 0 to High(FWriters)
  do FWriters[i] := TTrWriter.Create(self, i);
end;


destructor TTrWriterPool.Destroy;
begin
  TerminateAll;

  // These are NOT owned:
  FIni := nil;
  FQueue := nil;
  inherited Destroy;
end;


procedure TTrWriterPool.TerminateAll;
var
  i : Integer;
begin
  for i := 0 to High(FWriters)
  do begin
    if  Assigned(FWriters[i])
    then begin
      FWriters[i].Terminate;
      FWriters[i].WaitFor;
      FreeAndNil(FWriters[i]);
    end;
  end;
end;


function TTrWriterPool.GetActiveThreads : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FWriters)
  do if (Assigned(FWriters[i]))
    and (not FWriters[i].Terminated)
    then Inc(Result);
end;


procedure TTrWriterPool.AddThread;
begin

  // If we add one, the list will always get longer; never reuse
  // thread indexes.
  SetLength(FWriters, Length(FWriters)+1);
  FWriters[High(FWriters)] := TTrWriter.Create(self, High(FWriters));
end;


procedure TTrWriterPool.RemoveThread;
var
  i : Integer;
begin

  // We go through the list and find the first to retire.
  for i := High(FWriters) downto 0
  do begin
    if  Assigned(FWriters[i])
    then begin
      FWriters[i].Terminate;
      FWriters[i].WaitFor;
      FreeAndNil(FWriters[i]);
      SetLength(FWriters, i);

      // Once we have removed one, just exit.
      Exit;
    end;
  end;
end;


procedure TTrWriterPool.SetWriterNumber(const ANumber : Integer);
begin
  if ANumber > 100
  then raise ETrXmlWriter.Create('Maximum is 100 writer threads.');

  FWriterNumber := ANumber;
end;


function TTrWriterPool.GetDocMeta : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDocMeta)
  do Result += FWriteDocMeta[i];
end;


procedure TTrWriterPool.SetDocMeta(const AMeta : String);
begin
  FWriteDocMeta := TrExplode(AMeta, ['|']);
end;


function TTrWriterPool.GetDocContainer : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDocContainer)
  do Result += FWriteDocContainer[i];
end;


procedure TTrWriterPool.SetDocContainer(const AContainers : String);
begin
  FWriteDocContainer := TrExplode(AContainers, ['|']);
end;


function TTrWriterPool.GetDivMeta : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDivMeta)
  do Result += FWriteDivMeta[i];
end;


procedure TTrWriterPool.SetDivMeta(const AMeta : String);
begin
  FWriteDivMeta := TrExplode(AMeta, ['|']);
end;


function TTrWriterPool.GetDocAttr : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDocAttr)
  do Result += FWriteDocAttr[i];
end;


procedure TTrWriterPool.SetDocAttr(const AAttr : String);
begin
  FWriteDocAttr := TrExplode(AAttr, ['|']);
end;


function TTrWriterPool.GetDivAttr : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDivAttr)
  do Result += FWriteDivAttr[i];
end;


procedure TTrWriterPool.SetDivAttr(const AAttr : String);
begin
  FWriteDivAttr := TrExplode(AAttr, ['|']);
end;


procedure TTrWriterPool.SetGzipXml(const AValue : Boolean);
begin
  FGzipXml := AValue;
  if FGzipXml
  then FXmlSuffix := '.xml.gz'
  else FXmlSuffix := '.xml';
end;


procedure TTrWriterPool.SetGzipShingles(const AValue : Boolean);
begin
  FGzipShingles := AValue;
  if FGzipShingles
  then FShingleSuffix := '.shingles.gz'
  else FShingleSuffix := '.shingles';
end;


procedure TTrWriterPool.SetGzipLinks(const AValue : Boolean);
begin
  FGzipLinks := AValue;
  if FGzipLinks
  then FLinkSuffix := '.links.gz'
  else FLinkSuffix := '.links';
end;


procedure TTrWriterPool.SetGzipTokens(const AValue : Boolean);
begin
  FGzipTokens := AValue;
  if FGzipTokens
  then FTokenSuffix := '.tokens.csv.gz'
  else FTokenSuffix := '.tokens.csv';
end;


procedure TTrWriterPool.SetGzipTarc(const AValue : Boolean);
begin
  FGzipTarc := AValue;
  if FGzipTarc
  then FTarcSuffix := '.tarc.gz'
  else FTarcSuffix := '.tarc';
end;


procedure TTrWriterPool.SetSplitSizeXml(const ASize : Integer);
begin
  FSplitSizeXml := ASize * 8388608;
end;


function TTrWriterPool.GetSplitSizeXml : Integer;
begin
  Result := FSplitSizeXml div 8388608;
end;


procedure TTrWriterPool.SetSplitSizeShingles(const ASize : Integer);
begin
  FSplitSizeShingles := ASize * 8388608;
end;


function TTrWriterPool.GetSplitSizeShingles : Integer;
begin
  Result := FSplitSizeShingles div 8388608;
end;


procedure TTrWriterPool.SetSplitSizeLinks(const ASize : Integer);
begin
  FSplitSizeLinks := ASize * 8388608;
end;


function TTrWriterPool.GetSplitSizeLinks : Integer;
begin
  Result := FSplitSizeLinks div 8388608;
end;


procedure TTrWriterPool.SetSplitSizeTokens(const ASize : Integer);
begin
  FSplitSizeTokens := ASize * 8388608;
end;


function TTrWriterPool.GetSplitSizeTokens : Integer;
begin
  Result := FSplitSizeTokens div 8388608;
end;


procedure TTrWriterPool.SetSplitSizeTarc(const ASize : Integer);
begin
  FSplitSizeTarc := ASize * 8388608;
end;


function TTrWriterPool.GetSplitSizeTarc : Integer;
begin
  Result := FSplitSizeTarc div 8388608;
end;


end.
