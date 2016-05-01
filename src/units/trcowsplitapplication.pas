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


unit TrCowsplitApplication;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  CustApp,
  Classes,
  Contnrs,
  SysUtils,
  StrUtils,
  LazUtf8,
  IcuWrappers,
  TrVersionInfo,
  TrUtilities,
  TrFile,
  TrHashList;


type
  TTrHydraDecision = (
    thdLeavalone,
    thdMerge,
    thdConcatenate
  );

  ETrCowsplitApplication = class(Exception);


  TTrCowsplitApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FInFile : String;
    FOutFile : String;

    // We split BEFORE a line matching this if the line count has been
    // reached in the last file.
    FRegex : String;
    FGzip : Boolean;

    // This is the limit of lines a file should ideally not exceed.
    FSplitCount : Integer;

    // How many lines in CURRENT output file.
    FCurrentLineCount : Integer;

    FReader : TTrFileIn;
    FWriter : TTrFileOut;
    FSplitBeforeIcu : TIcuRegex;

    procedure NextFile;
    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;



implementation



const
  OptNum=5;
  OptionsShort : array[0..OptNum] of Char = ('i', 'o', 'h', 'r', 'g',
    's');
  OptionsLong : array[0..OptNum] of String = ('input', 'output',
    'help', 'regex', 'gzip', 'split');


constructor TTrCowsplitApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
end;


destructor TTrCowsplitApplication.Destroy;
begin
  FreeAndNil(FReader);
  FreeAndNil(FWriter);
  FreeAndNil(FSplitBeforeIcu);
  inherited Destroy;
end;


procedure TTrCowsplitApplication.Initialize;
var
  LOptionError : String;
begin
  inherited Initialize;

  Writeln(#10#13, 'cowsplit from ', TrName, '-', TrCode, ' (',
    TrVersion, ')', #10#13, TrMaintainer, #10#13);

  LOptionError := CheckOptions(OptionsShort, OptionsLong);

  if LOptionError <> ''
  then begin
    SayError(LOptionError);
    Exit;
  end;

  if HasOption('h', 'help')
  then begin
    ShowHelp;
    Terminate;
    Exit;
  end;

  if not HasOption('i', 'input')
  then begin
    SayError('No input file specified.');
    Exit;
  end;

  if not HasOption('o', 'output')
  then begin
    SayError('No output file name prefix specified.');
    Exit;
  end;

  if not HasOption('r', 'regex')
  then begin
    SayError('No regex specified.');
    Exit;
  end;

  if not HasOption('s', 'split')
  then begin
    SayError('No line count for splitting specified.');
    Exit;
  end;

  FInFile := GetOptionValue('i', 'input');
  FOutFile := GetOptionValue('o', 'output');
  FRegex := GetOptionValue('r', 'regex');

  if not TryStrToInt(GetOptionValue('s', 'split'), FSplitCount)
  or (FSplitCount < 1)
  then begin
    SayError('Line count for splitting must be a positve integer.');
    Exit;
  end;

  if not TrFindFile(FInFile)
  then begin
    SayError('Input file does not exist.');
    Exit;
  end;

  // Read facultative options.

  if HasOption('g', 'gzip')
  then FGzip := true
  else FGZip := false;

  // Try to create readers/writers.
  FReader := TTrFileIn.Create(FInFile, true);

  FCurrentLineCount := 0;
  NextFile;

  // Compile the regexes.
  FSplitBeforeIcu := TIcuRegex.Create(FRegex);
end;


procedure TTrCowsplitApplication.NextFile;
begin

  if not Assigned(FWriter)
  then begin
    if FGzip
    then FWriter := TTrFileOut.Create(FOutFile, '.gz', 0,
      FGzip)
    else FWriter := TTrFileOut.Create(FOutFile, '',    0,
      FGzip);
  end else

    // If the writer already exists, we just need to advance the
    // outfile.
    FWriter.CreateNextFile;

  Writeln('Split after ', FCurrentLineCount, ' lines. Now: ',
    FWriter.FileName);
  // Reset line count in current output.
  FCurrentLineCount := 0;
end;


procedure TTrCowsplitApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


procedure TTrCowsplitApplication.DoRun;
var
  // The current line and where we are in the process of examining it.
  LLine : String;
begin
  if not Terminated
  then begin

    while not FReader.Eos
    do begin
      FReader.ReadLine(LLine);
      Inc(FCurrentLineCount);

      // Split conditions are easy to check.
      if  (FCurrentLineCount >= FSplitCount)
      and FSplitBeforeIcu.Match(LLine, false, true)
      then NextFile;

      // This writes to either old or new file.
      FWriter.WriteString(LLine);
    end;

    Terminate;
  end;
end;


procedure TTrCowsplitApplication.ShowHelp;
begin
  Writeln(#10#13'Usage:  cowsplit OPTIONS');
  Writeln;
  Writeln(' --help     -h   Print this help and exit.');
  Writeln(' --input    -i S Input (corpus) file name.');
  Writeln(' --output   -o S Output file name prefix.');
  Writeln(' --regex    -r S Regex BEFORE which file should be split.');
  Writeln('                 ICU.');
  Writeln(' --split    -s I Number of lines after which file should be split.');
  Writeln(' --gzip     -g   Compress output with gzip.');
  Writeln;
end;


procedure TTrCowsplitApplication.SayError(const AError : String);
begin
  Writeln(#10#13, 'Error: ', AError);
  Writeln('Use cowsplit -h to get help.', #10#13);
  Terminate;
end;


end.
