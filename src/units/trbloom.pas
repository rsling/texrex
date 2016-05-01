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


// This unit provides a straightforward non-optimized Bloom Filter
// for strings and a self-scaling fixed error rate Bloom Filter.
// It use Rabin hashes from the TrRabinHash unit and TBits for the bit
// arrays, but it can represent longer bit arrays than TBits by using
// several TBits objects.


unit TrBloom;


{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils,
  Math,
  Classes,
  SyncObjs,
  TrRabinHash;


type

  ETrBloom = class(Exception);

  TBitsArray = array of TBits;
  TQWordArray = array of QWord;

  // Abstract class from which all implented filters inherit.
  TTrCustomBloomFilter = class(TObject)
  public
    function Add(const AKey : String) : Boolean; virtual; abstract;
    function Check(const AKey : String) : Boolean; virtual;
      abstract;
  protected
    function GetMemoryUsage : Integer; virtual; abstract;
    function GetAdds : QWord; virtual; abstract;
    function GetRejects : QWord; virtual; abstract;
    function GetErrorRate : Real; virtual; abstract;
    function GetIsFull : Boolean; virtual; abstract;
  public
    property MemoryUsage : Integer read GetMemoryUsage;
    property Adds : QWord read GetAdds;
    property Rejects : QWord read GetRejects;
    property ErrorRate : Real read GetErrorRate;
    property IsFull : Boolean read GetIsFull;
  end;


  // This implementations uses the calculations as described in:
  // Broder & Mitzenmacher (2004). "Network Applications of Bloom
  // Filters: A Survey". Internet Mathematics 1:4, 485-509
  TTrBloomFilter = class(TTrCustomBloomFilter)
  public

    // Based on the size of the set and the error rate,
    // the appropriate number of bits and hash functions will
    // be created. We avoid Grow() calls in TBits.
    constructor Create(AExpectedMembers : QWord;
      ADesiredErrorRate : Real); virtual;
    destructor Destroy; override;

    // Add a string to the set. Returns true if string was added,
    // false if it was already a member.
    function Add(const AKey : String) : Boolean; override;

    // Return whether AKey is already a member.
    function Check(const AKey : String) : Boolean; override;

    class function CalcBitsNeeded(AExpectedMembers : QWord;
      ADesiredErrorRate : Real) : QWord;
    class function MaxBitsCapacity : QWord;
  protected
    FExpectedMembers : QWord;
    FDesiredErrorRate : Real;
    FHashFunctionCount : Integer;

    // The maximum capacity of TBits on this system.
    FBitsNeeded : QWord;

    // Since TBitsArray cannot be arbitrary in size, we potentially
    // need several of them, the following variables hold the relevant
    // data structures.
    FBitArraysNeeded : Integer;
    FBitsPerBitArray : Integer;

    // The absolute starting offsets of the BitsArrays.
    FLowerBounds : array of QWord;
    FBitArrays : TBitsArray;

    // The Rabin hasher used to
    FHasher : TTrHashProvider;

    // How many keys were added and rejected (true and false positives).
    FAdds : QWord;
    FRejects : QWord;

    // The CS around adds.
    FAddLock : TCriticalSection;
    function GetMemoryUsage : Integer; override;
    function GetAdds : QWord; override;
    function GetRejects : QWord; override;
    function GetErrorRate : Real; override;
    function GetIsFull : Boolean; override;

    // The low-level internal functions that perform the actual adding
    // of hash values to the TBitsArrays.
    function CheckLow(AHash : QWord) : Boolean; inline;
    procedure AddLow(AHash : QWord); inline;
  public
    property DesiredErrorRate : Real read FDesiredErrorRate;
    property ExpectedMembers : QWord read FExpectedMembers;
    property BitsNeeded : QWord read FBitsNeeded;
    property BitArraysNeeded : Integer read FBitArraysNeeded;
    property BitsPerBitArray : Integer read FBitsPerBitArray;
    property HashFunctionCount : Integer read FHashFunctionCount;

    // This is in kB.
    property MemoryUsage : Integer read GetMemoryUsage;
    property Adds : QWord read GetAdds;
    property Rejects : QWord read GetRejects;
    property ErrorRate : Real read GetErrorRate;
    property IsFull : Boolean read GetIsFull;
  end;


  TTrBloomFilterArray = array of TTrBloomFilter;


  // This Bloom Filter grows roughly as described in:
  // Paulo Sérgio Almeida, Carlos Baquero, Nuno Preguiça,
  // David Hutchison, "Scalable Bloom Filters". Information
  // Processing Letters 101 (2007), p. 255–261.
  // This filter might be slower than necessary, because it does not
  // reuse the hash values when talking to the low-level Bloom filters.
  // This would be difficult to implement, however, since the filters
  // have different numbers of hash functions. (RS)
  TTrScalingBloomFilter = class(TTrCustomBloomFilter)
  public

    // This filter starts with a heuristically calculated initial size
    // and grows automatically when the desired error rate is reached.
    constructor Create(ADesiredErrorRate : Real;
      AMaxMemoryMb : Integer = 1024); virtual;
    destructor Destroy; override;
    function Add(const AKey : String) : Boolean; override;
    function Check(const AKey : String) : Boolean; override;
  protected
    FDesiredErrorRate : Real;
    FMaxMemoryBits : QWord;
    FOutOfMemory : Boolean;
    FBloomFilters : TTrBloomFilterArray;
    FGrowLock : TCriticalSection;
    procedure Grow;
    function GetAdds : QWord; override;
    function GetRejects : QWord; override;
    function GetMemoryUsage : Integer; override;
    function GetScalings : Integer;
    function GetFilterSize : QWord;
    function GetErrorRate : Real; override;
    function GetIsFull : Boolean; override;
    function GetMeanErrorRate : Real;
    function GetMaxMemoryMb : Integer;
  public
    property Adds : QWord read GetAdds;
    property Rejects : QWord read GetRejects;
    property DesiredErrorRate : Real read FDesiredErrorRate;
    property MemoryUsage : Integer read GetMemoryUsage;
    property Scalings : Integer read GetScalings;
    property FilterSize : QWord read GetFilterSize;
    property ErrorRate : Real read GetErrorRate;
    property IsFull : Boolean read GetIsFull;
    property OutOfMemory : Boolean read FOutOfMemory;
    property FMaxMemoryMb : Integer read GetMaxMemoryMb;

    // The weighted harmonic mean of error rates from all filters.
    property MeanErrorRate : Real read GetMeanErrorRate;
  end;



implementation



{ ***** TTrBloomFilter ***** }



constructor TTrBloomFilter.Create(AExpectedMembers : QWord;
  ADesiredErrorRate : Real);
var
  i : Integer;
  LLowerBound : QWord;
begin
  FAdds := 0;
  FRejects := 0;
  FExpectedMembers := AExpectedMembers;
  FDesiredErrorRate := ADesiredErrorRate;

  if FExpectedMembers < 1
  then raise ETrBloom.Create('Too low expected members number (' +
    IntToStr(FExpectedMembers) + ').');

  FAddLock := TCriticalSection.Create;

  // n expected members, m bits, k hash functions for error rate e:
  // bit length: m = - (n ln p) / (ln2)^2
  // optimal number of hash functions: k = (m/n) * ln2
  FBitsNeeded := CalcBitsNeeded(FExpectedMembers, FDesiredErrorRate);
  FHashFunctionCount := Round((FBitsNeeded/FExpectedMembers)*ln(2));

  FBitArraysNeeded := FBitsNeeded div MaxBitsCapacity;
  if (FBitsNeeded mod MaxBitsCapacity > 0)
  then Inc(FBitArraysNeeded);

  // Safety bit to avoid hassle with different lengths.
  FBitsPerBitArray := (FBitsNeeded div FBitArraysNeeded) + 1;

  // Pre-calculate the lower bounds (starting values of each array).
  LLowerBound := 0;
  SetLength(FLowerBounds, FBitArraysNeeded);
  for i := 0 to FBitArraysNeeded - 1
  do begin
    FLowerBounds[i] := LLowerBound;
    Inc(LLowerBound, FBitsPerBitArray);
  end;

  // Let's go. Create a deterministic hash provider (= always the same
  // polynomials).
  FHasher := TTrHashProvider.Create(FHashFunctionCount, true);

  // Create the TBits.
  SetLength(FBitArrays, FBitArraysNeeded);
  for i := 0 to High(FBitArrays)
  do FBitArrays[i] := TBits.Create(FBitsPerBitArray);

end;


destructor TTrBloomFilter.Destroy;
var
  i : Integer;
begin
  FreeAndNil(FHasher);

  for i := 0 to High(FBitArrays)
  do begin
    FreeAndNil(FBitArrays[i]);
  end;

  FreeAndNil(FAddLock);

  inherited Destroy;
end;


class function TTrBloomFilter.CalcBitsNeeded(AExpectedMembers : QWord;
  ADesiredErrorRate : Real) : QWord;
begin
  Result :=
    Trunc(-((AExpectedMembers*ln(ADesiredErrorRate))/(ln(2)*ln(2))))+1;
end;


class function TTrBloomFilter.MaxBitsCapacity : QWord;
begin

  // Cardinal is a 4 bit unsigned integer.
  Result := MaxBitRec * SizeOf(Cardinal) * 8 - 1;
end;


function TTrBloomFilter.CheckLow(AHash : QWord) : Boolean; inline;
var
  j : Integer;
begin
  for j := 0 to High(FLowerBounds)
  do begin
    if ( j = High(FLowerBounds) )
    or (     (AHash >= FLowerBounds[j]  )
         and (AHash <  FLowerBounds[j+1]) )
    then begin
      Result := FBitArrays[j].Get(AHash-FLowerBounds[j]);
      Break;
    end;
  end;
end;


procedure TTrBloomFilter.AddLow(AHash : QWord); inline;
var
  j : Integer;
begin
  FAddLock.Enter;
  try
    for j := 0 to High(FLowerBounds)
    do begin
      if ( j = High(FLowerBounds) )
      or (     (AHash >= FLowerBounds[j]  )
           and (AHash <  FLowerBounds[j+1]) )
      then begin
        FBitArrays[j].SetOn(AHash-FLowerBounds[j]);
        Break;
      end;
    end;
  finally
    FAddLock.Leave;
  end;
end;


function TTrBloomFilter.Add(const AKey : String) : Boolean;
var
  i : Integer;
  LHashArray : TQWordArray;
  LChecks : Boolean;
begin
  Result := false;

  // If even one check is false, this will turn false.
  LChecks := true;

  // First, we check.
  SetLength(LHashArray, FHashFunctionCount);

  // Hash k times and check the low-level arrays.
  for i := 0 to FHashFunctionCount - 1
  do begin

    // Hash and save hash.
    LHashArray[i] := FHasher.Hash(AKey, i) mod FBitsNeeded;

    // Once we know we will add, we must keep hashing, but do not
    // need to try seek further.
    if LChecks
    then LChecks := LChecks and CheckLow(LHashArray[i]);
  end;

  // We only add and count(!) the add when it is not already in the set.
  if not LChecks
  then begin

    // Hash k times and add to the low-level arrays.
    for i := 0 to FHashFunctionCount - 1
    do AddLow(LHashArray[i]);
    Inc(FAdds);
    Result := true;
  end
  else Inc(FRejects);
end;


function TTrBloomFilter.Check(const AKey : String) : Boolean;
var
  i : Integer;
begin

  // Partial results are ANDed. If a single false is among them,
  // this will turn false.
  Result := true;

  // Hash k times and check the low-level arrays.
  for i := 0 to FHashFunctionCount - 1
  do begin
    Result :=
      Result and CheckLow(FHasher.Hash(AKey, i) mod FBitsNeeded);

    // We can save time hashing etc. when we exit as soon as falsehood
    // reached (at least until filter starts overflowing).
    if not Result
    then Break;
  end;

end;


function TTrBloomFilter.GetMemoryUsage : Integer;
begin
  Result := FBitsNeeded div 8192;
end;


function TTrBloomFilter.GetAdds : QWord;
begin
  Result := FAdds;
end;


function TTrBloomFilter.GetRejects : QWord;
begin
  Result := FRejects;
end;


function TTrBloomFilter.GetErrorRate : Real;
var
  P : Real;
begin

  // Probability that any bit is 0:
  P := Power((1-(1/FBitsNeeded)), (FHashFunctionCount*FAdds));
  Result := Power((1-P),FHashFunctionCount);
end;


function TTrBloomFilter.GetIsFull : Boolean;
begin
  Result := (ErrorRate >= FDesiredErrorRate);
end;



{ ***** TTrScalingBloomFilter ***** }



constructor TTrScalingBloomFilter.Create(ADesiredErrorRate : Real;
  AMaxMemoryMb : Integer = 1024);
begin
  FDesiredErrorRate := ADesiredErrorRate;
  FMaxMemoryBits := AMaxMemoryMb * 8242880;
  FOutOfMemory := false;

  // We always start with one underlying filter.
  SetLength(FBloomFilters, 1);

  // The calculation of the initial filter size involves a bit of
  // heuristics. We start with n=(e)^(-1).
  FBloomFilters[0] := TTrBloomFilter.Create(
    Round(Power(FDesiredErrorRate,-1)), FDesiredErrorRate);

  FGrowLock := TCriticalSection.Create;
end;


destructor TTrScalingBloomFilter.Destroy;
var
  i : Integer;
begin
  for i := 0 to High(FBloomFilters)
  do FreeAndNil(FBloomFilters[i]);
  FreeAndNil(FGrowLock);
  inherited Destroy;
end;


function TTrScalingBloomFilter.Add(const AKey : String) : Boolean;
var
  i : Integer;
  LChecks : Boolean;
begin

  // If key is in any filter, this will become true.
  LChecks := false;

  // Check in full (old/"closed") filters.
  for i := 0 to High(FBloomFilters)-1
  do begin
    LChecks := LChecks or FBloomFilters[i].Check(AKey);

    // Exit when key found. Not just Break – we're really done.
    if LChecks
    then begin
      Result := false;
      Exit;
    end;
  end;

  // Last filter: Check-Add... LChecks is still false if we're here.
  // If Result is true, we added the key, if false, it was already
  // there.
  Result := FBloomFilters[High(FBloomFilters)].Add(AKey);

  // If this add has raised the error rate too high, grow.
  // We only need to do that if we actually added something. Otherwise
  // we're still as good as at the last call.
  if  Result
  and FBloomFilters[High(FBloomFilters)].IsFull
  and not FOutOfMemory
  then begin
    FGrowLock.Enter;
    try

      // We check again, becaue we might have been waiting for the lock
      // while another thread was growing the filter.
      if FBloomFilters[High(FBloomFilters)].IsFull
      and not FOutOfMemory
      then Grow;
    finally
      FGrowLock.Leave;
    end;
  end;
end;


function TTrScalingBloomFilter.Check(const AKey : String) :
  Boolean;
var
  i : Integer;
begin
  Result := false;

  // We need to check in all filters, because we do not know when this
  // key was added.
  for i := 0 to High(FBloomFilters)
  do begin
    Result := Result or FBloomFilters[i].Check(AKey);
    if Result
    then Break;
  end;
end;


procedure TTrScalingBloomFilter.Grow;
var
  LLastFilterSize : QWord;
  LNewFilterSize : QWord;
begin

  // NOTE RS The upscaling is not done the way they describe it in the
  // paper.
  LLastFilterSize := FBloomFilters[High(FBloomFilters)].ExpectedMembers;
  LNewFilterSize := LLastFilterSize*2;

  // Check whether we are within the set memory limit.
  if MemoryUsage + TTrBloomFilter.CalcBitsNeeded(LNewFilterSize,
    FDesiredErrorRate) > FMaxMemoryBits
  then begin
    FOutOfMemory := true;
    Exit;
  end;

  // Grow Bloom Filter array.
  SetLength(FBloomFilters, Length(FBloomFilters)+1);

  // Catch EOutOfMemory and set FOutOfMemory.
  try
    FBloomFilters[High(FBloomFilters)] :=
      TTrBloomFilter.Create(LNewFilterSize, FDesiredErrorRate);
  except
    // If this is the best we can do, revert...
    on EOutOfMemory
    do begin
      // The low-level has not been created, no need to free it, just
      // make array shorter again.
      FOutOfMemory := true;
      SetLength(FBloomFilters, Length(FBloomFilters)-1);
    end;
  end;
end;


function TTrScalingBloomFilter.GetAdds : QWord;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FBloomFilters)
  do Result += FBloomFilters[i].Adds;
