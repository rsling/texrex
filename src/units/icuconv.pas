{
  This file is part of texrex.
  It contains header conversions and wrappers for the ICU library.
  Maintained by Roland Schäfer.
  http://texrex.sourceforge.net/

  See the file COPYING.IBM, included in this distribution, for
  details about the copyright.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
  OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
  HOLDERS INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL
  INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING
  FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
  NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
  WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
}


{
  Header translations for:
  - ucnv.h (partial 4.8)
  - ustring.h  (partial 4.8)
}


unit IcuConv;


{$MODE FPC}
{$CALLING CDECL}
{$PACKRECORDS C}
{$H+}

{$IFDEF DARWIN}
  {$LINKLIB icuuc}
{$ENDIF}


interface


uses
  CTypes,
  IcuTypes;


{$I icuplatform.inc}


const
  {$IFDEF WINDOWS}
    LibName = 'icuuc' + IcuSuff + '.dll';
  {$ELSE}
    LibName = 'icuuc';
  {$ENDIF}
  ProcSuf = '_' + IcuSuff;

type
  UConverter = packed record end;
  PUConverter = ^UConverter;
  PPUConverter = ^PUConverter;

type
  UConverterPlatform = CInt;
const
  UCNV_UNKNOWN = -1;
  UCNV_IBM = 0;


function ucnv_countAliases(alias : PCChar; pErrorCode : PUErrorCode) :
  CUInt16;
  external LibName
  name 'ucnv_countAliases' + ProcSuf;

function ucnv_getDefaultName : PChar;
  external LibName
  name 'ucnv_getDefaultName' + ProcSuf;

function ucnv_getMaxCharSize(converter : PUConverter) : CInt8;
  external LibName
  name 'ucnv_getMaxCharSize' + ProcSuf;

// IMPLEMENTED - From a C macro.
function UCNV_GET_MAX_BYTES_FOR_STRING(length : CInt;
  maxCharSize : CInt8) : CInt;

function ucnv_getMinCharSize(converter : PUConverter) : CInt8;
  external LibName
  name 'ucnv_getMinCharSize' + ProcSuf;

function ucnv_openCCSID(charset : CInt32;
  plattform : UConverterPlatform; err : PUErrorCode) : PUConverter;
  external LibName
  name 'ucnv_openCCSID' + ProcSuf;

function ucnv_open(converterName : PChar; err : PUErrorCode) :
  PUConverter;
  external LibName
  name 'ucnv_open' + ProcSuf;

function ucnv_openU(name : PChar; err : PUErrorCode) : PUConverter;
  external LibName
  name 'ucnv_openU' + ProcSuf;

procedure ucnv_close(converter : PUConverter);
  external LibName
  name 'ucnv_close' + ProcSuf;

function ucnv_getMinCharSize(converter : PUConverter) : CUInt8;
  external LibName
  name 'ucnv_getMinCharSize' + ProcSuf;

function ucnv_getMaxCharSize(converter : PUConverter) : CUInt8;
  external LibName
  name 'ucnv_getMaxCharSize' + ProcSuf;

procedure ucnv_toUnicode(converter : PUConverter; target : PPUChar;
  targetLimit : PUChar; source : PPChar; sourceLimit : PChar;
  offsets : PCInt32; flush : UBool; err : PUErrorCode);
  external LibName
  name 'ucnv_toUnicode' + ProcSuf;

function ucnv_toUChars(cnv : PUConverter; dest : PUChar;
  destCapacity : CInt32; src : PChar; srcLength : CInt32;
  pErrorCode : PUErrorCode) : CInt32;
  external LibName
  name 'ucnv_toUChars' + ProcSuf;

function ucnv_fromUChars(cnv : PUConverter; dest : PChar;
  destCapacity : CInt32; src : PUChar; srcLength : CInt32;
  pErrorCode : PUErrorCode) : CInt32;
  external LibName
  name 'ucnv_fromUChars' + ProcSuf;

procedure ucnv_fromUnicode(converter : PUConverter; target : PPChar;
  chartargetLimit : PChar; source : PPUChar; sourceLimit : PUChar;
  offsets : PCInt32; flush : UBool; err : PUErrorCode);
  external LibName
  name 'ucnv_fromUnicode' + ProcSuf;

procedure ucnv_convertEx(targetCnv : PUConverter;
  sourceCnv : PUConverter; target : PPChar; targetLimit : PChar;
  source : PPChar; sourceLimit : PChar; pivotStart : PUChar;
  pivotSource : PPUChar; pivotTarget : PPUChar; pivotLimit : PUChar;
  reset : UBool; flush : UBool; pErrorCode : PUErrorCode);
  external LibName
  name 'ucnv_convertEx' + ProcSuf;

function ucnv_convert(toConverterName : PChar;
  fromConverterName : PChar;
  target : PChar;
  targetCapacity : CInt32;
  source : PChar;
  sourceLength : CInt32;
  pErrorCode : PUErrorCode) : CInt32;
  external LibName
  name 'ucnv_convert' + ProcSuf;

procedure ucnv_resetFromUnicode(converter : PUConverter);
  external LibName
  name 'ucnv_resetFromUnicode' + ProcSuf;

procedure ucnv_resetToUnicode(converter : PUConverter);
  external LibName
  name 'ucnv_resetToUnicode' + ProcSuf;


{ *** ustring.h convenience *** }


function u_strlen (s : PUChar) : CInt32;
  external LibName
  name 'u_strlen' + ProcSuf;


function u_countChar32 (s : PUChar; length : CInt32) : CInt32;
  external LibName
  name 'u_countChar32' + ProcSuf;


function u_strFromUTF8 (dest : PUChar;
    destCapacity : CInt32;
    pDestLength : PCInt32;
    src : PChar;
    srcLength : CInt32;
    pErrorCode : PUErrorCode
  ) : PUChar;
  external LibName
  name 'u_strFromUTF8' + ProcSuf;

function u_strFromUTF8Lenient (dest : PUChar;
    destCapacity : CInt32;
    pDestLength : PCInt32;
    src : PChar;
    srcLength : CInt32;
    pErrorCode : PUErrorCode
  ) : PUChar;
  external LibName
  name 'u_strFromUTF8Lenient' + ProcSuf;


function u_strToUTF8(dest : PChar;
    destCapacity : CInt32;
    pDestLength : PCInt32;
    src : PUChar;
    srcLength : CInt32;
    ErrorCode : PUErrorCode
  ) : PChar;
  external LibName
  name 'u_strToUTF8' + ProcSuf;


function u_strToUpper(dest : PUChar;
    destCapacity : CInt32;
    src : PUChar;
    srcLength : CInt32;
    locale : PChar;
    ErrorCode : PUErrorCode
  ) : CInt32;
  external LibName
  name 'u_strToUpper' + ProcSuf;



implementation



function UCNV_GET_MAX_BYTES_FOR_STRING(length : CInt32;
  maxCharSize : CInt8) : CInt32;
begin
  UCNV_GET_MAX_BYTES_FOR_STRING := (length + 10) * maxCharSize;
end;


end.
