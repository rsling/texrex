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


unit TrRoflApplication;


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

  ETrRoflApplication = class(Exception);

  TTrRoflApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FInFile : String;
    FOutFile : String;
    FWordFile : String;
    FPrefixFile : String;
    FSuffixFile : String;

    FIgnore : Boolean;
    FIgnoreString : String;

    FWords : TTrHashList;
    FPrefixes : TTrHashList;
    FSuffixes : TTrHashList;

    FGzip : Boolean;
    FEmofix : Boolean;
    FLimit : Integer;

    FVerbose : Boolean;
    FVerboser : Boolean;

    FReader : TTrFileIn;
    FWriter : TTrFileOut;

    FCandidateIcu : TIcuRegex;
    FEmoIcu : TIcuRegex;
    FIgnoreIcu : TIcuRegex;

    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;


implementation



const
  OptNum=11;
  OptionsShort : array[0..OptNum] of Char = ('i', 'o', 'h', 'g', 'p',
    's', 'w', 'v', 'V', 'e', 'I', 'l');
  OptionsLong : array[0..OptNum] of String = ('input', 'output',
    'help', 'gzip', 'prefix', 'suffix', 'word', 'verbose',
    'Verboser', 'emofix', 'Ignore', 'limit');

  // An interesting match is something, plus at least two letters,
  // then punctuation, then at least two letters, then something
  // again. "Something" is for "end.It's", to capture the "'s".
  // Using zero-width assertions turned out to be impossible, or I am
  // too stupid.
  CandidateRegex : String = '(^|.*\P{L})(\p{L}{2,})([!?:.]+)(\p{L}{2,})(\P{L}.*|$)';

  EmoRegex : String = ' *(:\p{L}+:) *';

constructor TTrRoflApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
end;


destructor TTrRoflApplication.Destroy;
begin
  FreeAndNil(FPrefixes);
  FreeAndNil(FSuffixes);
  FreeAndNil(FWords);
  FreeAndNil(FReader);
  FreeAndNil(FWriter);
  FreeAndNil(FCandidateIcu);
  FreeAndNil(FEmoIcu);
  FreeAndNil(FIgnoreIcu);
  inherited Destroy;
end;


procedure TTrRoflApplication.Initialize;
var
  LOptionError : String;
  LStrings : TStringList;
  LString : String;
