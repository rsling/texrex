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


unit TrTeclApplication;


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
  TrVersionInfo,
  TrUtilities,
  TrFile,
  TrShingleHelpers;


type

  ETrTeclApplication = class(Exception);

  TTrTeclApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FInFileMask : String;
    FBlacklistFileMask : String;
    FOutFilePrefix : String;
    FSplit : Integer;
    FWhitelist : Boolean;
    FGzip : Boolean;
    FUniqueIds : Boolean;

    FInFiles : TStringList;
    FBlacklistFiles : TStringList;

    FReader : TTrFileIn;
    FWriter : TTrFileOut;
    FBlacklist : TFPHashList;

    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;


implementation


var
  Dummy : Byte = 0;


const
  OptNum=7;
  OptionsShort : array[0..OptNum] of Char = ('b', 'i', 'o', 'w', 's',
    'h', 'g', 'u');
  OptionsLong : array[0..OptNum] of String = ('black', 'input',
    'output', 'white', 'split', 'help', 'gzip', 'uniqids');

  DocStart       = '<doc url=';
  DocStartLength = 9;
  DocEnd         = '</doc>';
  DocEndLength   = 6;


constructor TTrTeclApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FSplit := 0;
  FGzip := false;
  FWhitelist := false;
end;


destructor TTrTeclApplication.Destroy;
begin
  FreeAndNil(FBlacklist);
  FreeAndNil(FReader);
  FreeAndNil(FWriter);
  inherited Destroy;
end;


procedure TTrTeclApplication.Initialize;
var
  LOptionError : String;
  LLine : String;
  LBlacklistReader : TTrFileIn;
