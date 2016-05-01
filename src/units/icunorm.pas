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


unit IcuNorm;


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
  UNormalizer2 = packed record end;
  PUNormalizer2 = ^UNormalizer2;
  PPUNormalizer2 = ^PUNormalizer2;


function unorm2_getNFCInstance(err : PUErrorCode) : PUNormalizer2;
  external LibName
  name 'unorm2_getNFCInstance' + ProcSuf;

function unorm2_normalize(norm2 : PUNormalizer2; src : PUChar; length : CInt32;
  dest : PUChar; capacity : CInt32; pErrorCode : PUErrorCode) : CInt32;
  external LibName
  name 'unorm2_normalize' + ProcSuf;

function unorm2_spanQuickCheckYes	(norm2 : PUNormalizer2; s : PUChar;
  length : CInt32; pErrorCode : PUErrorCode)	: CInt32;
  external LibName
  name 'unorm2_spanQuickCheckYes' + ProcSuf;

function unorm2_normalizeSecondAndAppend(norm2 : PUNormalizer2; first : PUChar;
  firstLength : CInt32; firstCapacity : CInt32; second : PUChar;
  secondLength : CInt32; pErrorCode : PUErrorCode)	: CInt32;
  external LibName
  name 'unorm2_normalizeSecondAndAppend' + ProcSuf;


implementation

end.
