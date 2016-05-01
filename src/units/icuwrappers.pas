{
  This file is part of texrex.
  Maintained by Roland Schäfer.
  http://texrex.sourceforge.net/

  See the file COPYING.LGPL, included in this distribution, for
  details about the copyright.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

// TIcu~ objects are not thread-safe! Each thread should have its own.

unit IcuWrappers;

{$MODE OBJFPC}
{$H+}

interface

uses
  CMem,
  SysUtils,
  Contnrs,
  CTypes,
  Math,
  IcuTypes,
  IcuDet,
  IcuConv,
  IcuRegex,
  IcuNorm;


const
  IcuDetectionBufferSize = Integer(8192);

type
  EIcuDetectException = class(Exception);
  EIcuConvertException = class(Exception);
  EIcuRegexException = class(Exception);
  EIcuNormException = class(Exception);

// Matching flags, constants from C enum.
type
  URegexpFlag = CInt32;
const
  UREGEX_CANON_EQ                 : URegexpFlag = 128;
  UREGEX_CASE_INSENSITIVE         : URegexpFlag = 2;
  UREGEX_COMMENTS                 : URegexpFlag = 4;
  UREGEX_DOTALL                   : URegexpFlag = 32;
  UREGEX_LITERAL                  : URegexpFlag = 16;
  UREGEX_MULTILINE                : URegexpFlag = 8;
  UREGEX_UNIX_LINES               : URegexpFlag = 1;
  UREGEX_UWORD                    : URegexpFlag = 256;
  UREGEX_ERROR_ON_UNKNOWN_ESCAPES : URegexpFlag = 512;


{ *** Convenience functions. *** }

// Icu ustring.h with pre-flighting.
function Utf8ToUtf16Icu(const AInput : Utf8String;
  ALenient : Boolean = false) : UnicodeString;
function Utf16ToUtf8Icu(const AInput : UnicodeString) : Utf8String;

function Utf16UpCaseIcu(const AInput : UnicodeString) : UnicodeString;
function Utf8UpCaseIcu(const AInput : Utf8String) : Utf8String;



{ *** Charset Detection *** }


type
  TIcuDetectionResult = packed record
    Charset : String;
    Confidence: Integer;
  end;
  TIcuDetectionResults = array of TIcuDetectionResult;


type
  TIcuDetector = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;
    function TestCharset(const ACharset : String) : Boolean;
    function DetectCharset(const ABuffer : String;
      const AMaxCompare : Integer) : String;
    procedure DetectCharsets(const ABuffer : String;
      out Results : TIcuDetectionResults; const AMaxCompare : Integer);
  protected
    FCsd : PUCharsetDetector;
    procedure OpenDetector;
    procedure PrepareBuffer(const ABuffer : String;
      const AMaxCompare : Integer);
  end;


  TIcuConverterItem = record
    Charset : String;
    Converter : PUConverter;
  end;
  TIcuConverterItems = array of TIcuConverterItem;


  TIcuConverter = class(TObject)
  public
    constructor Create(APivotBufferSize : Integer = 8192);
    destructor Destroy; override;
    function MaximalToBufferSizeForConversion(
      const AFromCharset : String; const AToCharset : String;
      const AFromBufferSize : Integer) : Integer;
    function MaximalToBufferSizeForConversion(
      const AFromConverter : PUConverter;
      const AToConverter : PUConverter;
      const AFromBufferSize : Integer) : Integer;

    // Single-byte conversions.
    function ConvertFromTo(const AFromBuffer : String;
      const AFromCharset : String; const AToCharset : String) :
      String;

  protected
    FConverters : TIcuConverterItems;
    function RetrieveConverter(const ACharset : String) : PUConverter;
  end;


  TIcuUtf8Normalizer = class(TObject)
  public
    constructor Create;
    function Normalize(const AInput : Utf8String) : Utf8String;
  protected
    FNormalizer : PUNormalizer2;
  end;


{ *** Regular Expressions *** }


  TIcuRegex = class
  public
    constructor Create(const ARegex : Utf8String;
      AIcuFlags : URegexpFlag = 0);
    destructor Destroy; override;

    // Match ASubject; pattern need not need describe string exhaustively.
    function Match(const ASubject : Utf8String;
      AFull : Boolean = false; ALenient : Boolean = false) : Boolean;

    // Count how often the string matches the pattern.
    function MatchCount(const ASubject : Utf8String;
      ALenient : Boolean = false) : Integer;

    // Replace the first occurence of AReplacement in ASubject,
    // with $ replacements.
    function Replace(const ASubject : Utf8String;
      const AReplacement : Utf8String; AAll : Boolean = false;
      ALenient : Boolean = false) : Utf8String;
  protected
    FRegex : PURegularExpression;     // The compiled regex.
  end;



implementation


{ *** Normalization *** }


constructor TIcuUtf8Normalizer.Create;
var
  Error : UErrorCode = U_ZERO_ERROR;
begin
  FNormalizer := unorm2_getNFCInstance(@Error);
  if not Error = U_ZERO_ERROR
  then raise EIcuNormException.Create(IntToStr(Error));
end;


function TIcuUtf8Normalizer.Normalize(const AInput : Utf8String) : Utf8String;
var
  LInput : UnicodeString;
  LResult : UnicodeString;
  Offset : CInt32;
  Laength : CInt32;
  Error : UErrorCode = U_ZERO_ERROR;
begin

  // Non-lenient conversion because we do not want malformed strings.
  LInput := Utf8ToUtf16Icu(AInput, false);

  // Check if string is already normalized.
  UniqueString(LInput);
  Offset := unorm2_spanQuickCheckYes(FNormalizer, PUChar(LInput),
    Length(LInput), @Error);
  if not Error = U_ZERO_ERROR
  then raise EIcuNormException.Create(IntToStr(Error));

  // Only if there was a normalization boundary in string, normalize the rest.
  if Offset < Length(LInput)
  then begin
    SetLength(LResult, Length(LInput));
    Laength := unorm2_normalize(FNormalizer, PUChar(LInput), Length(LInput),
      PUChar(LResult), Length(LResult), @Error);
    if not Error = U_ZERO_ERROR
    then raise EIcuNormException.Create(IntToStr(Error));
    Result := Utf16ToUtf8Icu(LResult);
   end else Result := AInput;
end;



{ *** Charset Conversion *** }



constructor TIcuConverter.Create(APivotBufferSize : Integer = 8192);
begin
  SetLength(FConverters, 0);
end;


destructor TIcuConverter.Destroy;
var
  i : Integer;
begin
  // Free the converters.
  for i := 0 to High(FConverters)
  do begin
    if FConverters[i].Converter <> nil
    then ucnv_close(PUConverter(FConverters[i].Converter));
  end;
  SetLength(FConverters, 0);
end;


function TIcuConverter.RetrieveConverter(const ACharset : String) :
  PUConverter;
var
  i : Integer = 0;
  LConverter : PUConverter = nil;
  LError : UErrorCode = U_ZERO_ERROR;
begin
  // First, try to find the converter in the list.
  while (i < High(FConverters))
  and (LConverter = nil)
  do begin
    if FConverters[i].Charset = ACharset
    then LConverter := FConverters[i].Converter;
    Inc(i);
  end;

  // If nothing was, found, create and add it.
  if LConverter = nil
  then begin
    LConverter := ucnv_open(PChar(ACharset), @LError);
    // We ignore certain error warnings like U_AMBIGUOUS_ALIAS_WARNING.
    if LConverter <> nil
    then begin
      SetLength(FConverters, Length(FConverters)+1);
      with FConverters[High(FConverters)]
      do begin
        Charset := ACharset;
        Converter := LConverter;
      end;
    end;
  end;

  // If everything went wrong (e.g., in case charset does not exist)
  // nil is returned.
  Result := LConverter;
end;


function TIcuConverter.MaximalToBufferSizeForConversion(
  const AFromConverter : PUConverter; const AToConverter : PUConverter;
  const AFromBufferSize : Integer) : Integer;
var
  LFromMaxCharSize : CInt8 = 0;
  LToMaxCharSize : CInt8 = 0;
  LRatio : Integer;
begin
  if (AFromConverter = nil)
  or (AToConverter = nil)
  then raise EIcuConvertException.Create('A converter was nil.');

  LFromMaxCharSize := ucnv_getMaxCharSize(AFromConverter);
  LToMaxCharSize := ucnv_getMaxCharSize(AToConverter);

  // Protect against div 0 and rounded down 0 results.
  if LFromMaxCharSize > 0
  then LRatio := Ceil(LToMaxCharSize / LFromMaxCharSize)
  else LRatio := 1;

  // Also add a safety margin for BOM etc.
  Result := LRatio * (AFromBufferSize + 5)
end;


function TIcuConverter.MaximalToBufferSizeForConversion(
  const AFromCharset : String; const AToCharset : String;
  const AFromBufferSize : Integer) : Integer;
var
  LFromConverter : PUConverter = nil;
  LToConverter : PUConverter = nil;
begin
  LFromConverter := RetrieveConverter(AFromCharset);
  LToConverter := RetrieveConverter(AToCharset);
  Result := MaximalToBufferSizeForConversion(LFromConverter,
    LToConverter, AFromBufferSize);
end;


function TIcuConverter.ConvertFromTo(const AFromBuffer : String;
  const AFromCharset : String; const AToCharset : String) :
  String;
var
  LFromConverter : PUConverter = nil;
  LToConverter : PUConverter = nil;
  LUnicode : PUChar;
  LUnicodeTrunc : PUChar;
  LUnicodeSize : Integer;
  LUnicodeSizeMax : Integer;
  LTarget : PChar;
  LTargetSize : Integer;
  LTargetSizeMax : Integer;
  LError : UErrorCode = U_ZERO_ERROR;
begin
  Result := '';

  // This check is also to prevent same to same conversion when
  // this is called from versions with charset autodetect. Do not
  // optimize this away!
  if (AFromCharset = AToCharset)
  or (Length(AFromBuffer) < 1)
  then Exit;

  // If converter retrieval fails, raise an exception.
  LFromConverter := RetrieveConverter(AFromCharset);
  if (LFromConverter = nil)
  then raise EIcuConvertException.Create('From-Converter retrieval' +
    ' failed (' + AFromCharset + ').');
  LToConverter := RetrieveConverter(AToCharset);
  if (LToConverter = nil)
  then raise EIcuConvertException.Create('To-Converter retrieval' +
    ' failed (' + AToCharset + ').');

  // Conversion to Unicode.
  LUnicodeSizeMax := 10+(Length(AFromBuffer)*2);
  GetMem(LUnicode, LUnicodeSizeMax);
  LError := U_ZERO_ERROR;

  LUnicodeSize := ucnv_toUChars(
    LFromConverter,
    LUnicode,
    LUnicodeSizeMax,
    @(AFromBuffer[1]),
    Length(AFromBuffer),
    @LError
  );
  LUnicodeTrunc := PUChar(Copy(LUnicode, 0, LUnicodeSize));
  FreeMem(LUnicode, LUnicodeSizeMax);
  ucnv_resetToUnicode(LFromConverter);

  if LUnicodeSize > LUnicodeSizeMax
  then raise EIcuConvertException.Create('A Unicode string did not ' +
    'fit into its buffer.');

  // Converion to UTF8.
  LTargetSizeMax := UCNV_GET_MAX_BYTES_FOR_STRING(LUnicodeSize,
    ucnv_getMaxCharSize(LToConverter));
  GetMem(LTarget, LTargetSizeMax);
  LError := U_ZERO_ERROR;

  LTargetSize := ucnv_fromUChars(
    LToConverter,
    LTarget,
    LTargetSizeMax,
    LUnicodeTrunc,
    LUnicodeSize,
    @LError
  );

  Result := Copy(LTarget, 0, LTargetSize);
  FreeMem(LTarget, LTargetSizeMax);
end;


{ *** Charset Detection *** }


constructor TIcuDetector.Create;
begin
  // Init values.
  FCsd := nil;
end;


destructor TIcuDetector.Destroy;
begin
  inherited Destroy;
  if FCsd <> nil
  then ucsdet_close(FCsd);
end;


procedure TIcuDetector.OpenDetector;
var
  LError : UErrorCode = U_ZERO_ERROR;
begin
  // Create ICU detector if not already exists.
  if FCsd = nil
  then begin
    FCsd := ucsdet_open(@LError);
    if (FCsd = nil)
    or (LError <> U_ZERO_ERROR)
    then raise EIcuDetectException.Create('Could not open ICU ' +
      'detector (' + IntToStr(LError) + ').');
  end;
end;


procedure TIcuDetector.PrepareBuffer(const ABuffer : String;
  const AMaxCompare : Integer);
var
  LError : UErrorCode = U_ZERO_ERROR;
begin

  // Try to pass the buffer to the detector.
  ucsdet_setText(FCsd, PCChar(ABuffer), AMaxCompare, @LError);
  if LError <> U_ZERO_ERROR
  then begin
    raise EIcuDetectException.Create('Could not pass buffer to ICU ' +
    'converter (' + IntToStr(LError) + ').');
  end;
end;


function TIcuDetector.TestCharset(const ACharset : String) : Boolean;
var
  LError : UErrorCode = U_ZERO_ERROR;
begin
  if (ucnv_countAliases(PCChar(ACharset), @LError) = 0)
  then Result := false
  else Result := true;
end;


function TIcuDetector.DetectCharset(const ABuffer : String;
  const AMaxCompare : Integer) : String;
var
  LCsm : PUCharsetMatch = nil;
  LError : UErrorCode = U_ZERO_ERROR;
begin
  // Open detector if necessary;
  OpenDetector;
  Result := '';

  // If anything is or goes wrong, this will raise an exception.
  PrepareBuffer(ABuffer, AMaxCompare);

  // Buffer should be assigned. Try to do the detection.
  LCsm := ucsdet_detect(FCsd, @LError);
  if LError = U_ZERO_ERROR
  then Result := ucsdet_getName(LCsm, @LError);

end;


procedure TIcuDetector.DetectCharsets(const ABuffer : String;
  out Results : TIcuDetectionResults; const AMaxCompare : Integer);
var
  LCsms : PPUCharsetMatch = nil;
  LMatchesFound : CInt = 0;
  i : Integer;
  LError : UErrorCode = U_ZERO_ERROR;
begin
  OpenDetector;

  // If anything is or goes wrong, this will raise an exception.
  PrepareBuffer(ABuffer, AMaxCompare);
  LCsms := ucsdet_detectAll(FCsd, @LMatchesFound, @LError);

  SetLength(Results, LMatchesFound);

  // Retrieve all matches.
  for i := 0 to LMatchesFound - 1
  do begin
    with Results[i]
    do begin
      Charset := ucsdet_getName(PPUCharsetMatch(LCsms + i)^, @LError);
      Confidence := ucsdet_getConfidence(PPUCharsetMatch(LCsms + i)^,
        @LError);
    end;
  end;

end;




{ *** Convenience conversion UTF-8 <> UTF-16 *** }


function Utf8ToUtf16Icu(const AInput : Utf8String;
  ALenient : Boolean = false) : UnicodeString;
var
  DestLength : Integer;
  ConvertLength : Integer;
  ConvertError : UErrorCode = U_ZERO_ERROR;
begin
  if Length(AInput) < 1
  then begin
    Result := '';
    Exit;
  end;

  // Preflighting to find length.
  if ALenient
  then u_strFromUTF8Lenient(nil, 0, @DestLength, PChar(AInput), -1,
    @ConvertError)
  else u_strFromUTF8(nil, 0, @DestLength, PChar(AInput), -1,
    @ConvertError);

  // We expect a buffer overflow in preflighting.
  if  (ConvertError <> U_BUFFER_OVERFLOW_ERROR)
  and (ConvertError <> U_ZERO_ERROR)
  and (ConvertError <> U_STRING_NOT_TERMINATED_WARNING) // For empty strings?
  then raise EIcuConvertException.Create(
    'To-UTF-16 string preflighting error: '
    + u_errorName(ConvertError));

  // Reset the Error, because otherwise next ICU function won't exec.
  ConvertError := U_ZERO_ERROR;

  SetLength(Result, DestLength);

  if ALenient
  then u_strFromUTF8Lenient(PUnicodeChar(Result), DestLength,
    @ConvertLength, PChar(AInput), -1, @ConvertError)
  else u_strFromUTF8(PUnicodeChar(Result), DestLength,
    @ConvertLength, PChar(AInput), -1, @ConvertError);
end;


function Utf16ToUtf8Icu(const AInput : UnicodeString) : Utf8String;
var
  DestLength : Integer;
  ConvertLength : Integer;
  ConvertError : UErrorCode = 0;
begin
  if Length(AInput) < 1
  then begin
    Result := '';
    Exit;
  end;

  // Preflighting to find length.
  u_strToUTF8(nil, 0, @DestLength, PUChar(AInput), -1,
    @ConvertError);

  // We expect a buffer overflow in preflighting.
  if  (ConvertError <> U_BUFFER_OVERFLOW_ERROR)
  and (ConvertError <> U_ZERO_ERROR)
  and (ConvertError <> U_STRING_NOT_TERMINATED_WARNING) // For empty strings?
  then  raise EIcuConvertException.Create(
      'To-UTF-8 string preflighting error: ' + u_errorName(ConvertError));

  // Reset the Error, because otherwise next ICU function won't exec.
  ConvertError := U_ZERO_ERROR;

  SetLength(Result, DestLength);
  u_strToUTF8(PChar(Result), DestLength, @ConvertLength,
    PUChar(AInput), -1, @ConvertError);
end;


function Utf16UpCaseIcu(const AInput : UnicodeString) : UnicodeString;
var
  DestLength : Integer;
  ConvertLength : Integer;
  ConvertError : UErrorCode = U_ZERO_ERROR;
begin
  if Length(AInput) < 1
  then begin
    Result := '';
    Exit;
  end;

  // We assume that length never increases.
  DestLength := Length(AInput);
  SetLength(Result, 0);

  // Pre-flight.
  ConvertLength := u_strToUpper(
    PUChar(Result),
    0,
    PUChar(AInput),
    -1,
    nil,
    @ConvertError);

  ConvertError := U_ZERO_ERROR;
  SetLength(Result, ConvertLength);

  u_strToUpper(
    PUChar(Result),
    ConvertLength,
    PUChar(AInput),
    -1,
    nil,
    @ConvertError);

  // We expect a buffer overflow in preflighting.
  if (ConvertError <> U_STRING_NOT_TERMINATED_WARNING) // For empty strings?
  and (ConvertError <> U_ZERO_ERROR)
  then raise EIcuConvertException.Create(
    'UTF16 upper casing error: '
    + u_errorName(ConvertError));
end;


function Utf8UpCaseIcu(const AInput : Utf8String) : Utf8String;
var
  From16, To16 : UnicodeString;
begin
  From16 := Utf8ToUtf16Icu(AInput);
  To16 := Utf16UpCaseIcu(From16);
  Result := Utf16ToUtf8Icu(To16);
end;


{ *** Regular Expressions *** }


constructor TIcuRegex.Create(const ARegex : Utf8String;
  AIcuFlags : URegexpFlag = 0);
var
  Converted : UnicodeString;
  LStatus : UErrorCode = U_ZERO_ERROR;
begin
  if Length(ARegex) < 1
  then raise EIcuRegexException.Create('Refusing to create null regex.');

  Converted := Utf8ToUtf16Icu(ARegex);
  FRegex := uregex_open(@Converted[1], -1, AIcuFlags, nil,
    @LStatus);
  if LStatus <> U_ZERO_ERROR
  then raise EIcuRegexException.Create('Regex compilation failed.');
end;


destructor TIcuRegex.Destroy;
begin
  inherited Destroy;
  if Assigned(FRegex)
  then uregex_close(FRegex);
end;


function TIcuRegex.Match(const ASubject : Utf8String;
  AFull : Boolean = false; ALenient : Boolean = false) : Boolean;
var
  Converted : UnicodeString;
  LStatus : UErrorCode = U_ZERO_ERROR;
begin
  Converted := Utf8ToUtf16Icu(ASubject, ALenient);

  uregex_setText(FRegex, PUnicodeChar(Converted), -1, @LStatus);
  if LStatus <> U_ZERO_ERROR
  then raise EIcuRegexException.Create('Setting the text failed: '
    + u_errorName(LStatus));

  if AFull
  then Result := uregex_matches(FRegex, -1, @LStatus)
  else Result := uregex_lookingAt(FRegex, -1, @LStatus);

  if LStatus <> U_ZERO_ERROR
  then raise EIcuRegexException.Create('Matching failed: '
    + u_errorName(LStatus));
end;


function TIcuRegex.MatchCount(const ASubject : Utf8String;
  ALenient : Boolean = false) : Integer;
var
  Converted : UnicodeString;
  LStatus : UErrorCode = U_ZERO_ERROR;
begin
  Result := 0;
  Converted := Utf8ToUtf16Icu(ASubject, ALenient);

  uregex_setText(FRegex, PUnicodeChar(Converted), -1, @LStatus);
  if LStatus <> U_ZERO_ERROR
  then raise EIcuRegexException.Create('Setting the text failed: '
    + u_errorName(LStatus));

  if  uregex_find(FRegex, -1, @LStatus)
  and (LStatus = U_ZERO_ERROR)
  then begin
    Inc(Result);
    while uregex_findNext(FRegex, @LStatus)
    and   (LStatus = U_ZERO_ERROR)
    do Inc(Result);
  end;
end;


function TIcuRegex.Replace(const ASubject : Utf8String;
  const AReplacement : Utf8String; AAll : Boolean = false;
  ALenient : Boolean = false) : Utf8String;
var
  ConvertedSubject : UnicodeString;
  ConvertedReplacement : UnicodeString;
  ResultUtf16 : UnicodeString = '';
  DestLength : Integer;
  ReplacedLength : Integer;
  LStatus : UErrorCode = U_ZERO_ERROR;
begin

  // Convert input to UTF-16.
  ConvertedSubject := Utf8ToUtf16Icu(ASubject, ALenient);
  ConvertedReplacement := Utf8ToUtf16Icu(AReplacement, ALenient);

  // Set ASubject as text.
  uregex_setText(FRegex, PUnicodeChar(ConvertedSubject), -1, @LStatus);
  if LStatus <> U_ZERO_ERROR
  then raise EIcuRegexException.Create('Setting the subject failed: '
    + u_errorName(LStatus));

  // Pre-flighting.
  if AAll
  then DestLength := uregex_replaceAll(FRegex,
    PUnicodeChar(ConvertedReplacement), -1, nil, 0, @LStatus)
  else DestLength := uregex_replaceFirst(FRegex,
    PUnicodeChar(ConvertedReplacement), -1, nil, 0, @LStatus);

  // We expect a buffer overflow in preflighting.
  if  (LStatus <> U_BUFFER_OVERFLOW_ERROR)
  and (LStatus <> U_STRING_NOT_TERMINATED_WARNING)  // TODO RS Investigate why this happens.
  then raise EIcuConvertException.Create(
    'Replace string preflighting error: ' + u_errorName(LStatus));

  // Reset the Error, because otherwise next ICU function won't exec.
  LStatus := U_ZERO_ERROR;

  // Allocate buffer and convert.
  SetLength(ResultUtf16, DestLength);
  if AAll
  then ReplacedLength := uregex_replaceAll(FRegex,
    PUnicodeChar(ConvertedReplacement), -1,
    PUnicodeChar(ResultUtf16), DestLength, @LStatus)
  else ReplacedLength := uregex_replaceFirst(FRegex,
    PUnicodeChar(ConvertedReplacement), -1,
    PUnicodeChar(ResultUtf16), DestLength, @LStatus);

  if  (LStatus <> U_ZERO_ERROR)
  and (LStatus <> U_STRING_NOT_TERMINATED_WARNING)  // TODO RS Investigate why this happens.
  then raise EIcuRegexException.Create('Replacement failed: '
    + u_errorName(LStatus));

  if ReplacedLength <> DestLength
  then raise EIcuRegexException.Create(
    'Replacement has incorrect size');

  Result := Utf16ToUtf8Icu(ResultUtf16);
end;


end.
