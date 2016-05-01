{
    This file is part of the Free Component Library (FCL)
    Copyright (c) 2002 by Florian Klaempfl

    See the file COPYING.modifiedLGPL.txt, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$ifdef fpc}
{$mode objfpc}
{$endif}
{$H+}
{$ifdef CLASSESINLINE}{$inline on}{$endif}

unit TrHashList;


interface


uses
  SysUtils,Classes;


type
  THashItem=record
    HashValue : LongWord;
    StrIndex  : Integer;
    NextIndex : Integer;
  end;
  PHashItem=^THashItem;

const
  MaxHashListSize = Maxint div 16;
  MaxHashStrSize  = Maxint;
  MaxHashTableSize = Maxint div 4;
  MaxItemsPerHash = 3;


type
  PHashItemList = ^THashItemList;
  THashItemList = array[0..MaxHashListSize - 1] of THashItem;
  PHashTable = ^THashTable;
  THashTable = array[0..MaxHashTableSize - 1] of Integer;

  TTrHashList = class(TObject)
  private
    { ItemList }
    FHashList     : PHashItemList;
    FCount,
    FCapacity : Integer;
    { Hash }
    FHashTable    : PHashTable;
    FHashCapacity : Integer;
    { Strings }
    FStrs     : PChar;
    FStrCount,
    FStrCapacity : Integer;
    function InternalFind(AHash:LongWord;const AName:shortstring;out PrevIndex:Integer):Integer;
  protected
    procedure SetCapacity(NewCapacity: Integer);
    procedure SetCount(NewCount: Integer);
    Procedure RaiseIndexError(Index : Integer);
    function  AddStr(const s:shortstring): Integer;
    procedure AddToHashTable(Index: Integer);
    procedure StrExpand(MinIncSize:Integer);
    procedure SetStrCapacity(NewCapacity: Integer);
    procedure SetHashCapacity(NewCapacity: Integer);
    procedure ReHash;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AName:shortstring): Integer;
    procedure Clear;
    function NameOfIndex(Index: Integer): ShortString; {$ifdef CCLASSESINLINE}inline;{$endif}
    function HashOfIndex(Index: Integer): LongWord; {$ifdef CCLASSESINLINE}inline;{$endif}
    function GetNextCollision(Index: Integer): Integer;
    procedure Delete(Index: Integer);
    class procedure Error(const Msg: string; Data: PtrInt);
    function Expand: TTrHashList;
    function Find(const AName:shortstring): Boolean;
    function FindIndexOf(const AName:shortstring): Integer;
    function FindWithHash(const AName:shortstring;AHash:LongWord): Boolean;
    function Rename(const AOldName,ANewName:shortstring): Integer;
    procedure Pack;
    procedure ShowStatistics;
    property Capacity: Integer read FCapacity write SetCapacity;
    property Count: Integer read FCount write SetCount;
    property List: PHashItemList read FHashList;
    property Strs: PChar read FStrs;
  end;


implementation


uses
  RtlConsts;


{*****************************************************************************
                            TTrHashList
*****************************************************************************}

    function FPHash(const s:shortstring):LongWord;
      Var
        p,pmax : pchar;
      begin
{$ifopt Q+}
{$define overflowon}
{$Q-}
{$endif}
        result:=0;
        p:=@s[1];
        pmax:=@s[length(s)+1];
        while (p<pmax) do
          begin
            result:=LongWord(LongInt(result shl 5) - LongInt(result)) xor LongWord(P^);
            inc(p);
          end;
{$ifdef overflowon}
{$Q+}
{$undef overflowon}
{$endif}
      end;

    function FPHash(P: PChar; Len: Integer): LongWord;
      Var
        pmax : pchar;
      begin
{$ifopt Q+}
{$define overflowon}
{$Q-}
{$endif}
        result:=0;
        pmax:=p+len;
        while (p<pmax) do
          begin
            result:=LongWord(LongInt(result shl 5) - LongInt(result)) xor LongWord(P^);
            inc(p);
          end;
{$ifdef overflowon}
{$Q+}
{$undef overflowon}
{$endif}
      end;


procedure TTrHashList.RaiseIndexError(Index : Integer);
begin
  Error(SListIndexError, Index);
end;



function TTrHashList.NameOfIndex(Index: Integer): shortstring;
begin
  If (Index < 0) or (Index >= FCount) then
    RaiseIndexError(Index);
  with FHashList^[Index] do
    begin
      if StrIndex>=0 then
        Result:=PShortString(@FStrs[StrIndex])^
      else
        Result:='';
    end;
end;


function TTrHashList.HashOfIndex(Index: Integer): LongWord;
begin
  If (Index < 0) or (Index >= FCount) then
    RaiseIndexError(Index);
  Result:=FHashList^[Index].HashValue;
end;


function TTrHashList.GetNextCollision(Index: Integer): Integer;
begin
  Result:=-1;
  if ((Index > -1) and (Index < FCount)) then
    Result:=FHashList^[Index].NextIndex;
end;


