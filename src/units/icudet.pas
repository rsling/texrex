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
  - ucsdet.h (partial 4.8)
}


unit IcuDet;


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
  UCharsetMatch = packed record end;
  PUCharsetMatch = ^UCharsetMatch;
  PPUCharsetMatch = ^PUCharsetMatch;

  UCharsetDetector = packed record end;
  PUCharsetDetector = ^UCharsetDetector;
  PPCharsetDetector = ^PUCharsetDetector;


function ucsdet_open(Status : PUErrorCode) : PUCharsetDetector;
  external LibName
  name 'ucsdet_open' + ProcSuf;

procedure ucsdet_close(ucsd : PUCharsetDetector);
  external LibName
  name 'ucsdet_close' + ProcSuf;

procedure ucsdet_setText(ucsd : PUCharsetDetector;
  textIn : PCChar; len : CInt32; status : PUErrorCode);
  external LibName
  name 'ucsdet_setText' + ProcSuf;

function ucsdet_detect(ucsd : PUCharsetDetector; status : PUErrorCode) :
  PUCharsetMatch;
  external LibName
  name 'ucsdet_detect' + ProcSuf;

function ucsdet_detectAll(ucsd : PUCharsetDetector;
  matchesFound : PCInt32; status: PUErrorCode) : Pointer;
  external LibName
  name 'ucsdet_detectAll' + ProcSuf;

function ucsdet_getName(ucsm : PUCharsetMatch; status : PUErrorCode) :
  PChar;
  external LibName
  name 'ucsdet_getName' + ProcSuf;

function ucsdet_getConfidence(ucsm : PUCharsetMatch;
  status : PUErrorCode) : CInt32;
  external LibName
  name 'ucsdet_getConfidence' + ProcSuf;

function ucsdet_getLanguage(ucsm : PUCharsetMatch;
  status : PUErrorCode) : PChar;
  external LibName
  name 'ucsdet_getLanguage' + ProcSuf;


implementation



end.
