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


unit TrShingleHelpers;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  Classes,
  Contnrs,
  SysUtils,
  StrUtils,
  SyncObjs,
  TrFile,
  TrUtilities;


const
  ShingleLineLength = 68;
  ShingleOffset = 1;
  ShingleLength = 20;
  DocIdOffset = 22;
  DocIdLength = 36;
  DocLengthOffset = 59;
  DocLengthLength = 10;
  DocDocLineLength  = 65;


type

  ETrShingleHelpers = class(Exception);


  TTrSorterPack = class(Tobject)
  public
    constructor Create(const AOutFile : String); virtual;
    destructor Destroy; override;
  protected
    FOutFile : String;
    FStrings : TStringList;
  public
    property OutFile : String read FOutFile write FOutFile;
    property Strings : TStringList read FStrings write FStrings;
  end;


  TTrSorterPackQueue = class(TObjectQueue)
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function PushTS(const ASorterPack : TTrSorterPack) : Boolean;
    function PopTS : TTrSorterPack;
  protected
    FLock : TCriticalSection;
  end;


  // Sort a TStrinList and writes the result to a possibly gzipped file.
  TTrSorter = class(TThread)
  public
    constructor Create(const AQueue : TTrSorterPackQueue;
      AGzip : Boolean = true); overload;
    destructor Destroy; override;
  protected
    FQueue : TTrSorterPackQueue;
    FGZip : Boolean;
    procedure Execute; override;
  end;
  TTrSorters = array of TTrSorter;


  TTrShinglePack = packed record
    Shingle    : String[ShingleLength];
    DocumentId : String[DocIdLength];
    Size       : Integer;
  end;
  TTrShinglePacks = array of TTrShinglePack;

  TTrShingleLine = String[ShingleLineLength];

  // Creates doc-doc pairs from sorted shingle lists and then does the
  // same as TTrSorter.
  TTrDocDocCreator = class(TThread)
  public
    constructor Create(const AQueue : TTrSorterPackQueue;
      const AMaximalRedundancy : Integer = 200;
      AGzip : Boolean = true); overload;
    destructor Destroy; override;
  protected
    FQueue : TTrSorterPackQueue;
    FGZip : Boolean;

    // If a shingle occurs more thean FMaximalRedundancy times, then
    // it will be discarded.
    FMaximalRedundancy : Integer;

    procedure Execute; override;
    procedure PermuteWrite(var AShinglePacks : TTrShinglePacks;
      const ADocDocList : TStringList); inline;
  end;
  TTrDocDocCreators = array of TTrDocDocCreator;


  TTrReaderArray = array of TTrFileIn;

  TTrMerger = class(TObject)
  public

    // TODO RS Compare start and compare length are not yet implemented.
    constructor Create(const AInFiles : TStringList;
      const ACompareStart : Integer = -1;
      const ACompareLength : Integer = 0); virtual;
    destructor Destroy; override;
    function NextLine(out ALine : String) : Integer;
  protected
    FReaders : TTrReaderArray;
    FCompareStart : Integer;       // Yet unused.
    FCompareLength : Integer;      // Yet unused.
    function GetEos : Boolean;
  public
    property Eos : Boolean read GetEos;
  end;


procedure TrLoadHashListFromFiles(const AFiles : TStringList;
  out AHashList : TFPHashList);


procedure TrExplodeShingle(const AShingleLine : TTrShingleLine;
  out AShinglePack : TTrShinglePack); inline;


procedure TrCopyShinglePack(const AInPack : TTrShinglePack;
  out AOutPack : TTrShinglePack); inline;



implementation



var
  Dummy : Integer = 0;


procedure TrLoadHashListFromFiles(const AFiles : TStringList;
  out AHashList : TFPHashList);
var
  LFileIn : TTrFileIn = nil;
  LLine : String;
begin
  if (AFiles.Count < 1)
  then raise ETrShingleHelpers.Create('No blacklist files found.');

  AHashList := TFPHashList.Create;
  LFileIn := TTrFileIn.Create(AFiles, true);

  try
    while LFileIn.ReadLine(LLine)
    do

      // Only add new string. This does not work with AND in the WHILE
      // construct. Hmmm, why?
      if not Assigned(AHashList.Find(LLine))
      then AHashList.Add(LLine, @Dummy);
  finally
    FreeAndNil(LFileIn);
  end;
