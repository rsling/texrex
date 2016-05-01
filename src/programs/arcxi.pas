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


// This program extracts a block of bytes from a file at some offset.
// The file is transparently un-gzipped if necessary. We use it to
// extract from gzipped ARC files.


program ArcXi;

{$MODE OBJFPC}
{$H+}


uses
  {$IFDEF DEBUG}
    CMem,
    Heaptrc,
  {$ENDIF}
  SysUtils,
  StrUtils,
  Classes,
  Contnrs,
  ZStream,
  TrUtilities;


procedure ShowHelp;
begin
  Writeln(stderr);
  Writeln(stderr, 'ArcXi - Extract a document from an ARC file.');
  Writeln(stderr);
  Writeln(stderr, 'Usage: arcxi -a ARCFILE -o OFFSET '+
    '-l LENGTH');
  Writeln(stderr);
end;


var
  GError : Boolean = false;
  GInFile : String;
  GOffsetString : String;
  GOffset : Int64;
  GLengthString : String;
  GLength : Int64;
  GStream : TStream = nil;
  GBuffer : array of Byte;


begin
  GInFile := GetCmdLineArg('a', StdSwitchChars);
  GOffsetString := GetCmdLineArg('o', StdSwitchChars);
  GLengthString := GetCmdLineArg('l', StdSwitchChars);

  if not FileExists(GInFile)
  then begin
    Writeln(stderr, #10#13'Input file does not exist.');
    GError := true;
  end;

  if not TryStrToInt64(GOffsetString, GOffset)
  or (GOffset < 0)
  then begin
    Writeln(stderr, #10#13'Offset must be a positive 64-bit signed integer.');
    GError := true;
  end;

  if not TryStrToInt64(GLengthString, GLength)
  or (GLength < 1)
  then begin
    Writeln(stderr, #10#13'Length must be a 64-bit signed integer larger than 0.');
    GError := true;
  end;

  // Open the stream.
  if not GError
  then
  try
    if TrFileIsGzip(GInFile)
    then GStream := TGZFileStream.Create(GInFile, GZOpenRead)
    else GStream := TFileStream.Create(GInFile, fmOpenRead);
  except
    Writeln(stderr, #10#13'Input file exists but cannot be opened.');
    GError := true;
  end;

  if GError
  then begin
    ShowHelp;
    Exit;
  end;

  // Extract the byte block and print as string.
  SetLength(GBuffer, GLength);

  // Try to seek the position in file.
  try

    // GZFileStream does not support 64-bit offsets, hence the bifurcation.
    if GStream is TGZFileStream
    then GStream.Seek(GOffset, soFromBeginning)
    else GStream.Seek(GOffset, soBeginning);
  except
    Writeln(stderr, #10#13'Could not advance to offset ', GOffset,'. Wrong or damaged file?');
    Writeln(stderr, 'If it is a compressed file, try unpacking it separately first.');
    GError := true;
  end;

  if not GError
  then
  try
    GStream.ReadBuffer(GBuffer[0], GLength);
    Writeln(String(GBuffer));
  except
    Writeln(stderr, #10#13'Could not read ', GLength, ' bytes. Wrong or truncated file?');
    Writeln(stderr, 'If it is a compressed file, try unpacking it separately first.');
  end;

  SetLength(GBuffer,0);
  FreeAndNil(GStream);

end.
