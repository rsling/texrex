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


unit TrGeolocator;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  Classes,
  StrUtils,
  IniFiles,
  Contnrs,
  TrData,
  TrUtilities,
  TrDocumentProcessor;


type

  ETrGeolocator = class(Exception);

  TTrBlock = packed record
    Lower : Longword;
    Upper : Longword;
    LocId : Integer;
  end;
  PTrBlock = ^TTrBlock;

  TTrLocation = packed record
    Country : String;
    Region : String;
    City : String;
  end;
  TTrLocationArray = array of TTrLocation;


  // This is an abstract class that takes a TTrDocument and
  // processes it. All strippers, cleaners etc. inherit from this.
  TTrGeolocator = class(TTrDocumentProcessor)
  public
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FAddCountry : Boolean;
    FAddRegion : Boolean;
    FAddCity : Boolean;
  published
    property AddCountry : Boolean read FAddCountry write FAddCountry
      default true;
    property AddRegion : Boolean read FAddRegion write FAddRegion
      default false;
    property AddCity : Boolean read FAddCity write FAddCity
      default false;
  end;


// This function must be called before any thread/function tries to use
// the geolocator.
procedure TrInitGeodata(var ABlocksFile : String;
  var ALocationsFile : String);


// Will be called anyway on finalization.
procedure TrFreeGeoData;


implementation


var
  Blocks : TFPList = nil;
  Locations : TTrLocationArray;



{ *** TTrGeolocator *** }



procedure TTrGeolocator.Process(const ADocument : TTrDocument);
var
  LIpInt : LongWord;
  LLow, LHigh, LMid : Integer;
  LLocIdx : Integer;
begin
  inherited Process(ADocument);

  // If nothing was returned (= IP unknown), then don't do anything.
  if ADocument.Ip = ''
  then Exit;

  LIpInt := TrAToN(ADocument.Ip);

  // Now do a binary search.
  LLow := 0;
  LHigh := Blocks.Count-1;
  while true
  do begin

    // Find new middle.
    LMid := LLow + ((LHigh-LLow) div 2);

    // Set new interval (either high or low boundary) to middle.
    if LIpInt >=  PTrBlock(Blocks[LMid])^.Lower
    then LLow := LMid
    else LHigh := LMid;

    // If distance between low and high has vanished, we're there!
    if (LHigh-LLow < 2)
    then begin

      // Check range. Sometimes, blocks are not adjacent.
      if  (LIpInt <= PTrBlock(Blocks[LLow])^.Upper)
      and (LIpInt >= PTrBlock(Blocks[LLow])^.Lower)
      then begin

        LLocIdx := PTrBlock(Blocks[LLow])^.LocId;

        if FAddCountry
        then ADocument.AddMeta('country',
          Locations[LLocIdx].Country);

        if FAddRegion
        then ADocument.AddMeta('region',
          Locations[LLocIdx].Region);

        if FAddCity
        then ADocument.AddMeta('city',
          Locations[LLocIdx].City);
      end;

      // We're done. Exit the binary search.
      Break;
    end;
  end;

end;


class function TTrGeolocator.Achieves : TTrPrerequisites;
begin
  Result := [];
end;


class function TTrGeolocator.Presupposes : TTrPrerequisites;
begin
  Result := [];
end;


{ *** Procedural *** }


procedure TrInitGeodata(var ABlocksFile : String;
  var ALocationsFile : String);
var
  LStringsBlocks : TStringList;
  LStringsLocations : TStringList;

  i : Integer;

  LLocId : Integer;
  LFields : TStringArray;
  LLower : Longword;
  LUpper : Longword;

  LPtr : PTrBlock;

begin

  // Now read the database.
  if not TrFindFile(ABlocksFile)
  then raise ETrGeolocator.Create('Blocks file must exist.');

  if not TrFindFile(ALocationsFile)
  then raise ETrGeolocator.Create('Locations file must exist.');

  // Try to read the info from the original GeoLite files.
  LStringsBlocks := TStringList.Create;
  LStringsBlocks.LoadFromFile(ABlocksFile);
  LStringsLocations := TStringList.Create;
  LStringsLocations.LoadFromFile(ALocationsFile);

  // Find the highest required block id. Note: The CSV is SORTED!
  LFields := TrExplode(LStringsLocations[LStringsLocations.Count-1],
    [',']);
  LLocId := StrToInt(LFields[0]);
  SetLength(Locations, LLocId+1);

  // Read location database. Skip first two lines (header).
  for i := 2 to LStringsLocations.Count-1
  do begin

    LFields := TrExplode(LStringsLocations[i], [','], true);

    if Length(LFields) <> 9
    then Continue;

    if (not TryStrToInt(LFields[0], LLocId))
    then Continue;

    if LLocId > High(Locations)
    then Continue;

    with Locations[LLocId]
    do begin

      if Length(LFields[1]) > 2
      then Country := AnsiMidStr(LFields[1], 2, Length(LFields[1])-2)
      else Country := 'unknown';

      if Length(LFields[2]) > 2
      then Region := AnsiMidStr(LFields[2], 2, Length(LFields[2])-2)
      else Region := 'unknown';

      if Length(LFields[3]) > 2
      then City := AnsiMidStr(LFields[3], 2, Length(LFields[3])-2)
      else City := 'unknown';

    end;

  end;
  FreeAndNil(LStringsLocations);

  Blocks := TFPList.Create;

  // Read all lines with block info and create record. Skip first two.
  for i := 2 to LStringsBlocks.Count-1
  do begin

    LFields := TrExplode(LStringsBlocks[i], [','], true);

    // Catch entried with other than 4 fields.
    if (Length(LFields) <> 3)
    then Continue;

    // Catch incorrect number in geoinfo.
    try
      LLower := StrToInt(AnsiMidStr(LFields[0], 2,
        Length(LFields[0])-2));
    except
      Continue;
    end;

    try
      LUpper := StrToInt(AnsiMidStr(LFields[1], 2,
        Length(LFields[1])-2));
    except
      Continue;
    end;

    try
      LLocId := StrToInt(AnsiMidStr(LFields[2], 2,
        Length(LFields[2])-2));
    except
      Continue;
    end;

    // We can add a data row.
    New(LPtr);
    with LPTr^
    do begin
      Lower := LLower;
      Upper := LUpper;
      LocId := LLocId;
    end;
    Blocks.Add(LPtr);
  end;
  FreeAndNil(LStringsBlocks);

end;


procedure TrFreeGeoData;
var
  i : Integer;
begin
  if Assigned(Blocks)
  then begin
    for i := 0 to Blocks.Count-1
    do if Assigned(Blocks[i])
    then begin
      Dispose(PTrBlock(Blocks[i]));
      Blocks[i] := nil;
    end;
    FreeAndNil(Blocks);
  end;
  SetLength(Locations,0);
end;


finalization

  // Make sure the database is freed.
  TrFreeGeoData;


end.
