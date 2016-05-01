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


// Purely procedural helpers/utilities.


unit TrUtilities;


{$MODE OBJFPC}
{$INLINE ON}
{$H+}
{$M+}



interface


uses
  UriParser,
  StrUtils,
  SysUtils,
  Classes,
  DateUtils,
  RttiUtils,
  IniFiles,
  IcuWrappers;


type

  ETrUtilities = class(Exception);
  ETrAssertion = class(Exception);

  TStringArray = array of String;
  TQWordArray = array of QWord;

  TTrLinkRelation = (
    trlMalformedUri,       // Cannot be determined due to malformed URI.
    trlDifferentHosts,     // Completely different hosts.
    trlSameFullHost,       // Same virtual host or no virtual host.
    trlSameNonVirtualHost  // Same host (last two segments identical).
  );

  TUtf8Byte = (
    tubOne,            // A single-byte.
    tubTwo,            // First byte of double-byte.
    tubThree,          // First byte of triple-byte.
    tubFour,           // First byte of four-byte.
    tubNext,           // Second to fourth of multi-byte.
    tubInvalid         // Invalid Utf-8 byte.
  );

  TTrWriteProc = function(const ALine : String) :
    Integer of object;

  TTrDbgMsg = (
    tdbError,
    tdbWarning,
    tdbInfo
  );

const
  TrDbgMsgStr : array[tdbError..tdbInfo] of String = (
    'Error',
    'Warning',
    'Info'
  );

  TrLinkRelationStr : array[trlMalformedUri..trlSameNonVirtualHost]
    of String = (
    'trlMalformedUri',
    'trlDifferentHosts',
    'trlSameFullHost',
    'trlSameNonVirtualHost'
  );


// Switch debug messages on or off.
procedure TrSetDebug(AOn : Boolean = true);
function TrGetDebug : Boolean;

function TrEpoch : Integer;

// This just emits a debug message on stderr.
procedure TrDebug(const AMessage : String;
  AExcep : Exception = nil; AType : TTrDbgMsg = tdbError);

procedure TrAssert(const ACondition : Boolean;
  const AMessage : String);

// Use RTTI to fetch published (=configurable) properties. If ASectionName
// is not passed, APersistent.ClassName will be used to locate the section.
procedure TrReadProps(const APersitent : TPersistent;
  const AIni : TIniFile; var ASectionName : String); overload;
procedure TrReadProps(const APersitent : TPersistent;
  const AIni : TIniFile); overload;

// Explodes a string into an array at certain split chars.
function TrExplode(const AString : String;
  ADelimiters : TSysCharset; AAllowEmpty : Boolean = false) :
  TStringArray;

// Extract the host part from a URL.
function TrExtractHost(const AUrl : String) : String;

// Extract the last segment (TLD) from a host name.
function TrExtractTld(const AHost : String) : String;

// This checks whether two URIs are to the same host.
// Passes an exception on malformed URIs.
function TrSameHost(const AUrl1 : String; AUrl2 : String) : Boolean;

// This is a more refined version of TrSameHost, returning a more exact
// link relation (cf. above). Relative URLs in AUrl2 are expanded
// to a full URL.
function TrLinkRelation(const AUrl1 : String; var AUrl2 : String) :
  TTrLinkRelation;

function TrLinkRelationToString(const ALinkRelation : TTrLinkRelation) :
  String;

// Calculating unique integers from IPv4 and back.
function TrAToN(const AIp : String) : Longword;
function TrNToA(AInt : Longword) : String;

// This checks for the magic GZip number at the beginning of a file.
function TrFileIsGzip(AFileName : String) : Boolean;

// Nicely formatted Bytes as string (in highest non-zero order).
function TrBytePrint(const Bytes : QWord) : String;

// Returns the strings 'true' and 'false' for a given boolean.
function TrBoolToStr(ABool : Boolean) : String;

// A wrapper to create an array from a text file.
procedure TrLoadLinesFromFile(const AFile : String;
  out AnArray : TStringArray);