begin
  inherited Initialize;

  Writeln(#10#13, 'rofl from ', TrName, '-', TrCode, ' (', TrVersion,
    ')', #10#13, TrMaintainer, #10#13);

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

  if not HasOption('w', 'word')
  then begin
    SayError('No word list file specified.');
    Exit;
  end;

  FInFile := GetOptionValue('i', 'input');
  FOutFile := GetOptionValue('o', 'output');
  FWordFile := GetOptionValue('w', 'word');

  if not TrFindFile(FInFile)
  then begin
    SayError('Input file does not exist.');
    Exit;
  end;

  if not TrFindFile(FWordFile)
  then begin
    SayError('Word list file does not exist.');
    Exit;
  end;

  // Read facultative options.

  if HasOption('g', 'gzip')
  then FGzip := true
  else FGzip := false;

  if HasOption('e', 'emofix')
  then FEmofix := true
  else FEmofix := false;

  if HasOption('v', 'verbose')
  then FVerbose := true
  else FVerbose := false;

  if HasOption('l', 'limit')
  then begin
    try
      FLimit := StrToInt(GetOptionValue('l', 'limit'));
    except
      SayError('The limit option is invalid/not an integer.');
      Exit;
    end;

    // Warn if the limit is insane.
    if FLimit < 1
    then begin
      SayError('A limit below 1 is not possible.');
      Exit;
    end
    else if FLimit > 10
    then Writeln('WARNING! Setting the limit option to more than 10 ',
      'is not recommended!');
  end
  else FLimit := 1;

  if HasOption('V', 'Verbose')
  then FVerboser := true
  else FVerboser := false;

  if HasOption('I', 'Ignore')
  then begin
    FIgnoreString := GetOptionValue('I', 'Ignore');
    try
      FIgnoreIcu := TIcuRegex.Create(FIgnoreString);
      FIgnore := true;
    except
      SayError('Ignore regex could not be compiled. Is it ICU-correct?');
      Exit;
    end;
  end else begin
    FIgnore := false;
  end;

  if HasOption('p', 'prefix')
  then begin
    FPrefixFile := GetOptionValue('p', 'prefix');
    if not TrFindFile(FPrefixFile)
    then begin
      SayError('The specified prefix file does not exist.');
      Exit;
    end;

    Write('Reading ignore prefixes ... ');

    // Read file.
    try
      LStrings := TStringList.Create;
      LStrings.Duplicates := dupIgnore;
      LStrings.LoadFromFile(FPrefixFile);
      FPrefixes := TTrHashList.Create;

      // Load strings in hash table.
      for LString in LStrings
      do if (Length(LString) < 256)
        then FPrefixes.Add(LString)
        else Writeln(stdout, 'Prefix too long, ignored: '#10#13,
          LString);

    except
      FreeAndNil(LStrings);
      SayError('Could not load prefix file.');
      Exit;
    end;
    FreeAndNil(LStrings);

    Write(FPrefixes.Count, ' ');
    Writeln('done.');
  end;

  if HasOption('s', 'suffix')
  then begin
    FSuffixFile := GetOptionValue('s', 'suffix');
    if not TrFindFile(FSuffixFile)
    then begin
      SayError('The specified suffix file does not exist.');
      Exit;
    end;

    Write('Reading ignore suffixes ... ');

    // Read file.
    try
      LStrings := TStringList.Create;
      LStrings.Duplicates := dupIgnore;
      LStrings.LoadFromFile(FSuffixFile);
      FSuffixes := TTrHashList.Create;

      // Load strings in hash table.
      for LString in LStrings
      do if (Length(LString) < 256)
        then FSuffixes.Add(LString)
        else Writeln(stdout, 'Suffix too long, ignored: '#10#13,
          LString);

    except
      FreeAndNil(LStrings);
      SayError('Could not load suffix file.');
      Exit;
    end;
    FreeAndNil(LStrings);

    Write(FSuffixes.Count, ' ');
    Writeln('done.');
  end;

  Write('Reading words ... ');

  // Try to read word list.
  try
    LStrings := TStringList.Create;
    LStrings.Duplicates := dupIgnore;
    LStrings.LoadFromFile(FWordFile);
    FWords := TTrHashList.Create;

    // Load strings in hash table.
    for LString in LStrings
    do if (Length(LString) < 256)
      then FWords.Add(LString)
      else Writeln(stdout, 'Word too long, ignored: '#10#13,
        LString);

  except
    FreeAndNil(LStrings);
    SayError('Could not load word list file.');
    Exit;
  end;
  FreeAndNil(LStrings);

  Write(FWords.Count, ' ');
  Writeln('done.');

  // Try to create readers/writers.
  FReader := TTrFileIn.Create(FInFile, true);

  if FGzip
  then FWriter := TTrFileOut.Create(FOutFile, '.gz', 0, FGzip)
  else FWriter := TTrFileOut.Create(FOutFile, '', 0, FGzip);

  // Compile the regexes.
  FCandidateIcu := TIcuRegex.Create(CandidateRegex);
  if FEmofix
  then FEmoIcu := TIcuRegex.Create(EmoRegex);

  if FVerbose
  then Writeln('Showing all replacements made ( => ).');

  if FVerboser
  then Writeln('Showing all replacements NOT made ( == ).');

  Writeln;

end;


procedure TTrRoflApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


procedure TTrRoflApplication.DoRun;

  // This is where the actual work is done. Can be called repeatedly.
  // Returns true when something was actually changed.
  function DoRofl(var ALine : String) : Boolean; inline;
  var
    C : String;
    LCandidates : TStringArray;
    LBefore : String;
    LPrefix : String;
    LPrefixLow : String;
    LSeparator : String;
    LSuffix : String;
    LSuffixLow : String;
    LAfter : String;
  begin
    Result := false;
    LCandidates := TrExplode(ALine, [' ']);
    ALine := '';

    // Now, we process the string with possible run-on fixing.
    for C in LCandidates
    do begin

      // Only do something if this matches the candidate pattern.
      if FCandidateIcu.Match(C)
      then begin
        LBefore    := FCandidateIcu.Replace(C, '$1', true, true);
        LPrefix    := FCandidateIcu.Replace(C, '$2', true, true);
        LSeparator := FCandidateIcu.Replace(C, '$3', true, true);
        LSuffix    := FCandidateIcu.Replace(C, '$4', true, true);
        LAfter     := FCandidateIcu.Replace(C, '$5', true, true);
        LPrefixLow := Utf8LowerCase(LPrefix);
        LSuffixLow := Utf8LowerCase(LSuffix);

        // If the prefix/suffix are not in the ignore lists
        // and they are words, fix the run-on.
        if  ((not Assigned(FPrefixes))
          or (not FPrefixes.Find(LPrefixLow)))
        and ((not Assigned(FSuffixes))
          or (not FSuffixes.Find(LSuffixLow)))
        and (FWords.Find(LPrefixLow))
        and (FWords.Find(LSuffixLow))
        then begin
          ALine += LBefore + LPrefix + LSeparator + ' ' +
            LSuffix + LAfter + ' ';
          Result := true;

          if FVerbose
          then Writeln(C, ' => ', LBefore + LPrefix + LSeparator +
            ' ' + LSuffix + LAfter);
        end

        // If all this is not the case, we just add the candidate
        // to the output unchanged.
        else begin
          ALine += C + ' ';

          if FVerboser
          then Writeln(C, ' == ');
        end;

      end

      // This candidate does not match, so just copy stuff
      else ALine += C + ' ';
    end;

  end;

var

  // The current line and where we are in the process of examining it.
  LLine, LOriginal : String;
  i : Integer;

begin
  if not Terminated
  then begin

    while not FReader.Eos
    do begin
      FReader.ReadLine(LOriginal);
      LLine := LOriginal;

      try
        // First see if this line should be ignored. If so, just
        // write it and continue with next iteration
        if (not FIgnore)
        or (not FIgnoreIcu.Match(LLine))
        then begin

          // Apply phpBB emoticon fix if desired.
          if FEmofix
          then LLine := FEmoIcu.Replace(LLine, ' $1 ', true, true);

          i := 0;
          while DoRofl(LLine)
          and   (i < FLimit)
          do Inc(i);

        end;

      except
        Writeln(stderr, 'Choked on line: ', LOriginal);
        LLine := LOriginal;
      end;

      FWriter.WriteString(LLine);
    end;

    Terminate;
  end;
end;


procedure TTrRoflApplication.ShowHelp;
begin
  Writeln(#10#13'Usage:  rofl OPTIONS');
  Writeln;
  Writeln(' --help    -h   Print this help and exit.');
  Writeln(' --input   -i S Input (corpus) file name (S).');
  Writeln(' --output  -o S Output file name prefix (S).');
  Writeln(' --word    -w S Word list file name (S).');
  Writeln(' --prefix  -p S Ignore prefix file name (S). [optional]');
  Writeln(' --suffix  -s S Ignore suffix file name (S). [optional]');
  Writeln(' --emofix  -e   Pre-wash with phpBB :emoticon: fixer.');
  Writeln('                Note: This does NOT ignore XML regions.');
  Writeln(' --Ignore  -I R Lines which mach regex R are skipped.');
  Writeln(' --limit   -l I Wash each line I times. [default: 1]');
  Writeln(' --gzip    -g   Compress output with gzip.');
  Writeln(' --verbose -v   Show all replacements on stdout.');
  Writeln(' --Verbose -V   Show all omitted replacements on stdout.');
  Writeln;
end;


procedure TTrRoflApplication.SayError(const AError : String);
begin
  Writeln(#10#13, 'Error: ', AError);
  Writeln('Use rofl -h to get help.', #10#13);
  Terminate;
end;


end.
