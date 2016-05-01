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


unit TrDivDeduplicator;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  Classes,
  IniFiles,
  TrData,
  TrRabinHash,
  TrUtilities,
  TrDocumentProcessor;


procedure TrInitDivDeduplicator;
procedure TrFreeDivDeduplicator;


type

  ETrDivDeduplicator = class(Exception);


  TTrDupDivInfo = packed record
    Number : Integer;
    Hash : QWord;
  end;


  TTrDupDivInfoBucket = array of TTrDupDivInfo;
  TTrDupDivInfoBuckets = array of TTrDupDivInfoBucket;


  // A very simple hash list relying on a single Rabin64 being collision
  // free enough, and that 256 buckets are well enough. Do not use for
  // any other purpose than TTrDivDeduplicator.
  TTrSimpleHashList = class(TObject)
  public
    constructor Create(const ABucketNumber : Integer = 256);
    destructor Destroy; override;

    // Returns a number of which AKey was a duplicate.
    // If not a duplicate, ANumber is returned.
    function IsDuplicateOf(const AKey : String;
      const ANumber : Integer) : Integer;
  protected
    FBuckets : TTrDupDivInfoBuckets;
    FBucketNumber : Integer;
  end;


  TTrDivDeduplicator = class(TTrDocumentProcessor)
  public
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FCharacterThreshold : Integer;
  published
    property CharacterThreshold : Integer read FCharacterThreshold
      write FCharacterThreshold default 3;
  end;


implementation


var
  Rabin : TTrRabin64 = nil;



procedure TrInitDivDeduplicator;
begin
  Rabin := TTrRabin64.Create;
end;


procedure TrFreeDivDeduplicator;
begin
  FreeAndNil(Rabin);
end;



{ *** TTrSimpleHashList *** }



constructor TTrSimpleHashList.Create(
  const ABucketNumber : Integer = 256);
begin
  if ABucketNumber > 4
  then FBucketNumber := ABucketNumber
  else FBucketNumber := 4;
  SetLength(FBuckets, FBucketNumber);
end;


destructor TTrSimpleHashList.Destroy;
var
  i : Integer;
begin
  for i := 0 to FBucketNumber-1
  do SetLength(FBuckets[i], 0);
  SetLength(FBuckets, 0);
  inherited Destroy;
end;


function TTrSimpleHashList.IsDuplicateOf(const AKey : String;
  const ANumber : Integer) : Integer;
var
  i : Integer;
  LHash : QWord;
  LBucket : Integer;
begin
  Result := ANumber;
  LHash := Rabin.Hash(AKey);
  LBucket := LHash mod FBucketNumber;

  // Find what this is a duplicate of.
  for i := 0 to High(FBuckets[LBucket])
  do if FBuckets[LBucket][i].Hash = LHash
  then begin
    Result := FBuckets[LBucket][i].Number;
    Break;
  end;

  // If nothing was found, add to appropriate bucket.
  if Result = ANumber
  then begin
    SetLength(FBuckets[LBucket], Length(FBuckets[LBucket])+1);
    with FBuckets[LBucket][High(FBuckets[LBucket])]
    do begin
      Number := ANumber;
      Hash := LHash;
    end;
  end;
end;



{ *** TTrDivDeduplicator *** }


procedure TTrDivDeduplicator.Process(
  const ADocument : TTrDocument);
var
  LHashes : TTrSimpleHashList = nil;
  LDupIdx : Integer;
  i : Integer;
begin
  inherited Process(ADocument);

  if ADocument.Number < 2
  then Exit;

  if not Assigned(Rabin)
  then raise ETrDivDeduplicator.Create(
    'TrInitDivDeduplicator was not called before use.');

  // Create a hash list with half as many buckets as pars. Heuristics.
  LHashes := TTrSimpleHashList.Create(ADocument.Number div 2);
  try
    for i := 0 to ADocument.Number
    do begin
      if Assigned(ADocument[i])
      and (ADocument[i].Size >= FCharacterThreshold)
      then begin
        LDupIdx := LHashes.IsDuplicateOf(ADocument[i].Text, i);
        if LDupIdx <> i
        then ADocument[i].IsDuplicateOf := LDupIdx;
      end;
    end;
  finally
    FreeAndNil(LHashes);
  end;
end;


class function TTrDivDeduplicator.Achieves : TTrPrerequisites;
begin
  Result := [trpreUniqueDivs];
end;


class function TTrDivDeduplicator.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped];
end;


finalization

  TrFreeDivDeduplicator;

end.