procedure TTrHashList.SetCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < FCount) or (NewCapacity > MaxHashListSize) then
     Error (SListCapacityError, NewCapacity);
  if NewCapacity = FCapacity then
    exit;
  ReallocMem(FHashList, NewCapacity*SizeOf(THashItem));
  FCapacity := NewCapacity;
  { Maybe expand hash also }
  if FCapacity>FHashCapacity*MaxItemsPerHash then
    SetHashCapacity(FCapacity div MaxItemsPerHash);
end;


procedure TTrHashList.SetCount(NewCount: Integer);
begin
  if (NewCount < 0) or (NewCount > MaxHashListSize)then
    Error(SListCountError, NewCount);
  If NewCount > FCount then
    begin
      If NewCount > FCapacity then
        SetCapacity(NewCount);
      If FCount < NewCount then
        FillChar(FHashList^[FCount], (NewCount-FCount) div Sizeof(THashItem), 0);
    end;
  FCount := Newcount;
end;


procedure TTrHashList.SetStrCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < FStrCount) or (NewCapacity > MaxHashStrSize) then
     Error (SListCapacityError, NewCapacity);
  if NewCapacity = FStrCapacity then
    exit;
  ReallocMem(FStrs, NewCapacity);
  FStrCapacity := NewCapacity;
end;


procedure TTrHashList.SetHashCapacity(NewCapacity: Integer);
begin
  If (NewCapacity < 1) then
    Error (SListCapacityError, NewCapacity);
  if FHashCapacity=NewCapacity then
    exit;
  FHashCapacity:=NewCapacity;
  ReallocMem(FHashTable, FHashCapacity*sizeof(Integer));
  ReHash;
end;


procedure TTrHashList.ReHash;
var
  i : Integer;
begin
  FillDword(FHashTable^,FHashCapacity,LongWord(-1));
  For i:=0 To FCount-1 Do
    AddToHashTable(i);
end;


constructor TTrHashList.Create;
begin
  SetHashCapacity(1);
end;


destructor TTrHashList.Destroy;
begin
  Clear;
  if assigned(FHashTable) then
    FreeMem(FHashTable);
  inherited Destroy;
end;


function TTrHashList.AddStr(const s:shortstring): Integer;
var
  Len : Integer;
begin
  len:=length(s)+1;
  if FStrCount+Len >= FStrCapacity then
    StrExpand(Len);
  System.Move(s[0],FStrs[FStrCount],Len);
  result:=FStrCount;
  inc(FStrCount,Len);
end;


procedure TTrHashList.AddToHashTable(Index: Integer);
var
  HashIndex : Integer;
begin
  with FHashList^[Index] do
    begin
      HashIndex:=HashValue mod LongWord(FHashCapacity);
      NextIndex:=FHashTable^[HashIndex];
      FHashTable^[HashIndex]:=Index;
    end;
end;


function TTrHashList.Add(const AName:shortstring): Integer;
begin
  if FCount = FCapacity then
    Expand;
  with FHashList^[FCount] do
    begin
      HashValue:=FPHash(AName);
      StrIndex:=AddStr(AName);
    end;
  AddToHashTable(FCount);
  Result := FCount;
  inc(FCount);
end;

procedure TTrHashList.Clear;
begin
  if Assigned(FHashList) then
    begin
      FCount:=0;
      SetCapacity(0);
      FHashList := nil;
    end;
  SetHashCapacity(1);
  FHashTable^[0]:=(-1); // sethashcapacity does not always call rehash
  if Assigned(FStrs) then
    begin
      FStrCount:=0;
      SetStrCapacity(0);
      FStrs := nil;
    end;
end;

procedure TTrHashList.Delete(Index: Integer);
begin
  If (Index<0) or (Index>=FCount) then
    Error (SListIndexError, Index);
  { Remove from HashList }
  dec(FCount);
  System.Move (FHashList^[Index+1], FHashList^[Index], (FCount - Index) * Sizeof(THashItem));
  { All indexes are updated, we need to build the hashtable again }
  Rehash;
  { Shrink the list if appropriate }
  if (FCapacity > 256) and (FCount < FCapacity shr 2) then
    begin
      FCapacity := FCapacity shr 1;
      ReallocMem(FHashList, Sizeof(THashItem) * FCapacity);
    end;
end;


class procedure TTrHashList.Error(const Msg: string; Data: PtrInt);
begin
  Raise EListError.CreateFmt(Msg,[Data]) at get_caller_addr(get_frame);
end;

function TTrHashList.Expand: TTrHashList;
var
  IncSize : Longint;
begin
  Result := Self;
  if FCount < FCapacity then
    exit;
  IncSize := sizeof(ptrint)*2;
  if FCapacity > 127 then
    Inc(IncSize, FCapacity shr 2)
  else if FCapacity > sizeof(ptrint)*3 then
    Inc(IncSize, FCapacity shr 1)
  else if FCapacity >= sizeof(ptrint) then
    inc(IncSize,sizeof(ptrint));
  SetCapacity(FCapacity + IncSize);
end;

procedure TTrHashList.StrExpand(MinIncSize:Integer);
var
  IncSize : Longint;