end;


function TTrScalingBloomFilter.GetRejects : QWord;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FBloomFilters)
  do Result += FBloomFilters[i].Rejects;
end;


function TTrScalingBloomFilter.GetMemoryUsage : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FBloomFilters)
  do Result += FBloomFilters[i].MemoryUsage;
end;


function TTrScalingBloomFilter.GetScalings : Integer;
begin
  Result := High(FBloomFilters);
end;


function TTrScalingBloomFilter.GetFilterSize : QWord;
begin
  Result := FBloomFilters[High(FBloomFilters)].ExpectedMembers;
end;


function TTrScalingBloomFilter.GetErrorRate : Real;
begin
  Result := FBloomFilters[High(FBloomFilters)].ErrorRate;
end;


function TTrScalingBloomFilter.GetIsFull : Boolean;
begin
  Result := FBloomFilters[High(FBloomFilters)].IsFull;
end;


function TTrScalingBloomFilter.GetMeanErrorRate : Real;
var
  i : Integer;
  LAllAds : QWord;
  LNumerator : Real;
  LDenominator : Real;
  LWeight : Real;
begin

  // Get total adds once.
  LAllAds := Adds;

  LNumerator := 0;
  LDenominator := 0;

  // First, get total
  for i := 0 to High(FBloomFilters)
  do begin

    // The filter weighs its share of adds.
    LWeight := FBloomFilters[i].Adds / LAllAds;
    LNumerator += LWeight;
    LDenominator += LWeight / FBloomFilters[i].ErrorRate;
  end;

  if LDenominator <> 0
  then Result := LNumerator / LDenominator
  else Result := -1;

end;


function TTrScalingBloomFilter.GetMaxMemoryMb : Integer;
begin
  Result := FMaxMemoryBits div 8242880;
end;


end.
