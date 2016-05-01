{
  This file is part of texrex.
  Maintained by Roland Schäfer.
  http://texrex.sourceforge.net/

Copyright (c) <YEAR>, <OWNER>
All rights reserved.

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


unit TrCowInterleaveApplication;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  CustApp,
  Classes,
  SysUtils,
  StrUtils,
  TrVersionInfo,
  TrUtilities,
  TrFile;


type

  ETrCowInterleaveApplication = class(Exception);


  TTrCowInterleaveApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FInFile : String;
    FReader : TTrFileIn;

    FStruct : String;

    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;



implementation



const
  OptNum=2;
  OptionsShort : array[0..OptNum] of Char = ('i', 'h', 's');
  OptionsLong : array[0..OptNum] of String = ('input', 'help',
    'struct');


constructor TTrCowInterleaveApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
end;


destructor TTrCowInterleaveApplication.Destroy;
begin
  FreeAndNil(FReader);
  inherited Destroy;
end;


procedure TTrCowInterleaveApplication.Initialize;
var
  LOptionError : String;
begin
  inherited Initialize;

  Writeln(stderr,  'cowinterleave from ', TrName, '-', TrCode, ' (',
    TrVersion, ')');
  Writeln(stderr, TrMaintainer);
  Writeln(stderr);

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

  if not HasOption('s', 'struct')
  then begin
    SayError('No structural attribute was specified.');
    Exit;
  end;

  FInFile := GetOptionValue('i', 'input');
  FStruct := GetOptionValue('s', 'struct');

  if not TrFindFile(FInFile)
  then begin
    SayError('Input file does not exist.');
    Exit;
  end;

  // Try to create readers/writers.
  FReader := TTrFileIn.Create(FInFile, true);

end;



procedure TTrCowInterleaveApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


type
  TAnno = record
    Tag : String;
    Annos : String;
  end;
  TAnnos = array of TAnno;

procedure TTrCowInterleaveApplication.DoRun;
const
  LLbr = '<ci_l />';
  LTab = '<ci_t />';
var
  // The current line and where we are in the process of examining it.
  LLine : String;
  LOut : String;
  LConstructTag : String;
  LStart : String;
  LEnd : String;
  LReadingStruct : Boolean = false;
  LAnnotations : TAnnos;
  i : Integer;

  // Just for the inline functions.
  LTagFirst : String;
  LTagRest : String;
  LPos : Integer;
  LAnnoInd : Integer;

  function GetTagName(AClosing : Boolean = false) : String; inline;
  begin
    if AClosing
    then Result := ExtractDelimited(1,
        AnsiMidStr(LLine, 3, Length(LLine)-3),
       [' '])
    else Result := ExtractDelimited(1,
        AnsiMidStr(LLine, 2, Length(LLine)-2),
       [' ']);
  end;

  function IsAnnotation(const AString : String) : Integer; inline;
  var
    k : Integer;
  begin
    Result := (-1);
    for k := 0 to High(LAnnotations)
    do begin
      if (LAnnotations[k].Tag = AString)
      then begin
        Result := k;
        Break;
      end;
    end;
  end;

  procedure RemoveAnnotation;
  begin

    // Extract tag name in LTagFirst.
    LTagFirst := AnsiMidStr(LLine, 3, Length(LLine)-3);

    LAnnoInd := IsAnnotation(LTagFirst);
    if LAnnoInd >= 0
    then LAnnotations[LAnnoInd].Annos := '';
  end;

  procedure AddAnnotation;
  begin

    // Extract parts from tag into LTagFirst and LTagRest.
    LPos := PosEx(' ', LLine);
    if LPos < 1
    then Exit;

    LTagFirst := AnsiMidStr(LLine, 2, LPos-2);
    LTagRest  := AnsiMidStr(LLine, LPos, Length(LLine)-LPos);

    if Length(LTagRest) > 0
    then begin

      // Actual insertion.
      LAnnoInd := IsAnnotation(LTagFirst);

      // New insertion
      if LAnnoInd < 0
      then begin
        SetLength(LAnnotations, Length(LAnnotations)+1);
        LAnnotations[High(LAnnotations)].Tag := LTagFirst;
        LAnnotations[High(LAnnotations)].Annos := LTagRest;
      end

      // Just update an existing annotation.
      else LAnnotations[LAnnoInd].Annos := LTagRest;
    end;
  end;

begin
  if not Terminated
  then begin

    LStart := '<'  + FStruct + '>';
    LEnd   := '</' + FStruct + '>';

    while not FReader.Eos
    do begin
      FReader.ReadLine(LLine);

      if LLine = LStart
      then begin

        // Start a new output line.
        LConstructTag := '<' + FStruct;
        for i := 0 to High(LAnnotations)
        do LConstructTag += LAnnotations[i].Annos;
        LConstructTag += '>';

        LReadingStruct:= true;
        LOut := LConstructTag + LLbr;
      end

      else if LLine = LEnd
      then begin
        LOut += LLine + LLbr;
        Writeln(LOut);
        LReadingStruct:= false;
      end

      else begin

        // If its neither a start nor an end, it depends on whether
        // we are inside a region of interest.

        if LReadingStruct
        then begin
          LOut += StringReplace(LLine, #9, LTab, [rfReplaceAll]) + LLbr;
        end

        // We are NOT reading a struct and this is neither a struct
        // start nor end.
        else begin

          // For XML tag lines...
          if AnsiStartsStr('<', LLine)
          then begin

            if AnsiStartsStr('</', LLine)
            then RemoveAnnotation
            else
              if not AnsiEndsStr('/>', LLine)
              then AddAnnotation;

          end;  // else do nothing = ignore LLine.

        end;

      end;
    end;

    Terminate;
  end;
end;


procedure TTrCowInterleaveApplication.ShowHelp;
begin
  Writeln(stderr, 'Usage:  cowinterleave OPTIONS');
  Writeln(stderr);
  Writeln(stderr, ' --help     -h   Print this help and exit.');
  Writeln(stderr, ' --input    -i S Input (corpus) file name.');
  Writeln(stderr, ' --struct   -s S Shuffle on structural attribute S.');
  Writeln(stderr);
end;


procedure TTrCowInterleaveApplication.SayError(const AError : String);
begin
  Writeln(stderr, 'Error: ', AError);
  Writeln(stderr, 'Use cowinterleave -h to get help.', #10#13);
  Terminate;
end;


end.
