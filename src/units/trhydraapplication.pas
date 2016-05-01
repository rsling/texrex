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


unit TrHydraApplication;


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

  ETrHydraApplication = class(Exception);

  TTrNgrams = class
  public
    constructor Create(const AFileName : String;
      const AAddOne : Boolean = true); virtual;
    destructor Destroy; override;
    function LookupFrequency(const ANgram : String) : Integer;
  protected
    FIndex : TFPHashList;
    FAddOne: Boolean;
    FIntegers : array of Integer;
    FTotal : Integer;
    function GetSize : Integer;
  public

    // Whether brute-force add one smoothing should be used.
    property AddOne : Boolean read FAddOne;
    property Size : Integer read GetSize;
    property Total : Integer read FTotal;
  end;

  TTrHydraApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FInFile : String;
    FOutFile : String;
    FUnigramFile : String;

    FIgnore : Boolean;
    FIgnoreString : String;

    FUnigrams : TTrNgrams;

    FGzip : Boolean;
    FGerman : Boolean;
    FNondestructive : Boolean;

    FVerbose : Boolean;
    FVerboser : Boolean;

    FReader : TTrFileIn;
    FWriter : TTrFileOut;

    FCandidateLeftIcu : TIcuRegex;
    FCandidateRightIcu : TIcuRegex;
    FIgnoreIcu : TIcuRegex;
    FGermanLeftIcu : TIcuRegex;
    FGermanRightIcu : TIcuRegex;

    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;



implementation



const
  OptNum=11;
  OptionsShort : array[0..OptNum] of Char = ('i', 'o', 'h', 'g', 'u',
    'r', 'v', 'V', 'e', 'I', 'n', 'G');
  OptionsLong : array[0..OptNum] of String = ('input', 'output',
    'help', 'gzip', 'unigrams', 'rules', 'verbose',
    'Verbose', 'emofix', 'Ignore', 'nondest', 'German');

  CandidateLeftRegex : String = '^[-\p{L}]{2,}-$';
  CandidateRightRegex : String = '^([-\p{L}]{2,})(\P{L}|)$';
  GermanLeftRegex : String ='^[[:upper:]][[:lower:]]+-$';
  GermanRightRegex : String ='^[[:upper:]][[:lower:]]+$';

  XmlPre = #10'<normalized from="';
  XmlInf = '">'#10;
  XmlSuf = #10'</normalized>'#10;


constructor TTrNgrams.Create(const AFileName : String;
  const AAddOne : Boolean = true);
var
  LStrings : TStringList = nil;
  S : String;
  LValues : TStringArray;
  LFrequency : Integer;
  LIndex : Integer = 0;

