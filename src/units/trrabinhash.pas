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


{ This unit is based on the implementation in Java by Sean Owen:
  http://sourceforge.net/projects/rabinhash/ }


unit TrRabinHash;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  TrPoly64;


type
  ETrRabinHash = class(Exception);

  TQWordArray = array of QWord;


type
  TTrRabin64 = class(TObject)
  public
    constructor Create(const APoly : QWord);
    constructor Create;
    destructor Destroy; override;
    function Hash(const AString : String) : QWord;
    function Hash(const AString : String; const AOffset : Integer;
      const ALength : Integer; var W : QWord) : QWord;
    function Hash(const AInts : TQWordArray) : QWord;
  protected
    FPoly : QWord;
    FTable32 : TQWordArray;
    FTable40 : TQWordArray;
    FTable48 : TQWordArray;
    FTable56 : TQWordArray;
    FTable64 : TQWordArray;
    FTable72 : TQWordArray;
    FTable80 : TQWordArray;
    FTable88 : TQWordArray;
    procedure InitializeTables;
    function ComputeShifted(const W : QWord) : QWord;
  end;


  // This class provides access to a number of Rabin hash functions
  // with different, distinct and irreducible polynomials.
  TTrHashProvider = class(TObject)
  public
    constructor Create(const ANumberOfHashes : Integer;
      ADeterministic : Boolean = true);
    destructor Destroy; override;
    function Hash(const AString : String; const AIndex : Integer) :
      QWord;
  protected
    FHashFunctions : array of TTrRabin64;
    function GetSize : Integer;
  public
    property Size : Integer read GetSize;
  end;



implementation


const
  DefaultPoly : QWord = QWord($E5FE94D7ABBF88A1);
  PolyDegree : Integer = 64;
  TrHashProvider : TTrHashProvider = nil;
var
  XpDegree : QWord = 0;


constructor TTrRabin64.Create(const APoly : QWord);
begin
  FPoly := APoly;
  InitializeTables;
end;


constructor TTrRabin64.Create;
begin
  Create(DefaultPoly);
end;


destructor TTrRabin64.Destroy;
begin
  SetLength(FTable32, 0);
  SetLength(FTable40, 0);
  SetLength(FTable48, 0);
  SetLength(FTable56, 0);
  SetLength(FTable64, 0);
  SetLength(FTable72, 0);
  SetLength(FTable80, 0);
  SetLength(FTable88, 0);
  inherited;
end;


procedure TTrRabin64.InitializeTables;
var
  LMods : TQWordArray;
  LastMod : QWord;
  ThisMod : QWord;
  i, j : Integer;
  Cntrl : Integer;
begin
  SetLength(LMods, PolyDegree);

  LMods[0] := FPoly;
  for i := 1 to PolyDegree - 1
  do begin
    LastMod := LMods[i-1];
    ThisMod := LastMod shl 1;
    if ((LastMod and XpDegree) <> 0)
    then ThisMod := ThisMod xor FPoly;
    LMods[i] := ThisMod;
  end;

  SetLength(FTable32, 256);
  SetLength(FTable40, 256);
  SetLength(FTable48, 256);
  SetLength(FTable56, 256);
  SetLength(FTable64, 256);
  SetLength(FTable72, 256);
  SetLength(FTable80, 256);
  SetLength(FTable88, 256);

  for i := 0 to 256
  do begin
    Cntrl := i;
    j := 0;
    while (j < 8)
    and (Cntrl > 0)
    do begin
      if ((Cntrl and 1) <> 0)
      then begin
        FTable32[i] := FTable32[i] xor LMods[j];
        FTable40[i] := FTable40[i] xor LMods[j + 8];
        FTable48[i] := FTable48[i] xor LMods[j + 16];
        FTable56[i] := FTable56[i] xor LMods[j + 24];
        FTable64[i] := FTable64[i] xor LMods[j + 32];
        FTable72[i] := FTable72[i] xor LMods[j + 40];
        FTable80[i] := FTable80[i] xor LMods[j + 48];
        FTable88[i] := FTable88[i] xor LMods[j + 56];
      end;
      // In Java, shr was >>>.
      Cntrl := Cntrl shr 1;
      Inc(j)
    end;
  end;
end;


function TTrRabin64.ComputeShifted(const W : QWord) : QWord;
begin
  // In Java, shr was >>>.
  Result := FTable32[QWord( W         and $FF)] xor
            FTable40[QWord((W shr  8) and $FF)] xor
            FTable48[QWord((W shr 16) and $FF)] xor
            FTable56[QWord((W shr 24) and $FF)] xor
            FTable64[QWord((W shr 32) and $FF)] xor
            FTable72[QWord((W shr 40) and $FF)] xor
            FTable80[QWord((W shr 48) and $FF)] xor
            FTable88[QWord((W shr 56) and $FF)];
end;


function TTrRabin64.Hash(const AString : String;
  const AOffset : Integer; const ALength : Integer;
  var W : QWord) : QWord;
var
  S : Integer;
  StarterBytes : Integer;
  Max : Integer;
  LLength : Integer = 0;
begin

  // Protection against reading beyond Length(AString).
  LLength := ALength;
  if LLength >= AOffset + Length(AString)
  then LLength := (Length(AString) - AOffset) + 1;

  S := AOffset;
  StarterBytes := (LLength) mod 8;
  if StarterBytes <> 0
  then begin
    Max := (AOffset + StarterBytes);
    while S < Max
    do begin
      W := (W shl 8) xor QWord(Ord(AString[S]) and $FF);
      Inc(S);
    end;
  end;

  // Note : S is as left by last loop, we continue here...
  Max := (AOffset + LLength) - 1;
  while S < Max
  do begin
    W :=  ComputeShifted(W)                            xor
          (QWord(Ord(AString[S]))             shl 56) xor
          (QWord(Ord(AString[S + 1]) and $FF) shl 48) xor
          (QWord(Ord(AString[S + 2]) and $FF) shl 40) xor
          (QWord(Ord(AString[S + 3]) and $FF) shl 32) xor
          (QWord(Ord(AString[S + 4]) and $FF) shl 24) xor
          (QWord(Ord(AString[S + 5]) and $FF) shl 16) xor
          (QWord(Ord(AString[S + 6]) and $FF) shl  8) xor
           QWord(Ord(AString[S + 7]) and $FF);
    Inc(S, 8);
  end;
  Result := W;
end;


function TTrRabin64.Hash(const AInts : TQWordArray) : QWord;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to Length(AInts)
  do Result := ComputeShifted(Result) xor AInts[i];
end;


function TTrRabin64.Hash(const  AString : String) : QWord;
var
  W : QWord = 0;
begin
  Result := Hash(AString, 1, Length(AString), W);
end;


{ *** TTrHashProvider *** }


constructor TTrHashProvider.Create(const ANumberOfHashes :
  Integer; ADeterministic : Boolean = true);
var
  i : Integer;
  KnownPolys : array of QWord;
  NextPoly : QWord;
  IsKnown : Boolean;
begin

  // We currently only have 1000 random polys in Poly64.
  if ANumberOfHashes > 1000
  then raise ETrRabinHash.Create('Currently, 1000 hash functions is ' +
    'the limit.');

  SetLength(KnownPolys, 0);
  SetLength(FHashFunctions, 0);

  // Now select ANumberOfHashes random polys an create appropriate
  // hash function, avoiding identical functions.... or (if
  // deterministic), just use first n.
  if ADeterministic
  then begin
    SetLength(FHashFunctions, ANumberOfHashes);
    for i := 0 to High(FHashFunctions)
    do begin
      NextPoly := Polys64[i];
      FHashFunctions[i] := TTrRabin64.Create(NextPoly);
      if not Assigned(FHashFunctions[i])
      then
        raise ETrRabinHash.Create('One Rabin hash function could ' +
          'not be created.');
    end;
  end

  else begin
    Randomize;
    while Length(KnownPolys) < ANumberOfHashes
    do begin
      IsKnown := false;
      NextPoly := Polys64[Random(999)];
      for i := 0 to High(KnownPolys)
      do
        if (KnownPolys[i] = NextPoly)
        then IsKnown := true;

      // Only if poly is not known, add a hash function with it.
      if not IsKnown
      then begin
        SetLength(KnownPolys, Length(KnownPolys)+1);
        SetLength(FHashFunctions, Length(FHashFunctions)+1);
        KnownPolys[High(KnownPolys)] := NextPoly;
        FHashFunctions[High(FHashFunctions)] :=
          TTrRabin64.Create(NextPoly);
        if not Assigned(FHashFunctions[High(FHashFunctions)])
        then
          raise ETrRabinHash.Create('One Rabin hash function could ' +
            'not be created.');
      end;
    end;
  end;

  SetLength(KnownPolys, 0);
end;


destructor TTrHashProvider.Destroy;
var
  i : Integer;
begin
  for i := 0 to High(FHashFunctions)
  do begin
    if Assigned(FHashFunctions[i])
    then FreeAndNil(FHashFunctions[i]);
  end;
  SetLength(FHashFunctions, 0);
  inherited Destroy;
end;


function TTrHashProvider.Hash(const AString : String;
  const AIndex : Integer) : QWord;
begin
  if (AIndex < Length(FHashFunctions))
  and Assigned(FHashFunctions[AIndex])
  then Result := FHashFunctions[AIndex].Hash(AString)
  else Result := 0;
end;


function TTrHashProvider.GetSize : Integer;
begin
  Result := Length(FHashFunctions);
end;


initialization

  XpDegree := QWord(1) shl (PolyDegree - 1);


end.