end;


procedure TrExplodeShingle(const AShingleLine : TTrShingleLine;
  out AShinglePack : TTrShinglePack); inline;
begin
  with AShinglePack
  do begin
    Shingle := AnsiLeftStr(AShingleLine, ShingleLength);
    DocumentId := AnsiMidStr(AShingleLine, DocIdOffset, DocIdLength);
    Size := StrToIntDef(AnsiRightStr(AShingleLine, DocLengthLength), 0);
  end;
end;


procedure TrCopyShinglePack(const AInPack : TTrShinglePack;
  out AOutPack : TTrShinglePack); inline;
begin
  with AOutPack
  do begin
    Shingle    := AInPack.Shingle;
    DocumentId := AInPack.DocumentId;
    Size       := AInPack.Size;
  end;
end;



{ *** TTrSorterPack *** }


constructor TTrSorterPack.Create(const AOutFile : String);
begin
  FOutFile := AOutFile;
  FStrings := TStringList.Create;
end;


destructor TTrSorterPack.Destroy;
begin
  FreeAndNil(FStrings);
  inherited Destroy;
end;



{ *** TSorterPackQueue *** }


constructor TTrSorterPackQueue.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
end;


destructor TTrSorterPackQueue.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;


function TTrSorterPackQueue.PushTS(const ASorterPack : TTrSorterPack) :
  Boolean;
begin
  Result := false;
  FLock.Enter;
  try
    if Push(ASorterPack as TObject) = ASorterPack as TObject
    then Result := true;
  finally
    FLock.Leave;
  end;
end;


function TTrSorterPackQueue.PopTS : TTrSorterPack;
begin
  Result := nil;
  FLock.Enter;
  try
    Result := Pop as TTrSorterPack;
  finally
    FLock.Leave;
  end;
end;


{ *** TTrSorter *** }



constructor TTrSorter.Create(const AQueue : TTrSorterPackQueue;
  AGzip : Boolean = true); overload;
begin
  FQueue := AQueue;
  FGzip := AGzip;
  inherited Create(false);
end;


destructor TTrSorter.Destroy;
begin
  inherited Destroy;
end;


procedure TTrSorter.Execute;
var
  LSorterPack : TTrSorterPack = nil;
  LWriter : TTrFileOut = nil;
  i : Integer;
begin

  while not Terminated
  do begin

    // Try to pop one.
    LSorterPack := FQueue.PopTS;

    // If queue is empty, nil is popped.
    if Assigned(LSorterPack)
    then begin

      // This is what takes time.
      LSorterPack.Strings.Sort;

      LWriter := TTrFileOut.Create(LSorterPack.OutFile, FGzip);
      for i := 0 to LSorterPack.Strings.Count-1
      do  LWriter.WriteString(LSorterPack.Strings[i]);
      FreeAndNil(LWriter);
      FreeAndNil(LSorterPack);
    end
    else Sleep(100);
  end;
end;


{ *** TTrMerger *** }


constructor TTrMerger.Create(const AInFiles : TStringList;
  const ACompareStart : Integer = -1;
  const ACompareLength : Integer = 0);
var
  i : Integer;
begin
  if AInFiles.Count < 1
  then raise ETrShingleHelpers.Create('Refusing to merge 0 files.');

  SetLength(FReaders, AInFiles.Count);

  // Create a reader object for each input file.
  for i := 0 to AInFiles.Count-1
  do FReaders[i] := TTrFileIn.Create(AInFiles[i], true);

  FCompareStart := ACompareStart;
  FCompareLength := ACompareLength;
end;


destructor TTrMerger.Destroy;
var
  i : Integer;
begin
  for i := 0 to High(FReaders)
  do FreeAndNil(FReaders[i]);
  SetLength(FReaders, 0);
  inherited Destroy;
end;