// A wrapper to save a text file from an array.
procedure TrSaveLinesToFile(const AFile : String;
  const AnArray : TStringArray);

// Searches a file within defined texrex paths and returns it as
// openable, or result is false.
function TrFindFile(var AFile : String) : Boolean;

// Build a list of path names from a file name mask.
procedure TrBuildFileList(const AFileMask : String; out AFileList :
  TStringList);

// This is a helper proc for output of reports. it breaks the second
// string to align nicely with the report format.
procedure TrFormatReportLongString(const AName : String;
  const AContent : String; AProc : TTrWriteProc);

function TrIsNotSpace(const AUtf8Char : String) : Boolean; inline;
function TrUtf8CodepointEncode(ACodepoint : Integer) : String; inline;
function TrUtf8Codepoint(AUtf8Sequence : String) : Integer; inline;
function TrUtf8ByteType(const AChar : Char) : TUtf8Byte; inline;

// Leniently estimates the codepoint length of an UTF-8 string.
function TrUtf8Length(AString : Utf8String) : Integer;

// Checks whether a string is valid UTF-8, returns 0 for OK, or > 1
// for the index in the string where the condition occured.
function TrUtf8Check(AString : Utf8String) : Integer;

// Wrapper for INI reading.
function TrIniToInteger(const AIni : TIniFile;
  const ASection : String; const AIdentifier : String;
  const ADefault : Integer) : Integer;

function TrIniToReal(const AIni : TIniFile;
  const ASection : String; const AIdentifier : String;
  const ADefault : Real) : Real;

function TrIniToBoolean(const AIni : TIniFile;
  const ASection : String; const AIdentifier : String;
  const ADefault : Boolean) : Boolean;

// Replaces XML reserved characters in String by entities.
function TrXmlEncode(const AInput : String) : String;

// Says true if any of the reserved XML chars appears in input.
function TrXmlFilter(const AInput : String) : Boolean;

function TrPad(const ANumber : Integer; const AString : String) :
  String;

function TrBadnessToBdc(ABadness : Real) : Char; inline;

function TrBoilerToBpc(ABoiler : Real) : Char; inline;

procedure TrSecret(var ASecret : String);


implementation


var
  Texrexdata : String;
  DebugMsgs : Boolean = true;


procedure TrSetDebug(AOn : Boolean);
begin
  DebugMsgs := AOn;
end;

function TrGetDebug : Boolean;
begin
  Result := DebugMsgs;
end;


procedure TrDebug(const AMessage : String;
  AExcep : Exception = nil; AType : TTrDbgMsg = tdbError);
begin
  if not DebugMsgs
  then Exit;

  Writeln(stderr);
  Writeln(stderr, #13, DateTimeToStr(Now), ' ['+ TrDbgMsgStr[AType]
    +']');

  // Report what the caller had to say.