begin
  inherited Initialize;

  Writeln(#10#13, 'tecl from ', TrName, '-', TrCode, ' (', TrVersion,
    ')', #10#13, TrMaintainer, #10#13);

  LOptionError := CheckOptions(OptionsShort, OptionsLong);
  if LOptionError <> ''
  then begin
    SayError(LOptionError);
    Exit;
  end;

  // Whitelist and unique ID mode are incomaptible, so check.
  if  HasOption('u', 'uniqids')
  and HasOption('w', 'white')
  then begin
    SayError('The whitelist and the unique ID options cannot be used ' +
      'together.');
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
    SayError('No input file mask specified.');
    Exit;
  end;

  if not HasOption('o', 'output')
  then begin
    SayError('No output file name prefix specified.');
    Exit;
  end;

  if not HasOption('b', 'black')
  then begin
    SayError('No blacklist file name prefix specified.');
    Exit;
  end;

  FInFileMask := GetOptionValue('i', 'input');
  FBlacklistFileMask := GetOptionValue('b', 'black');
  FOutFilePrefix := GetOptionValue('o', 'output');

  // Read facultative options.

  if HasOption('u', 'uniqids')
  then FUniqueIds := true;

  if HasOption('g', 'gzip')
  then FGzip := true;

  if HasOption('w', 'white')
  then FWhitelist := true;

  if HasOption('s', 'split')
  then begin
    if (not TryStrToInt(GetOptionValue('s', 'split'), FSplit))
    or (FSplit < 0)
    then begin
      SayError('Split number must be a positive integer.');
      Exit;
    end;
  end;

  // Try to create input file list.
  TrBuildFileList(FInFileMask, FInFiles);
  if (FInFiles.Count < 1)
  then begin
    SayError('No files were found which match the input pattern.');
    Exit;
  end;

  // Try to create blacklist file list.
  TrBuildFileList(FBlacklistFileMask, FBlacklistFiles);
  if (FBlacklistFiles.Count < 1)
  then begin
    SayError('No files were found which match the blacklist pattern.');
    Exit;
  end;

  // Try to create blacklist.
  try
    If FWhitelist
    then Write('Reading whitelist entries... ')
    else Write('Reading blacklist entries... ');

    LBlacklistReader := TTrFileIn.Create(FBlacklistFiles, true);
    FBlacklist := TFPHashList.Create;
    while LBlacklistReader.ReadLine(LLine)
    do FBlacklist.Add(LLine, @Dummy);
    Writeln('found: ', FBlacklist.Count, '.');
  finally
    FreeAndNil(LBlacklistReader);
  end;

  // Try to create readers/writers.
  FReader := TTrFileIn.Create(FInFiles, true);
  if FGzip
  then FWriter := TTrFileOut.Create(FOutFilePrefix, '.xml.gz', 0,
    FGzip)
  else FWriter := TTrFileOut.Create(FOutFilePrefix, '.xml', 0, FGzip);

end;


procedure TTrTeclApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;


type
  TTrTeclStatus = (
   ttsOutside,
   ttsInsideRead,
   ttsInsideDelete
  );

procedure TTrTeclApplication.DoRun;
var
  LStatus : TTrTeclStatus = ttsOutside;
  LLine : String;
  LId : String;
  LPosition : Integer;
  LRetained : Integer = 0;
  LDeleted : Integer = 0;
  LSinceLastSplit : Integer = 0;

  procedure DocumentEndActions;
  begin
    if ((LRetained + LDeleted) mod 1000 = 0)
    then Write(#13, 'Retained/deleted documents: ', LRetained, '/',
      LDeleted);

    if  (FSplit > 0)
    and (LSinceLastSplit >= FSplit)
    then begin
      FWriter.CreateNextFile;
      LSinceLastSplit := 0;
    end;
  end;

begin
  if not Terminated
  then begin

    Writeln('Processing corpus file(s).');
    while FReader.ReadLine(LLine)
    do begin

      case LStatus
      of
        ttsOutside :
        begin

          // Check whether a document begins here
          if AnsiStartsStr(DocStart, LLine)
          then begin
            LPosition := AnsiPos(' id="', LLine) + 5;
            LId := AnsiMidStr(LLine, LPosition,  DocIdLength);

            // Document matches list.
            if FBlacklist.FindIndexOf(LId) >= 0
            then begin
              if FWhitelist
              then begin
                LStatus := ttsInsideRead;
                FWriter.WriteString(LLine);
              end else begin
                LStatus := ttsInsideDelete;
              end;

            // Document does not match list.
            end else begin
              if FWhitelist
              then begin
                LStatus := ttsInsideDelete;
              end else begin
                LStatus := ttsInsideRead;

                // To enforce unique IDs, we add each written document
                // to the blacklist, so subsequent documents with the
                // same ID are deleted. (Only if the resp. modus is on.)
                if FUniqueIds
                then FBlacklist.Add(LId, @Dummy);

                FWriter.WriteString(LLine);
              end;
            end;

          end

          // Stuff outside documents is simply written.
          else FWriter.WriteString(LLine);
        end;

        ttsInsideRead :
        begin
          FWriter.WriteString(LLine);
          if AnsiStartsStr(DocEnd, LLine)
          then begin
            LStatus := ttsOutside;
            Inc(LRetained);
            Inc(LSinceLastSplit);

            // Show Activity, possibly split output.
            DocumentEndActions;
          end;
        end;

        ttsInsideDelete :
        begin
          if AnsiStartsStr(DocEnd, LLine)
          then begin
            LStatus := ttsOutside;
            Inc(LDeleted);

            // Show Activity, possibly split output.
            DocumentEndActions;
          end;
        end;
      end;
    end;
    Writeln(#13, 'Retained/deleted documents: ', LRetained, '/',
      LDeleted);

    if FWhitelist
    then Writeln(#10#13'Nigrum habemus corpus!'#10#13)
    else Writeln(#10#13'Album habemus corpus!'#10#13);

    Terminate;
  end;
end;


procedure TTrTeclApplication.ShowHelp;
begin
  Writeln(#10#13'Usage:  tender OPTIONS');
  Writeln;
  Writeln('Options without default in square brackets are obligatory.');
  Writeln;
  Writeln(' --help    -h   Print this help and exit.');
  Writeln(' --black   -b S Blacklist file name (S, wildcards allowed).');
  Writeln(' --input   -i S Input (corpus) file name pattern (S, wildcards allowed).');
  Writeln(' --output  -o S Output file name prefix (S).');
  Writeln(' --uniqids -u   Delete documents with duplicate IDs. [no]');
  Writeln(' --split   -s I Split output every I documents. [0]');
  Writeln(' --gzip    -g   Compress output with gzip. [no]');
  Writeln(' --white   -w   Interpret blacklist as whitelist. [no]');
  Writeln;
  Writeln('Note: -u (--uniqids) and -w (--white) cannot be used together.');
  Writeln;
  Writeln('Note: Enclose file name patterns with wildcards in "" or '''' in order');
  Writeln('      to keep your shell from expanding them.');
  Writeln;
end;


procedure TTrTeclApplication.SayError(const AError : String);
begin
  Writeln(#10#13, 'Error: ', AError);
  Writeln('Use tecl -h to get help.', #10#13);
  Terminate;
end;


end.