function TTrMerger.NextLine(out ALine : String) : Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to High(FReaders)
  do begin
    if (FReaders[i].PeekedLine <> #0)
    then begin
      if (Result < 0)
      or (FReaders[i].PeekedLine < FReaders[Result].PeekedLine)
      then Result := i;
    end;
  end;

  // This fetches the actual minimal line from its reader.
  if (Result >= 0)
  then FReaders[Result].ReadLine(ALine);
end;


function TTrMerger.GetEos : Boolean;
var
  i : Integer;
begin
  Result := true;
  for i := 0 to High(FReaders)
  do Result := Result and FReaders[i].Eos;
end;




{ *** TTrDocDocCreator *** }


constructor TTrDocDocCreator.Create(
  const AQueue : TTrSorterPackQueue;
  const AMaximalRedundancy : Integer = 200;
  AGzip : Boolean = true); overload;
begin
  FMaximalRedundancy := AMaximalRedundancy;
  FQueue := AQueue;
  FGzip := AGzip;
  inherited Create(false);
end;


destructor TTrDocDocCreator.Destroy;
begin
  inherited Destroy;
end;


procedure TTrDocDocCreator.PermuteWrite(
  var AShinglePacks : TTrShinglePacks;
  const ADocDocList : TStringList); inline;
var
  i, j : Integer;
begin
  if  (Length(AShinglePacks) > 1)
  and (Length(AShinglePacks) < FMaximalRedundancy)
  then begin

    // Two loops, cartesian product the brute-force way.
    for i := 0 to High(AShinglePacks)
    do begin
      for j := i+1 to High(AShinglePacks)
      do begin

        // The smaller document always comes first in the pairs.
        if (AShinglePacks[i].Size < AShinglePacks[j].Size)
        then ADocDocList.Add(AShinglePacks[i].DocumentId + ' ' +
          AShinglePacks[j].DocumentId)
        else ADocDocList.Add(AShinglePacks[j].DocumentId + ' ' +
          AShinglePacks[i].DocumentId);
      end;
    end;
  end;
end;


procedure TTrDocDocCreator.Execute;
var
  LSorterPack : TTrSorterPack = nil;
  LWriter : TTrFileOut = nil;
  LCurrentShinglePacks : TTrShinglePacks;
  LNextShinglePack : TTrShinglePack;
  LDocDocList : TStringList;
  i : Integer;
begin

  while not Terminated
  do begin

    // Try to pop one.
    LSorterPack := FQueue.PopTS;

    // If queue is empty, nil is popped.
    if Assigned(LSorterPack)
    then
      try
        LDocDocList := TStringList.Create;

        // Go through all shingle strings passed to this thread.
        SetLength(LCurrentShinglePacks, 0);
        for i := 0 to LSorterPack.Strings.Count-1
        do begin

          // Create and read the next shingle pack from input.
          TrExplodeShingle(LSorterPack.Strings[i], LNextShinglePack);

          // Decide what to do.
          if  (Length(LCurrentShinglePacks) > 0)
          then begin

            // The list already contains something. See whether we start
            // a new shingle.
            if LCurrentShinglePacks[High(LCurrentShinglePacks)].Shingle
              = LNextShinglePack.Shingle
            then begin
              SetLength(LCurrentShinglePacks,
                Length(LCurrentShinglePacks)+1);

              // Make deep-copy of shingle pack.
              TrCopyShinglePack(LNextShinglePack,
                LCurrentShinglePacks[High(LCurrentShinglePacks)]);
            end

            // New shingle. Pass old list to permuter, then reset and
            // add the first line with the new shingle.
            else begin
              PermuteWrite(LCurrentShinglePacks, LDocDocList);
              SetLength(LCurrentShinglePacks, 1);
              TrCopyShinglePack(LNextShinglePack,
                LCurrentShinglePacks[0]);
            end;

          end

          // Length=0, so just create a new list and pass current pack.
          else begin
            SetLength(LCurrentShinglePacks, 1);
            TrCopyShinglePack(LNextShinglePack,
              LCurrentShinglePacks[0]);
          end;

        end; // rof

        // Process the last list and cut list to 0.
        PermuteWrite(LCurrentShinglePacks, LDocDocList);
        SetLength(LCurrentShinglePacks, 0);

        // We are done. Now sort the list of doc-doc pairs.
        LDocDocList.Sort;

        // Write everything.
        LWriter := TTrFileOut.Create(LSorterPack.OutFile, FGzip);
        for i := 0 to LDocDocList.Count-1
        do  LWriter.WriteString(LDocDocList[i]);

      finally
        // Free resources.
        FreeAndNil(LWriter);
        FreeANdNil(LDocDocList);
        FreeAndNil(LSorterPack);
      end

    // Wait awhile if nothing was popped.
    else Sleep(100);

  end; // elihw
end;


end.
