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
  - uregex.h (complete 4.8)
}


unit IcuRegex;


{$MODE FPC}
{$CALLING CDECL}
{$PACKRECORDS C}
{$H+}

{$IFDEF DARWIN}
  {$LINKLIB icui18n}
{$ENDIF}

interface


uses
  CTypes,
  IcuTypes;


{$I icuplatform.inc}

const
  {$IFDEF WINDOWS}
    LibName = 'icuin' + IcuSuff + '.dll';
  {$ELSE}
    LibName = 'icui18n';
  {$ENDIF}
  ProcSuf = '_' + IcuSuff;


type
  URegularExpression = packed record end;
  PURegularExpression = ^URegularExpression;


type
  URegexpFlag = CUInt32;
  PURegexpFlag = ^URegexpFlag;


const
  UREGEX_CASE_INSENSITIVE = 2;
  UREGEX_COMMENTS         = 4;
  UREGEX_DOTALL           = 32;
  UREGEX_MULTILINE        = 8;
  UREGEX_UWORD            = 256;



function uregex_open(pattern : PUChar; patternLength : CInt32;
  flags : CUInt32; pe : PUParseError; status : PUErrorCode) :
  PURegularExpression;
  external LibName
  name 'uregex_open' + ProcSuf;

function uregex_openC(pattern : PChar; flags : CUInt32;
  pe : PUParseError; status : PUErrorCode) : PURegularExpression;
  external LibName
  name 'uregex_openC' + ProcSuf;

procedure uregex_close(regexp : PURegularExpression);
  external LibName
  name 'uregex_close' + ProcSuf;

function uregex_clone(regexp : PURegularExpression;
  status : PUErrorCode) : PURegularExpression;
  external LibName
  name 'uregex_clone' + ProcSuf;

function uregex_pattern(regexp : PURegularExpression;
  patLength : PCInt32; status : PUErrorCode) : PUChar;
  external LibName
  name 'uregex_pattern' + ProcSuf;

function uregex_flags(regexp : PURegularExpression;
  status : PUErrorCode) : CInt32;
  external LibName
  name 'uregex_flags' + ProcSuf;

procedure uregex_setText(regexp : PURegularExpression;
  text : PUChar; textLength : CInt32; status : PUErrorCode);
  external LibName
  name 'uregex_setText' + ProcSuf;

function uregex_getText(regexp : PURegularExpression;
  textLength : PCInt32; status : PUErrorCode) : PUChar;
  external LibName
  name 'uregex_getText' + ProcSuf;

function uregex_matches(regexp : PURegularExpression;
  startIndex : CInt32; status : PUErrorCode) : UBool;
  external LibName
  name 'uregex_matches' + ProcSuf;

function uregex_lookingAt(regexp : PURegularExpression;
  startIndex : CInt32; status : PUErrorCode) : UBool;
  external LibName
  name 'uregex_lookingAt' + ProcSuf;

function uregex_find(regexp : PURegularExpression; startIndex : CInt32;
  status : PUErrorCode) : UBool;
  external LibName
  name 'uregex_find' + ProcSuf;

function uregex_findNext(regexp : PURegularExpression;
  status : PUErrorCode) : UBool;
  external LibName
  name 'uregex_findNext' + ProcSuf;

function uregex_groupCount(regexp : PURegularExpression;
  status : PUErrorCode) : CInt32;
  external LibName
  name 'uregex_groupCount' + ProcSuf;

function uregex_group(regexp : PURegularExpression; groupNum : CInt32;
  dest : PUChar; destCapacity : CInt32; status : PUErrorCode) :
  CInt32;
  external LibName
  name 'uregex_group' + ProcSuf;

function uregex_start(regexp : PURegularExpression; groupNum : CInt32;
  status : PUErrorCode) : CInt32;
  external LibName
  name 'uregex_start' + ProcSuf;

function uregex_end(regexp : PURegularExpression; groupNum : CInt32;
  status : PUErrorCode) : CInt32;
  external LibName
  name 'uregex_end' + ProcSuf;

procedure uregex_reset(regexp : PURegularExpression; index : CInt32;
  status : PUErrorCode);
  external LibName
  name 'uregex_reset' + ProcSuf;

function uregex_replaceAll(regexp : PURegularExpression;
  replacementText : PUChar; replacementLength : CInt32;
  destBuf : PUChar; destCapacity : CInt32; status : PUErrorCode) :
  CInt32;
  external LibName
  name 'uregex_replaceAll' + ProcSuf;

function uregex_replaceFirst(regexp : PURegularExpression;
  replacementText : PUChar; replacementLength : CInt32;
  destBuf : PUChar; destCapacity : CInt32; status : PUErrorCode) :
  CInt32;
  external LibName
  name 'uregex_replaceFirst' + ProcSuf;

function uregex_appendReplacement(regexp : PURegularExpression;
  replacementText : PUChar; replacementLength : CInt32;
  destBuf : PPUChar; destCapacity : PCInt32; status : PUErrorCode) :
  CInt32;
  external LibName
  name 'uregex_appendReplacement' + ProcSuf;

function uregex_appendTail(regexp : PURegularExpression;
  destBuf : PPUChar; destCapacity : PCInt32; status : PUErrorCode) :
  CInt32;
  external LibName
  name 'uregex_appendTail' + ProcSuf;


// NOTE RS array of PUChar was UChar *destFields[]
function uregex_split(regexp : PURegularExpression; destBuf : PUChar;
  destCapacity : CInt32; requiredCapacity : PCInt32;
  destFields : array of PUChar; destFieldsCapacity : CInt32;
  status : PUErrorCode) : CInt32;
  external LibName
  name 'uregex_split' + ProcSuf;


implementation



end.
