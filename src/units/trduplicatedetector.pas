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


unit TrDuplicateDetector;


{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  SysUtils,
  Classes,
  SyncObjs,
  Contnrs,
  IniFiles,
  TrUtilities,
  TrBloom,
  TrData,
  TrDocumentProcessor;


type
  ETrDuplicateDetector = class(Exception);

  // A perfect duplicate deduper which uses a Bloom Filter or a hash
  // list (more memory, but no false positives).
  TTrDuplicateDetector = class(TTrDocumentProcessor)
  public

    // Uses a Bloom filter with a certain rate of false positives.
    constructor Create(const AIni : TIniFile); override;
    destructor Destroy; override;

    // This only sets Valid := false, never := true.
    // If already = false, then doc is ignored anyway.
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected

    FFingerprintSize : Integer;
  published
    property FingerprintSize : Integer read FFingerprintSize
      write FFingerprintSize default 64;
  end;


// This must be called before any thread/function uses the deduplicator.
procedure TrInitDuplicateDetector(const AErrorRate : Real);

// Will be called anyway on finalization.
procedure TrFreeDuplicateDetector;



implementation


var
  Bloom : TTrScalingBloomFilter = nil;


{ *** TTrDuplicateDetector *** }


constructor TTrDuplicateDetector.Create(const AIni : TIniFile);
begin
  if not Assigned(Bloom)
  then raise ETrDuplicateDetector.Create('Bloom Filter was nil. ' +
    'Call TrInitDuplicateDetector first.');

  inherited Create(AIni);
end;


destructor TTrDuplicateDetector.Destroy;
begin
  inherited Destroy;
end;


procedure TTrDuplicateDetector.Process(
  const ADocument : TTrDocument);
begin
  inherited;

  // Add returns false if key was already in list.
  if not Bloom.Add(ADocument.SimpleFingerprint(FFingerprintSize))
  then ADocument.Valid := false;
end;


class function TTrDuplicateDetector.Achieves : TTrPrerequisites;
begin
  Result := [];
end;


class function TTrDuplicateDetector.Presupposes : TTrPrerequisites;
begin
  Result := [];
end;


{ *** Procedural *** }


procedure TrInitDuplicateDetector(const AErrorRate : Real);
begin
  Bloom := TTrScalingBloomFilter.Create(AErrorRate);
end;


procedure TrFreeDuplicateDetector;
begin
  FreeAndNil(Bloom);
end;


finalization

  TrFreeDuplicateDetector;


end.