begin
  inherited Create;

  FAddOne := AAddOne;
  LStrings := TStringList.Create;
  SetLength(FIntegers, 1000000);
  LIndex := 0;
  FTotal := 0;

  FIndex := TFPHashList.Create;

  try
    LStrings.Duplicates := dupIgnore;
    LStrings.LoadFromFile(AFileName);

    for S in LStrings
    do begin

      LValues := TrExplode(S, [#9]);

      if Length(LValues) <> 2
      then begin
        Writeln(stderr, 'Ignored (split chars): ', S);
        Continue;
      end;

      if Length(LValues[1]) > 256
      then begin
        Writeln(stderr, 'Ignored (ngram length): ', S);
        Continue;
      end;

      try
        LFrequency := StrToInt(LValues[0]);
      except
        Writeln(stderr, 'Ignored (frequency not a number): [', S, ']');
        Continue;
      end;

      // Everyting ok. Add to list.

      // Make room if necessary.
      if LIndex > High(FIntegers)
      then SetLength(FIntegers, High(FIntegers)+1000000);

      FIntegers[LIndex] := LFrequency;
      FIndex.Add(LValues[1], PInteger(FIntegers[LIndex]));
      if FAddOne
      then Inc(FTotal, LFrequency+1)
      else Inc(FTotal, LFrequency);

      Inc(LIndex);
    end;

  finally
    FreeAndNil(LStrings);
  end;
end;


destructor TTrNgrams.Destroy;
begin
  FreeAndNil(FIndex);
  SetLength(FIntegers, 0);
  inherited Destroy;
end;


function TTrNgrams.LookupFrequency(const ANgram : String) : Integer;
var
  LInt : PInteger;
begin
  LInt := FIndex.Find(ANgram);
  if LInt = nil
  then Result := 0
  else Move(LInt, Result, SizeOf(Integer));

  if FAddOne
  then Inc(Result);
end;


function TTrNgrams.GetSize : Integer;
begin
  Result := FIndex.Count;
end;


constructor TTrHydraApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
end;


destructor TTrHydraApplication.Destroy;
begin
  FreeAndNil(FUnigrams);
  FreeAndNil(FReader);
  FreeAndNil(FWriter);
  FreeAndNil(FCandidateLeftIcu);
  FreeAndNil(FCandidateRightIcu);
  FreeAndNil(FIgnoreIcu);
  FreeAndNil(FGermanLeftIcu);
  FreeAndNil(FGermanRightIcu);
  inherited Destroy;
end;


procedure TTrHydraApplication.Initialize;
var
  LOptionError : String;
begin
  inherited Initialize;

  Writeln(#10#13, 'HyDRA from ', TrName, '-', TrCode, ' (', TrVersion,
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

  if not HasOption('u', 'unigrams')
  then begin
    SayError('No unigram file specified.');
    Exit;
  end;

  FInFile := GetOptionValue('i', 'input');
  FOutFile := GetOptionValue('o', 'output');
  FUnigramFile := GetOptionValue('u', 'unigrams');

  if not TrFindFile(FInFile)
  then begin
    SayError('Input file does not exist.');
    Exit;
  end;

  if not TrFindFile(FUnigramFile)
  then begin
    SayError('Unigram file does not exist.');
    Exit;
  end;

  // Read facultative options.

  if HasOption('g', 'gzip')
  then FGzip := true
  else FGZip := false;

  if HasOption('G', 'German')
  then FGerman := true
  else FGerman := false;

  if HasOption('n', 'nondest')
  then FNondestructive := true
  else FNondestructive := false;

  if HasOption('v', 'verbose')
  then FVerbose := true
  else FVerbose := false;

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

  Writeln('Reading unigrams...');
  try
    FUnigrams := TTrNgrams.Create(FUnigramFile);
  except
    SayError('Error creating unigram databases.');
    Exit;
  end;
  Writeln('Read : ', FUnigrams.Size);
  Writeln('Total : ', FUnigrams.Total);

  // Try to create readers/writers.
  FReader := TTrFileIn.Create(FInFile, true);

  if FGzip
  then FWriter := TTrFileOut.Create(FOutFile, '.gz', 0, FGzip)
  else FWriter := TTrFileOut.Create(FOutFile, '', 0, FGzip);

  // Compile the regexes.
  FCandidateLeftIcu := TIcuRegex.Create(CandidateLeftRegex);
  FCandidateRightIcu := TIcuRegex.Create(CandidateRightRegex);

  if FGerman
  then begin
    FGermanLeftIcu := TIcuRegex.Create(GermanLeftRegex);
    FGermanRightIcu := TIcuRegex.Create(GermanRightRegex);
  end;

  if FVerbose
  then Writeln('Showing all replacements made ( => ).');

  if FVerboser
  then Writeln('Showing all replacements NOT made ( == ).');

  Writeln;

end;


procedure TTrHydraApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


procedure TTrHydraApplication.DoRun;

var
  // Variables for the local funtion. Allocate once outside.
  i : Integer;
  LCandidates : TStringArray;
  LPrefix : String;
  LSuffix : String;
  LAfter : String;
  LConcat : String;
  LMerger : String;
  LPPrefix : Real;
  LPSuffix : Real;
  LPMerger : Real;
  LPConcat : Real;
  LDecision : TTrHydraDecision;

  // This is where the actual work is done. Can be called repeatedly.
  // Returns true when something was actually changed.
  procedure DoHydra(var ALine : String); inline;
  begin
    LCandidates := TrExplode(ALine, [' ']);
    ALine := '';

    // Now, we process the string. We look at the i'th an i+1'th
    // token in each pass.
    i := 0;
    while i < Length(LCandidates)
    do begin

      LDecision := thdLeavalone;

      // Last single token left. Write it and exit.
      if (i = High(LCandidates))
      then begin
        ALine += LCandidates[i];
        Break;
      end;

      // Only do something if this matches the candidate pattern.
      if  FCandidateLeftIcu.Match(LCandidates[i])
      and FCandidateRightIcu.Match(LCandidates[i+1])
      then begin

        LPrefix := LCandidates[i];
        LSuffix := FCandidateRightIcu.Replace(LCandidates[i+1], '$1',
          true, true);
        LAfter  := FCandidateRightIcu.Replace(LCandidates[i+1], '$2',
          true, true);

        // unter-werfen
        LConcat := LPrefix + LSuffix;

        // unterwerfen
        LMerger := AnsiLeftStr(LPrefix, Length(LPrefix)-1) + LSuffix;

        LPPrefix := FUnigrams.LookupFrequency(LPrefix)/FUnigrams.Total;
        LPSuffix := FUnigrams.LookupFrequency(LSuffix)/FUnigrams.Total;
        LPConcat := FUnigrams.LookupFrequency(LConcat)/FUnigrams.Total;
        LPMerger := FUnigrams.LookupFrequency(LMerger)/FUnigrams.Total;

        if  (LPConcat > LPPrefix) and (LPConcat > LPSuffix)
        and (LPConcat > LPMerger)
        then LDecision := thdConcatenate

        else
        if  (LPMerger > LPPrefix) and (LPMerger > LPSuffix)
        and (LPMerger > LPConcat)
        then LDecision := thdMerge

        else
        begin

          // Additional check if this might be a German NN compound.
          if  FGerman
          and (FGermanLeftIcu.Match(LPrefix, true, true))
          and (FGermanRightIcu.Match(LSuffix, true, true))
          then LDecision := thdConcatenate

          // No, so this is definitely and finally a leavalone.
          else LDecision := thdLeavalone;
        end;

        // Act on decicion.
        case LDecision of
          thdLeavalone : begin
            ALine += LCandidates[i] + ' ';

            if FVerboser
            then Writeln(LCandidates[i], ' ', LCandidates[i+1], ' ==');

            Inc(i);
          end;

          thdMerge : begin

            if FNondestructive
            then ALine += XmlPre + LPrefix + ' ' + LSuffix + LAfter +
              XmlInf + LMerger + LAfter + XmlSuf
            else ALine += LMerger + LAfter + ' ';

            if FVerbose
            then Writeln(LPrefix, ' ', LSuffix, LAfter, ' => ', LMerger,
              LAfter);

            Inc(i, 2);
          end;

          thdConcatenate : begin

            if FNondestructive
            then ALine += XmlPre + LPrefix + ' ' + LSuffix + LAfter +
              XmlInf + LConcat + LAfter + XmlSuf
            else ALine += LConcat + LAfter + ' ';

            if FVerbose
            then Writeln(LPrefix, ' ', LSuffix, LAfter, ' => ', LConcat,
              LAfter);

            Inc(i, 2);
          end;

        end; // esac
      end

      // This candidate does not match, so just copy stuff
      else begin
        ALine += LCandidates[i] + ' ';

        // We havent processed anything, so just move forward ONE token.
        // The i+1'th token could be the left token in a real
        // candidate.
        Inc(i);
      end;

    end;
  end;

var
  // The current line and where we are in the process of examining it.
  LLine, LOriginal : String;

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
        then DoHydra(LLine);

      except
        Writeln(stderr, 'Choked on line: ', LOriginal);
        LLine := LOriginal;
      end;

      FWriter.WriteString(LLine);
    end;

    Terminate;
  end;
end;


procedure TTrHydraApplication.ShowHelp;
begin
  Writeln(#10#13'Usage:  hydra OPTIONS');
  Writeln;
  Writeln(' --help     -h   Print this help and exit.');
  Writeln(' --input    -i S Input (corpus) file name (S).');
  Writeln(' --output   -o S Output file name prefix (S).');
  Writeln(' --unigrams -u S Word list file name (S).');
  Writeln(' --German   -G   Use special rule for German NN compounds.');
  Writeln(' --Ignore   -I R Lines which mach regex R are skipped.');
  Writeln(' --nondest  -n   Insert <normalized from> tags.');
  Writeln(' --gzip     -g   Compress output with gzip.');
  Writeln(' --verbose  -v   Show all replacements on stdout.');
  Writeln(' --Verbose  -V   Show all omitted replacements on stdout.');
  Writeln;
end;


procedure TTrHydraApplication.SayError(const AError : String);
begin
  Writeln(#10#13, 'Error: ', AError);
  Writeln('Use hydra -h to get help.', #10#13);
  Terminate;
end;


end.
