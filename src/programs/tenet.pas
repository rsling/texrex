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


// This is almost unmodified texrex-mrvain code *deprecated* for further
// use in new texrex components.


program tenet;

{$MODE OBJFPC}
{$H+}


{$IFDEF LINUX}
  {$LINKLIB m}
{$ENDIF}


uses
  {$IFDEF UNIX}
    CMem,
  {$ENDIF}

  {$IFDEF DEBUG}
    HeapTrc,
  {$ENDIF}
  SysUtils,
  TrTenetApplication;


var
  TrTenetApp : TTrTenetApplication;


begin
  TrTenetApp := TTrTenetApplication.Create(nil);
  TrTenetApp.Initialize;
  TrTenetApp.Run;
  FreeAndNil(TrTenetApp);
end.