//  Writeln(stderr, #13'Thread: ', GetThreadId);
  Writeln(stderr, #13, AMessage);

  // If exception, report it.
  if Assigned(AExcep)
  then with AExcep
  do begin
    Writeln(stderr, #13, 'Exception: ', ClassName, '(', UnitName, ')');
    Writeln(stderr, #13, 'Message: ', Message);
  end;
  Writeln(stderr, #13);
end;


function TrEpoch : Integer;
begin
  Result := DateTimeToUnix(Now);
end;


procedure TrAssert(const ACondition : Boolean;
  const AMessage : String);
begin
  if not ACondition
  then raise ETrAssertion.Create('Assertion failed: ' + AMessage);
end;


procedure TrReadProps(const APersitent : TPersistent;
  const AIni : TIniFile; var ASectionName : String);
var
  LProps : TPropsStorage = nil;
  LPropStrings : TStringList = nil;
  LSections : TStringList = nil;
begin
  if not Assigned(AIni)
  then raise ETrUtilities.Create('Ini not assigned.');

  if not Assigned(APersitent)
  then raise ETrUtilities.Create(
    'Object for property loading not assigned.');

  // Find out whether a section for this class exists.
  // If not, just exit.
  LSections := TStringList.Create;
  AIni.ReadSections(LSections);

  if (not Assigned(LSections))
  or (LSections.IndexOf(ASectionName) = -1)
  then begin
    FreeAndNil(LSections);
    Exit;
  end;
  FreeAndNil(LSections);

  // Read the property names from section.
  LPropStrings := TStringList.Create;
  AIni.ReadSection(ASectionName, LPropStrings);

  // Only try to "stream" if section exists.
  if (LPropStrings.Count < 1)
  then Exit;

  // Actually do the storage loading.
  LProps := TPropsStorage.Create;
  if not Assigned(LProps)
  then raise ETrUtilities.Create('Could not create property reader.');

  // Properties will be read from the INI file.
  with LProps
  do begin
    OnReadString := @AIni.ReadString;
    AObject := APersitent;
    Prefix := '';
    Section := ASectionName;
  end;

  // If we're here, we can go.
  LProps.LoadProperties(LPropStrings);

  FreeAndNil(LProps);
  FreeAndNil(LPropStrings);
end;


procedure TrReadProps(const APersitent : TPersistent;
  const AIni : TIniFile);
var
  LSectionName : String;
begin

  // This is a wrapper. If there is no specific section name given, then we
  // us APersitent.ClassName.
  LSectionName := APersitent.ClassName;
  TrReadProps(APersitent, AIni, LSectionName);
end;



function TrExplode(const AString : String;
  ADelimiters : TSysCharset; AAllowEmpty : Boolean = false) :
  TStringArray;
var
  i : Integer = 1;
  LCount : Integer;
begin

  // Both approaches are separated. First, WITH empty fields.
  if AAllowEmpty
  then begin

    // Get the number of substrings first. No idea how to do it better.
    // One string is always there, even if empty.
    LCount := 1;
    for i := 1 to Length(AString)
    do if AString[i] in ADelimiters
      then Inc(LCount);

    // Now, extract the strings.
    SetLength(Result, LCount);
    for i := 1 to LCount
    do Result[i-1] := ExtractDelimited(i, AString, ADelimiters);
  end

  // NO empty fields allowed.
  else begin

    LCount := WordCount(AString, ADelimiters);
    SetLength(Result, LCount);

    // We take the strings from the left until nothing is left.
    for i := 1 to LCount
    do Result[i-1] := ExtractWord(i, AString, ADelimiters);
  end;

end;


function TrExtractHost(const AUrl : String) : String;
var
  LUri : TUri;
begin
  LUri := ParseUri(AUrl);
  Result := LUri.Host;
end;


function TrExtractTld(const AHost : String) : String;
begin
  Result := AnsiRightStr(AHost, Length(AHost) - RPos('.', AHost) );
end;


function TrSameHost(const AUrl1 : String; AUrl2 : String) : Boolean;
var
  LUri1, LUri2 : TUri;
begin
  LUri1 := ParseUri(AUrl1);
  LUri2 := ParseUri(AUrl2);
  if (AnsiLowerCase(LUri1.Host) = AnsiLowerCase(LUri2.Host))
  then Result := true
  else Result := false;
end;


function TrLinkRelation(const AUrl1 : String; var AUrl2 : String) :
  TTrLinkRelation;
const
  LDelimiters : TSysCharset = ['.'];
var
  LUri : String;
  LUri1, LUri2 : TUri;
  HostSegments1, HostSegments2 : TStringArray;
begin

  // First, check whether AUrl2 is relative and, if so, expand.
  if not IsAbsoluteUri(AUrl2)
  then try
    ResolveRelativeUri(AUrl1, AUrl2, LUri);
    AUrl2 := LUri;
  except
    Result := trlMalformedUri;
    Exit;
  end;

  // ParseUri chokes on some malformed URIs, so we protect it.
  try
    LUri1 := ParseUri(AUrl1);
    LUri2 := ParseUri(AUrl2);
  except
    Result := trlMalformedUri;
    Exit;
  end;

  // The host as returned might include virtual host prefixes.
  if (AnsiLowerCase(LUri1.Host) = AnsiLowerCase(LUri2.Host))
  then Result := trlSameFullHost
  else begin

    HostSegments1 := TrExplode(LUri1.Host, LDelimiters);
    HostSegments2 := TrExplode(LUri2.Host, LDelimiters);

    if (Length(HostSegments1) >= 2)
    and (Length(HostSegments2) >= 2)
    then begin

      if (HostSegments1[High(HostSegments1)] =
        HostSegments2[High(HostSegments2)])
      and (HostSegments1[High(HostSegments1)-1] =
        HostSegments2[High(HostSegments2)-1])
      then Result := trlSameNonVirtualHost
      else Result := trlDifferentHosts;

    end
    else Result := trlDifferentHosts;
  end;
end;


function TrLinkRelationToString(const ALinkRelation : TTrLinkRelation) :
  String;
begin
  Result := TrLinkRelationStr[ALinkRelation];
end;


function TrAToN(const AIp : String) : Longword;
var
  LComponents : TStringArray;
begin
  LComponents := TrExplode(AIp, ['.']);

  // Only accept 4 segments of correct length.
  if (Length(LComponents) <> 4)
  or (Length(LComponents[0]) > 3)
  or (Length(LComponents[1]) > 3)
  or (Length(LComponents[2]) > 3)
  or (Length(LComponents[3]) > 3)
  then begin
    Result := 0;
    Exit;
  end;

  try
    Result :=
      Byte(StrToInt(LComponents[0])) shl 24 +
      Byte(StrToInt(LComponents[1])) shl 16 +
      Byte(StrToInt(LComponents[2])) shl 8 +
      Byte(StrToInt(LComponents[3]));
  except
    Result := 0;
  end;
end;


function TrNToA(AInt : Longword) : String;
begin
  Result :=
    IntToStr((AInt and 4278190080) shr 24) + '.' +
    IntToStr((AInt and 16711680) shr 16) + '.' +
    IntToStr((AInt and 65280) shr 8) + '.' +
    IntToStr(AInt and 255);
end;


function TrFileIsGzip(AFileName : String) : Boolean;
var
  LFile : File;
  LBuffer : array[0..1] of Byte;
const
  LFirst : Byte = $1f;
  LSecond : Byte = $8b;
begin
  Result := false;

  // Only handle existing files.
  if (not FileExists(AFileName))
  then Exit;

  // Open file.
  Assign(LFile, AFileName);
  Reset(LFile, 1);

  // Check size.
  if (FileSize(LFile) < 2)
  then begin
    Close(LFile);
    Exit;
  end;

  // Read two bytes and check for 0x1f and 0x8b.
  Blockread(LFile, LBuffer, 2);

  if  (NtoLE(LBuffer[0]) = LFirst)
  and (NtoLE(LBuffer[1]) = LSecond)
  then Result := true;
end;


procedure TrFormatReportLongString(const AName : String;
  const AContent : String; AProc : TTrWriteProc);
var
  i : Integer;
begin
  if not Assigned(AProc)
  then Exit;

  if Length(AContent) < 41
  then AProc(Format('%0:27S : %1:-42S', [AName, '''' + AContent +
    '''']))
  else begin
    AProc(Format('%0:27S : %1:-42S', [AName, '''' +
      Copy(AContent, 1, 39) + '''+']));
    for i := 1 to Length(AContent) div 39
    do begin
      if (i < Length(AContent) div 39)
      then AProc(Format('%0:27S   %1:-42S', ['',
      '''' + Copy(AContent, i*399+1, 39) + '''+' ]))
       else AProc(Format('%0:27S   %1:-42S', ['',
      '''' + Copy(AContent, i*39+1, 39) + '''']));
    end;
  end;
end;



procedure TrLoadLinesFromFile(const AFile : String;
  out AnArray : TStringArray);
var
  LFile : Text;
  LLine : String = '';
begin
  SetLength(AnArray, 0);

  if not(FileExists(AFile))
  then Exit;

  {$I-}
  Assign(LFile, AFile);
  Reset (LFile);
  if (IoResult = 0)
  and (AFile <> '')
  then begin
    while not Eof(LFile)
    do begin
      ReadLn(LFile, LLine);
      if not ( (IoResult <> 0)
      or (LLine = '') )
      then begin
        SetLength(AnArray, Length(AnArray)+1);
        AnArray[High(AnArray)] := LLine;
      end;
    end;
  end;
  {$I+}
  Close(LFile);
end;


procedure TrSaveLinesToFile(const AFile : String;
  const AnArray : TStringArray);
var
  LFile : Text;
  i : Integer = 0;
begin
  {$I-}
  Assign(LFile, AFile);
  Rewrite(LFile);
  if (IoResult = 0)
  and (AFile <> '')
  then begin
    for i := 0 to High(AnArray)
    do begin
      Writeln(LFile, AnArray[i]);
    end;
  end;
  {$I+}
  Close(LFile);
end;


function TrBytePrint(const Bytes : QWord) : String; inline;
begin
  if Bytes < 1025
  then Result := IntToStr(Bytes) + ' B'
  else if Bytes < 1048577
  then Result := FloatToStrF(Bytes/1024, ffFixed, 2, 2) + ' KB'
  else if Bytes < 1073741825
  then Result := FloatToStrF(Bytes/1048576, ffFixed, 2, 2) + ' MB'
  else if Bytes < 1099511627777
  then Result := FloatToStrF(Bytes/1073741824, ffFixed, 2, 2) + ' GB'
  else Result := FloatToStrF(Bytes/1099511627776, ffFixed, 2, 2) +
    ' TB';
end;


function TrBoolToStr(ABool : Boolean) : String;
begin
  if ABool
  then Result := 'true'
  else Result := 'false';
end;


function TrFindFile(var AFile : String) : Boolean;
begin
  if FileExists(AFile)
  then Result := true
  else begin
    if  (Texrexdata <> '')
    and FileExists(Texrexdata + ExtractFileName(AFile))
    then begin
      AFile := Texrexdata + ExtractFileName(AFile);
      Result := true;
    end else Result := false;
  end;
end;


procedure TrBuildFileList(const AFileMask : String; out AFileList :
  TStringList);
var
  Info : TSearchRec;
begin
  AFileList := TStringList.Create;

  if FindFirst(AFileMask, faAnyFile, Info) = 0
  then AFileList.Add(Info.Name);

  while (FindNext(Info) = 0)
  do AFileList.Add(Info.Name);

  FindClose(Info);
end;


function TrIsNotSpace(const AUtf8Char : String) : Boolean; inline;
begin
  if  (AUtf8Char <> #32)       // SP
  and (AUtf8Char <> #194#160)  // NBSP
  and (AUtf8Char <> #9)        // TAB
  and (AUtf8Char <> #10)       // LF
  and (AUtf8Char <> #13)       // CR
  then Result :=true
  else Result := false;
end;


function TrUtf8CodepointEncode(ACodepoint : Integer) : String; inline;
var
  LCodepoint : Integer;
begin
  LCodepoint := NToLE(ACodepoint);
  if (LCodepoint < $80)                         // Single-byte.
  then Result :=
    Char(LCodepoint shr 0 and $7F or $00)
  else if LCodepoint < $0800                   // Double-byte.
  then Result :=
    Char(LCodepoint shr 6 and $1F or $C0) +
    Char(LCodepoint shr 0 and $3F or $80)
  else if LCodepoint < $010000                 // Triple-byte
  then Result :=
    Char(LCodepoint shr 12 and $0F or $E0) +
    Char(LCodepoint shr 6 and $3F or $80) +
    Char(LCodepoint shr 0 and $3F or $80)
  else if LCodepoint < $110000                 // Quadruple-byte.
  then Result :=
    Char(LCodepoint shr 18 and $07 or $F0) +
    Char(LCodepoint shr 12 and $3F or $80) +
    Char(LCodepoint shr 6 and $3F or $80) +
    Char(LCodepoint shr 0 and $3F or $80);
end;


function TrUtf8Codepoint(AUtf8Sequence : String) : Integer; inline;
begin
  Result := 0;
  if AUtf8Sequence = ''
  then Exit;

  case Length(AUtf8Sequence) of
    1 : Result := NToLE(Integer(AUtf8Sequence[1]));
    2 : Result := NToLE(Integer(AUtf8Sequence[1]) and $1F shl 6)
               or NToLE(Integer(AUtf8Sequence[2]) and $3F);
    3 : Result := NToLE(Integer(AUtf8Sequence[1]) and $0F shl 12)
               or NToLE(Integer(AUtf8Sequence[2]) and $3F shl 6)
               or NToLE(Integer(AUtf8Sequence[3]) and $3F);
    4 : Result := NToLE(Integer(AUtf8Sequence[1]) and $07 shl 18)
               or NToLE(Integer(AUtf8Sequence[2]) and $3F shl 12)
               or NToLE(Integer(AUtf8Sequence[3]) and $3F shl 6)
               or NToLE(Integer(AUtf8Sequence[4]) and $3F);
    else Result := (-1);
  end;
  Result := LEToN(Result);
end;


function TrUtf8ByteType(const AChar : Char) : TUtf8Byte; inline;
var
  LChar : Byte;
begin
  // Fix big-endian bytes.
  LChar := Byte(NtoLE(Word(AChar)));

  if Byte(LChar) <= $7F
  then Result := tubOne

  else
  if (Byte(LChar) >= $C0)
  and (Byte(LChar) <= $DF)
  then Result := tubTwo

  else
  if (Byte(LChar) >= $E0)
  and (Byte(LChar) <= $EF)
  then Result := tubThree

  else
  if (Byte(LChar) >= $F0)
  and (Byte(LChar) <= $F7)
  then Result := tubFour

  else
  if (Byte(LChar) >= $80)
  and (Byte(LChar) <= $BF)
  then Result := tubNext

  else Result := tubInvalid;
end;


function TrUtf8Length(AString : Utf8String) : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 1 to Length(AString)-1
  do
  if  (TrUtf8ByteType(AString[i]) <> tubNext)
  and (TrUtf8ByteType(AString[i]) <> tubInvalid)
  then Inc(Result);
end;


function TrUtf8Check(AString : Utf8String) : Integer;
var
  i : Integer;
begin
  Result := 0;
  i := 1;
  while i <= Length(AString)
  do begin
    case TrUtf8ByteType(AString[i])
    of

      // An invalid byte always leads to error.
      tubInvalid : begin
        Result := i;
        Exit;
      end;

      // All the multi-byte starters consume their following bytes.
      // So, a single byte is always good.
      tubOne : ;

      tubTwo : begin
        if (i >= Length(AString))
        or (TrUtf8ByteType(AString[i+1]) <> tubNext)
        then begin
          Result := i;
          Exit;
        end else Inc(i);
      end;

      tubThree : begin
        if (i >= Length(AString)-1)
        or (TrUtf8ByteType(AString[i+1]) <> tubNext)
        or (TrUtf8ByteType(AString[i+2]) <> tubNext)
        then begin
          Result := i;
          Exit;
        end else Inc(i, 2);
      end;

      // This includes the codepoint >= U+10FFFF check.
      tubFour : begin
        if (i >= Length(AString)-2)
        or (TrUtf8ByteType(AString[i+1]) <> tubNext)
        or (TrUtf8ByteType(AString[i+2]) <> tubNext)
        or (TrUtf8ByteType(AString[i+3]) <> tubNext)
        or (TrUtf8Codepoint(AnsiMidStr(AString, i, 4)) > $10ffff)
        then begin
          Result := i;
          Exit;
        end else Inc(i, 3);
      end;

      // Since all multi-by starters consume their follow bytes, we are
      // always incorrect if we end up here directly.
      tubNext : begin
          Result := i;
          Exit;
      end;

    end;

    // This is a while-loop! We have to manually increment.
    Inc(i);
  end;
end;



function TrIniToInteger(const AIni : TIniFile;
  const ASection : String; const AIdentifier : String;
  const ADefault : Integer) : Integer;
begin
  if not Assigned(AIni)
  then Result := ADefault
  else Result := StrToIntDef(AIni.ReadString(ASection, AIdentifier,
    IntToStr(ADefault)), ADefault);
end;


function TrIniToReal(const AIni : TIniFile;
  const ASection : String; const AIdentifier : String;
  const ADefault : Real) : Real;
begin
  if not Assigned(AIni)
  then Result := ADefault
  else Result := StrToFloatDef(AIni.ReadString(ASection, AIdentifier,
    FloatToStr(ADefault)), ADefault);
end;


function TrIniToBoolean(const AIni : TIniFile;
  const ASection : String; const AIdentifier : String;
  const ADefault : Boolean) : Boolean;
var
  LRead : String;
begin
  if not Assigned(AIni)
  then Result := ADefault
  else begin
    LRead := AIni.ReadString(ASection, AIdentifier, '');
    case LRead
    of
      'true'  : Result := true;
      'false' : Result := false;
      else     Result := ADefault;
    end;
  end;
end;


function TrXmlEncode(const AInput : String) : String;
begin
  Result := AInput;
  if Result = ''
  then Exit;

  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;


function TrXmlFilter(const AInput : String) : Boolean;
begin
  Result := AnsiContainsStr(AInput, '&')
   or AnsiContainsStr(AInput, '"')
   or AnsiContainsStr(AInput, '''')
   or AnsiContainsStr(AInput, '<')
   or AnsiContainsStr(AInput, '>');
end;


function TrPad(const ANumber : Integer; const AString : String) :
  String;
begin
  if Length(AString) < ANumber
  then begin
    SetLength(Result, ANumber - Length(AString));
    FillChar(Result[1], ANumber - Length(AString), '0');
    Result := Result + AString;
  end else Result := AString;
end;


// This just inits the common file directory.
procedure TrFindDataPath;
begin
  Texrexdata := GetEnvironmentVariable('TEXREXDATA');
  if (Texrexdata <> '')
  and DirectoryExists(Texrexdata)
  then begin
    {$IFDEF WINDOWS}
      if RightStr(Texrexdata, 1) <> '\'
      then Texrexdata += '\';
    {$ELSE}
      if RightStr(Texrexdata, 1) <> '/'
      then Texrexdata += '/';
    {$ENDIF}
  end
  else Texrexdata := '';
end;


function TrBadnessToBdc(ABadness : Real) : Char; inline;
begin
  Result := Char(Round(ABadness / 2) + 97);
end;


function TrBoilerToBpc(ABoiler : Real) : Char; inline;
begin
  if (ABoiler <= 0)
  then Result := Char(97)
  else Result := Char(Round(ABoiler * 10) + 97);
end;


procedure TrSecret(var ASecret : String);
var
  i : Integer;
begin
  for i := 1 to Length(ASecret)
  do begin

    // This works only for valid ASCII letter input, i.e. < 97 implies >= 65.
    if (Byte(ASecret[i]) >= 97)
    then ASecret[i] := Char( ((( Byte(ASecret[i]) - 97)+13) mod 26)+97 )
    else ASecret[i] := Char( ((( Byte(ASecret[i]) - 65)+13) mod 26)+65 );
  end;
end;


initialization

  TrFindDataPath;

end.