begin
  if FStrCount+MinIncSize < FStrCapacity then
    exit;
  IncSize := 64;
  if FStrCapacity > 255 then
    Inc(IncSize, FStrCapacity shr 2);
  SetStrCapacity(FStrCapacity + IncSize + MinIncSize);
end;



function TTrHashList.InternalFind(AHash:LongWord;const AName:shortstring;out PrevIndex:Integer):Integer;
var
  HashIndex : Integer;
  Len,
  LastChar  : Char;
begin
  HashIndex:=AHash mod LongWord(FHashCapacity);
  Result:=FHashTable^[HashIndex];
  Len:=Char(Length(AName));
  LastChar:=AName[Byte(Len)];
  PrevIndex:=-1;
  while Result<>-1 do
    begin
      with FHashList^[Result] do
        begin
          if (HashValue=AHash) and
             (Len=FStrs[StrIndex]) and
             (LastChar=FStrs[StrIndex+Byte(Len)]) and
             (AName=PShortString(@FStrs[StrIndex])^) then
            exit;
          PrevIndex:=Result;
          Result:=NextIndex;
        end;
    end;
end;


function TTrHashList.Find(const AName:shortstring): Boolean;
var
  Index,
  PrevIndex : Integer;
begin
  Result := false;
  Index:=InternalFind(FPHash(AName),AName,PrevIndex);
  if Index <> -1 then
    Result := true;
end;


function TTrHashList.FindIndexOf(const AName:shortstring): Integer;
var
  PrevIndex : Integer;
begin
  Result:=InternalFind(FPHash(AName),AName,PrevIndex);
end;


function TTrHashList.FindWithHash(const AName:shortstring;AHash:LongWord): Boolean;
var
  Index,
  PrevIndex : Integer;
begin
  Result := false;
  Index:=InternalFind(AHash,AName,PrevIndex);
  if Index <> -1 then
    Result := true;
end;


function TTrHashList.Rename(const AOldName,ANewName:shortstring): Integer;
var
  PrevIndex,
  Index : Integer;
  OldHash : LongWord;
begin
  Result:=-1;
  OldHash:=FPHash(AOldName);
  Index:=InternalFind(OldHash,AOldName,PrevIndex);
  if Index=-1 then
    exit;
  { Remove from current Hash }
  if PrevIndex<>-1 then
    FHashList^[PrevIndex].NextIndex:=FHashList^[Index].NextIndex
  else
    FHashTable^[OldHash mod LongWord(FHashCapacity)]:=FHashList^[Index].NextIndex;
  { Set new name and hash }
  with FHashList^[Index] do
    begin
      HashValue:=FPHash(ANewName);
      StrIndex:=AddStr(ANewName);
    end;
  { Insert back in Hash }
  AddToHashTable(Index);
  { Return Index }
  Result:=Index;
end;

procedure TTrHashList.Pack;
var
  NewCount,
  i : integer;
  pdest,
  psrc : PHashItem;
  FOldStr : Pchar;

begin
  NewCount:=0;
  psrc:=@FHashList^[0];
  FOldStr:=FStrs;
  try
    FStrs:=Nil;
    FStrCount:=0;
    FStrCapacity:=0;
    pdest:=psrc;
    For I:=0 To FCount-1 Do
      begin
        pdest^:=psrc^;
        Pdest^.strindex:=AddStr(PShortString(@FOldStr[PDest^.StrIndex])^);
        inc(pdest);
        inc(NewCount);
        inc(psrc);
      end;
  finally
    FreeMem(FoldStr);
  end;
  FCount:=NewCount;
  { We need to ReHash to update the IndexNext }
  ReHash;
  { Release over-capacity }
  SetCapacity(FCount);
  SetStrCapacity(FStrCount);
end;


procedure TTrHashList.ShowStatistics;
var
  HashMean,
  HashStdDev : Double;
  Index,
  i,j : Integer;
begin
  { Calculate Mean and StdDev }
  HashMean:=0;
  HashStdDev:=0;
  for i:=0 to FHashCapacity-1 do
    begin
      j:=0;
      Index:=FHashTable^[i];
      while (Index<>-1) do
        begin
          inc(j);
          Index:=FHashList^[Index].NextIndex;
        end;
      HashMean:=HashMean+j;
      HashStdDev:=HashStdDev+Sqr(j);
    end;
  HashMean:=HashMean/FHashCapacity;
  HashStdDev:=(HashStdDev-FHashCapacity*Sqr(HashMean));
  If FHashCapacity>1 then
    HashStdDev:=Sqrt(HashStdDev/(FHashCapacity-1))
  else
    HashStdDev:=0;
  { Print info to stdout }
  Writeln('HashSize   : ',FHashCapacity);
  Writeln('HashMean   : ',HashMean:1:4);
  Writeln('HashStdDev : ',HashStdDev:1:4);
  Writeln('ListSize   : ',FCount,'/',FCapacity);
  Writeln('StringSize : ',FStrCount,'/',FStrCapacity);
end;

end.
