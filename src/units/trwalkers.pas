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

unit TrWalkers;


{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  IniFiles,
  SysUtils,
  Classes,
  Contnrs,
  StrUtils,
  DateUtils,
  Math,
  UriParser,
  InternetAccess,
  SynapseInternetAccess,
  IcuWrappers,
  TrBloom,
  TrPoliteness,
  TrUtilities,
  TrData,
  TrFile,
  TrDocumentProcessor,
  TrHtmlStripper,
  TrGeolocator,
  TrDuplicateDetector,
  TrCharsetConverter,
  TrSecondPass,
  TrUtf8Validator,
  TrDeboilerplater,
  TrSimpleDocumentFilter,
  TrUnicodeLetterRangeTokenizer,
  TrRabinHash,
  TrShingler,
  TrTextAssessment,
  TrNormalizer,
  TrDivDeduplicator,
  TrMetaExtractor,
  TrNfcNormalizer,
  TrWriteTools;


const
  TrWalkerClassNames : array[0..0] of String = ( 'TTrWalker' );


type
  ETrWalker = class(Exception);

  TTrReport = procedure(const AMessage : String;
    const ASuppressLf : Boolean = false) of object;


  TTrDocumentCache = class(TObject)
  public
    constructor Create(const ASize : Integer);
    destructor Destroy; override;
    procedure Cache(const AUrl : String; const ADocument : TTrDocument);
    function Retrieve(const AUrl : String) : TTrDocument;
  private
    FSize : Integer;
    FCache : TFPHashObjectList;
    procedure Cleanup(Data : TObject; Arg : Pointer);
  end;



  TTrWalkStep = class(TObject)
  public
    constructor Create(const AUrl : String; const AHost : String;
      const AId : String);
    destructor Destroy; override;

    // Returns a link and removes it from the list of links. Makes backtracking
    // in the random walk process easy. Returns empty string when no links are
    // left.
    function PopRandomLink : String;
    procedure AddLink(const ALink : String);
  private
    FUrl : String;
    FHost : String;
    FId : String;
    FAccessTime : Int64;
    FLinks : TStringList;
    FMaxLinkNumber : Integer;
  public
    property Url : String read FUrl;
    property Id : String read FId;
    property Host : String read FHost;
    property AccessTime : Int64 read FAccessTime;
    property MaxLinkNumber : Integer read FMaxLinkNumber;
  end;


  TTrWalker = class(TPersistent)
  public
    constructor Create(AIni : TIniFile; const AReport : TTrReport);
    destructor Destroy; override;

    // Ideally, these two will be all that descendants need to implement.
    procedure Run; virtual;
    class function ClassName : String; virtual;
  private
    FIni : TIniFile;
    FUserAgent : String;
    FTimeout : Integer;
    FRandomJumpProbability : Real;
    FSeedsFile : String;
    FSeedsList : TStringList;
    FPrefix : String;
    FHostScopeRegex : String;
    FBlockFileRegex : String;

    FMaxSteps : Integer;

    FBacktrackOnDeadEnd : Boolean;
    FJumpOnDeadEnd : Boolean;
    FRespectMetaRobotsNoIndex : Boolean;
    FRespectMetaRobotsNoFollow : Boolean;
    FAddRandomWaitUpTo : Integer;

    FUseSameHostLinks : Boolean;
    FUseSameVirtualHostLinks : Boolean;
    FUseExternalLinks : Boolean;

    // For internettools.
    FInternetAccess : TSynapseInternetAccess;
    FInternetConfig : TInternetConfig;
    FRequestsSinceRestart : Integer;

    // For keeping some documents cached for insanely circular walk segments.
    FCache : TTrDocumentCache;
    FCacheSize : Integer;

    FBloom : TTrScalingBloomFilter;

    // For being nice.
    FPolitenessManager : TTrPolitenessManager;

    // Output modules.
    FLogger : TTrFileOut;
    FDumper : TTrFileOut;
    FTarcWriter : TTrFileOut;
    FXmlWriter : TTrFileOut;
    FLinkWriter : TTrFileOut;
    FShingleWriter : TTrFileOut;

    // Processor switches.
    FUseDeboilerplater : Boolean;
    FUseTextAssessment : Boolean;
    FUseShingler : Boolean;
    FUseNormalizer : Boolean;
    FUseNfcNormalizer : Boolean;
    FUseDivDeduplicator : Boolean;
    FUseMetaExtractor : Boolean;
    FUseGeolocator : Boolean;
    FGeoBlocksFile : String;
    FGeoLocationsFile : String;

    // The processors.
    FUnicodeLetterRangeTokenizer : TTrUnicodeLetterRangeTokenizer;
    FStripper : TTrHtmlStripper;
    FCharsetConverter : TTrCharsetConverter;
    FSimpleDocumentFilter : TTrSimpleDocumentFilter;
    FSecondPass : TTrSecondPass;
    FUtf8Validator : TTrUtf8Validator;
    FDeboilerplater : TTrDeboilerplater;
    FTextAssessment : TTrTextAssessment;
    FShingler : TTrShingler;
    FNormalizer : TTrNormalizer;
    FNfcNormalizer : TTrNfcNormalizer;
    FDivDeduplicator : TTrDivDeduplicator;
    FMetaExtractor : TTrMetaExtractor;
    FGeolocator : TTrGeolocator;

    // Output configuration.
    FWriteDocContainer : TStringArray;
    FWriteDocMeta : TStringArray;
    FWriteDivMeta : TStringArray;
    FWriteDocAttr : TStringArray;
    FWriteDivAttr : TStringArray;
    FWriteDups : Boolean;
    FDupBlank : String;

    FHeaderEncodingIcu : TIcuRegex;
    FHostScopeIcu : TIcuRegex;
    FBlockFileIcu : TIcuRegex;

    Report : TTrReport;

    // Gets a random seed from the seed pool.
    function FetchSeed : String;

    // Download from HTTP and turn into document.
    function Fetch(const AUrl : String; out ADocument : TTrDocument;
      out AHttpStatus : Integer) : Boolean;

    // texrex post-processing. Includes Link extraction.
    function Process(const ADocument : TTrDocument) : String;

    // Some of the finalize functionality refactored into an extra function.
    function MakeStep(const AUrl : String; const ADocument : TTrDocument) :
      TTrWalkStep;

    // Processes and writes a document to disk. The document is freed an nild.
    // Returns data structure for walk stack.
    function Finalize(const AUrl : String; ADocument : TTrDocument) :
      TTrWalkStep;

    // Performs a straightforward random walk, gathering statistics. Is used
    // by Henziger and Rusmevichientong algorithms.
    procedure Walk(const AMaxSteps : Integer;
      const AAllowRandomJumps : Boolean);
    procedure Log(AMessage: String; ATab : Boolean = true;
      ALineFeed: Boolean = false);

    // Write to output files.
    procedure WriteDocumentXml(ADocument : TTrDocument); virtual; abstract;
    procedure WriteDocumentLinks(ADocument : TTrDocument); virtual; abstract;
    procedure WriteDocumentWarc(ADocument : TTrDocument); virtual; abstract;

    procedure SetSeedsFile(const AFile : String);
    procedure SetHostScopeRegex(const ARegex : String);
    procedure SetBlockFileRegex(const ARegex : String);
    procedure SetUserAgent(const AUserAgent : String);
    function GetDocContainer : String;
    procedure SetDocContainer(const AContainers : String);
    function GetDocMeta : String;
    procedure SetDocMeta(const AMeta : String);
    function GetDivMeta : String;
    procedure SetDivMeta(const AMeta : String);
    function GetDocAttr : String;
    procedure SetDocAttr(const AAttr : String);
    function GetDivAttr : String;
    procedure SetDivAttr(const AAttr : String);
  published
    property UserAgent : String read FUserAgent write SetUserAgent;
    property Timeout : Integer read FTimeout write FTimeout;
    property MaxSteps : Integer read FMaxSteps write FMaxSteps;
    property CacheSize : Integer read FCacheSize write FCacheSize;

    property RandomJumpProbability : Real read FRandomJumpProbability
      write FRandomJumpProbability;
    property SeedsFile : String read FSeedsFile write SetSeedsFile;

    property HostScopeRegex : String read FHostScopeRegex
      write SetHostScopeRegex;
    property BlockFileRegex : String read FBlockFileRegex
      write SetBlockFileRegex;

    property Prefix : String read FPrefix write FPrefix;
    property BacktrackOnDeadEnd : Boolean read FBacktrackOnDeadEnd
      write FBacktrackOnDeadEnd default true;
    property JumpOnDeadEnd : Boolean read FJumpOnDeadEnd
      write FJumpOnDeadEnd default true;
    property RespectMetaRobotsNoIndex : Boolean read FRespectMetaRobotsNoIndex
      write FRespectMetaRobotsNoIndex;
    property RespectMetaRobotsNoFollow : Boolean read FRespectMetaRobotsNoFollow
      write FRespectMetaRobotsNoFollow;
    property AddRandomWaitUpTo : Integer read FAddRandomWaitUpTo
      write FAddRandomWaitUpTo;

   property UseSameHostLinks : Boolean read FUseSameHostLinks
     write FUseSameHostLinks default true;
   property UseSameVirtualHostLinks : Boolean read FUseSameVirtualHostLinks
     write FUseSameVirtualHostLinks default false;
   property UseExternalLinks : Boolean read FUseExternalLinks
     write FUseExternalLinks default true;

    property UseDeboilerplater : Boolean read FUseDeboilerplater
      write FUseDeboilerplater default true;
    property UseTextAssessment : Boolean read FUseTextAssessment
      write FUseTextAssessment default true;
    property UseShingler : Boolean read FUseShingler write FUseShingler
      default true;
    property UseNormalizer : Boolean read FUseNormalizer write FUseNormalizer
      default true;
    property UseNfcNormalizer : Boolean read FUseNfcNormalizer
      write FUseNfcNormalizer default true;
    property UseDivDeduplicator : Boolean read FUseDivDeduplicator
      write FUseDivDeduplicator default true;
    property UseMetaExtractor : Boolean read FUseMetaExtractor
      write FUseMetaExtractor default true;
    property UseGeolocator : Boolean read FUseGeolocator write FUseGeolocator
      default true;
    property GeoBlocksFile : String read FGeoBlocksFile write FGeoBlocksFile;
    property GeoLocationsFile : String read FGeoLocationsFile
      write FGeoLocationsFile;

    property WriteDocContainer : String read GetDocContainer
      write SetDocContainer;
    property WriteDocMeta : String read GetDocMeta write SetDocMeta;
    property WriteDivMeta : String read GetDivMeta write SetDivMeta;
    property WriteDocAttr : String read GetDocAttr write SetDocAttr;
    property WriteDivAttr : String read GetDivAttr write SetDivAttr;
    property WriteDups : Boolean read FWriteDups write FWriteDups
      default true;
    property DupBlank : String read FDupBlank write FDupBlank;
  end;
  TTrWalkerClass = class of TTrWalker;




function GetWalkerClass(const AName : String) : TTrWalkerClass;



implementation



{ *** TTrDocumentCache *** }


constructor TTrDocumentCache.Create(const ASize : Integer);
begin

  // Avoid asinine cache sizes leading to access violations.
  FSize := Max(2, ASize);
  FCache := TFPHashObjectList.Create(false);
end;


destructor TTrDocumentCache.Destroy;
begin
  FCache.ForEachCall(@Cleanup, nil);
  FreeAndNil(FCache);
  inherited;
end;


procedure TTrDocumentCache.Cache(const AUrl : String;
  const ADocument : TTrDocument);
begin

  // First see if we need to make room.
  if FCache.Count > FSize
  then begin

    // If cache is fragmented at 0, clean up.
    if not Assigned(FCache[0])
    then FCache.Pack;

    (FCache[0] as TTrDocument).Free;
    FCache.Delete(0);
  end;

  // Then add.
  FCache.Add(AUrl, ADocument);
end;


function TTrDocumentCache.Retrieve(const AUrl : String) : TTrDocument;
begin
  Result := FCache.Find(AUrl) as TTrDocument;
end;


procedure TTrDocumentCache.Cleanup(Data : TObject; Arg : Pointer);
begin
  FreeAndNil(Data);
end;



{ *** TTrWalkStep *** }



constructor TTrWalkStep.Create(const AUrl : String; const AHost : String;
  const AId : String);
begin
  FUrl := AUrl;
  FHost := AHost;
  FId := AId;
  FAccessTime := TrEpoch;
  FLinks := TStringList.Create;
  FLinks.Duplicates := dupIgnore;
  FMaxLinkNumber := 0;
end;


destructor TTrWalkStep.Destroy;
begin
  if Assigned(FLinks)
  then FLinks.Clear;
  FreeAndNil(FLinks);
  inherited;
end;


function TTrWalkStep.PopRandomLink : String;
var
  i : Integer;
begin
  if FLinks.Count < 1
  then Exit('');
  i := Random(FLinks.Count);
  Result := FLinks[i];
  FLinks.Delete(i);
end;


procedure TTrWalkStep.AddLink(const ALink : String);
begin
  FLinks.Add(ALink);
  Inc(FMaxLinkNumber);
end;


{ *** TTrWalker *** }



constructor TTrWalker.Create(AIni : TIniFile; const AReport : TTrReport);
const
  HeaderEncoding  : Utf8String = '^.*charset=([-0-9A-Za-z]+)(?:$|,|;| )';
begin
  TrAssert(Assigned(AReport), 'Valid report function was passed.');
  Report := AReport;
  TrAssert(Assigned(AIni), 'Valid INI object was passed.');
  FIni := AIni;

  Report('Initializing random walker (' + self.ClassName +').');

  FHeaderEncodingIcu := TIcuRegex.Create(HeaderEncoding,
    UREGEX_CASE_INSENSITIVE);

  // The INI section must be named after the non-abstract descendant!
  TrReadProps(self, FIni);

  // Most of this is not settable by design. Would be easy to change, though.
  with FInternetConfig
  do begin
    UserAgent := '';
    TryDefaultConfig := false;
    UseProxy := false;
    ProxyHTTPName := '';
    ProxyHTTPPort := '';
    ProxyHTTPSName := '';
    ProxyHTTPSPort := '';
    ProxySOCKSName := '';
    ProxySOCKSPort := '';
    ConnectionCheckPage := 'http://google.com/';
    CheckSSLCertificates := false;
    LogToPath := '';
  end;

  // Init and stream the politeness manager.
  FPolitenessManager := TTrPolitenessManager.Create(FIni);

  FBloom := TTrScalingBloomFilter.Create(0.000001);

  // Create cache if desired.
  if FCacheSize > 0
  then FCache := TTrDocumentCache.Create(FCacheSize);

  // Init the output modules.
  FLogger := TTrFileOut.Create(FPrefix, '.log', 0, false);
  FDumper := TTrFileOut.Create(FPrefix, '.walk', 0, false);
  FTarcWriter := TTrFileOut.Create(FPrefix, '.tarc.gz', 0, true);
  FXmlWriter := TTrFileOut.Create(FPrefix, '.xml.gz', 0, true);
  FLinkWriter := TTrFileOut.Create(FPrefix, '.links.gz', 0, true);
  FShingleWriter := TTrFileOut.Create(FPrefix, '.shingles.gz', 0, true);

  // Open the internet connection.
//  FInternetAccess := TSynapseInternetAccessClass.Create();
//  FInternetAccess.InternetConfig := @FInternetConfig;
  FRequestsSinceRestart := 10000;

  // Init the processors.
  if FUseShingler or FUseTextAssessment
  then FUnicodeLetterRangeTokenizer :=
    TTrUnicodeLetterRangeTokenizer.Create(FIni);
  FStripper := TTrHtmlStripper.Create(FIni);
  FCharsetConverter := TTrCharsetConverter.Create(FIni);
  FSimpleDocumentFilter := TTrSimpleDocumentFilter.Create(FIni);
  FSecondPass := TTrSecondPass.Create(FIni);
  FUtf8Validator := TTrUtf8Validator.Create(FIni);
  if FUseDeboilerplater
  then FDeboilerplater := TTrDeboilerplater.Create(FIni);
  if FUseTextAssessment
  then FTextAssessment := TTrTextAssessment.Create(FIni);
  if FUseShingler
  then FShingler := TTrShingler.Create(FIni);
  if FUseNormalizer
  then FNormalizer := TTrNormalizer.Create(FIni);
  if FUseNfcNormalizer
  then FNfcNormalizer := TTrNfcNormalizer.Create(FIni);
  if FUseDivDeduplicator
  then begin
    TrInitDivDeduplicator;
    FDivDeduplicator := TTrDivDeduplicator.Create(FIni);
  end;
  if FUseMetaExtractor
  then FMetaExtractor := TTrMetaExtractor.Create(FIni);
  if FUseGeolocator
  then begin
    Report('Initializing geolocation database (might take a while).');
    TrInitGeodata(FGeoBlocksFile, FGeoLocationsFile);
    FGeolocator := TTrGeolocator.Create(FIni);
  end;
end;


destructor TTrWalker.Destroy;
begin
  if FCacheSize > 0
  then FreeAndNil(FCache);
  FreeAndNil(FBloom);
  FreeAndNil(FPolitenessManager);
  FreeAndNil(FUtf8Validator);
  FreeAndNil(FDeboilerplater);
  FreeAndNil(FTextAssessment);
  FreeAndNil(FShingler);
  FreeAndNil(FNormalizer);
  FreeAndNil(FNfcNormalizer);
  FreeAndNil(FDivDeduplicator);
  FreeAndNil(FMetaExtractor);
  FreeAndNil(FGeolocator);
  FreeAndNil(FStripper);
  FreeAndNil(FCharsetConverter);
  FreeAndNil(FSimpleDocumentFilter);
  FreeAndNil(FSecondPass);
  FreeAndNil(FUnicodeLetterRangeTokenizer);
  FreeAndNil(FInternetAccess);
  FreeAndNil(FHeaderEncodingIcu);
  FreeAndNil(FBlockFileIcu);
  FreeAndNil(FHostScopeIcu);
  if Assigned(FSeedsList)
  then FSeedsList.Clear;
  FreeAndNil(FSeedsList);
  FreeAndNil(FLogger);
  FreeAndNil(FDumper);
  FreeAndNil(FTarcWriter);
  FreeAndNil(FXmlWriter);
  FreeAndNil(FLinkWriter);
  FreeAndNil(FShingleWriter);
  inherited;
end;


class function TTrWalker.ClassName : String;
begin
  Result := 'TTrWalker';
end;

procedure TTrWalker.Run;
begin
  Report('Starting plain random walk.');
  Walk(FMaxSteps, true);
end;


procedure TTrWalker.Log(AMessage: String; ATab : Boolean = true;
  ALineFeed: Boolean = false);
begin
  FLogger.WriteString(AMessage);
end;

function TTrWalker.FetchSeed : String;
var
  i : Integer;
begin
  if (not Assigned(FSeedsList))
  or (FSeedsList.Count < 1)
  then raise ETrWalker.Create('Seed list starved.');

  i := Random(FSeedsList.Count);
  Result := FSeedsList[i];
  FSeedsList.Delete(i);
end;


function TTrWalker.Fetch(const AUrl : String; out ADocument : TTrDocument;
  out AHttpStatus : Integer) : Boolean;
var
  LData : String;
  LMetaExtract : String;
  LWaitSeconds : Integer;
  LTime : Integer = 0;
  LCursorState : Char = #124;
begin

  // For some reason, we need to do this to keep the internet access alive.
  if FRequestsSinceRestart > 20
  then begin
    FreeAndNil(FInternetAccess);
    FInternetAccess := TSynapseInternetAccessClass.Create();
    FInternetAccess.InternetConfig := @FInternetConfig;
    FInternetAccess.SetTimeout(FTimeout);
    FRequestsSinceRestart := 1;
  end
  else Inc(FRequestsSinceRestart);

  // Be polite.
  LWaitSeconds := FPolitenessManager.SecondsUntilRetrieval(AUrl);

  // Always log politeness seconds.
  Log('Wait     = ' + IntToStr(LWaitSeconds));

  if LWaitSeconds < 0
  then Exit(false)
  else begin
    if AddRandomWaitUpTo > 0
    then LWaitSeconds := LWaitSeconds + Random(AddRandomWaitUpTo);
    if LWaitSeconds > 0
    then Report('[pol. ' + IntToStr(LWaitSeconds) + 's] ', true);
    Sleep(LWaitSeconds * 1000);
  end;

  // Actual download.
  try
    LData := FInternetAccess.Request('GET', AUrl, '');
  except
    ADocument := nil;
    Exit(false);
  end;

  Report(IntToStr(FInternetAccess.LastHTTPResultCode), true);

  // Tell politeness manager that we have requested the document.
  FPolitenessManager.Retrieved(AUrl);

  // Executed only on success:
  AHttpStatus := FInternetAccess.LastHTTPResultCode;
  Result := true;
  ADocument := TTrDocument.Create;
  with ADocument
  do begin
    Ip := FInternetAccess.LastIp;
    Url := FInternetAccess.LastUrl;

    // Extract original charset.
    LMetaExtract := FInternetAccess.GetLastHTTPHeader('Content-type');
    if Length(LMetaExtract) > 0
    then begin
      try
        LMetaExtract := FHeaderEncodingIcu.Replace(LMetaExtract, '$1');
        ADocument.SourceCharset := LMetaExtract;
      except
        ADocument.SourceCharset := '';
      end;
    end;

    // Extract date, last-modified, content size.
    LMetaExtract := FInternetAccess.GetLastHTTPHeader('Date');
    if Length(LMetaExtract) > 0
    then AddMeta('date', LMetaExtract);

    LMetaExtract := FInternetAccess.GetLastHTTPHeader('Last-modified');
    if Length(LMetaExtract) > 0
    then AddMeta('last-modified', LMetaExtract);

    if (FInternetAccess.LastUrl = AUrl)
    then AddMeta('redirect-from', 'none')
    else AddMeta('redirect-from', AUrl);

    FInternetAccess.LastHTTPHeaders.TextLineBreakStyle := tlbsLF;
    AddRawLine(FInternetAccess.LastHTTPHeaders.Text);
    AddRawLine(LData);
  end;
end;


function TTrWalker.Process(const ADocument : TTrDocument) : String;

  function TryProc(const AProc : TTrDocProc; const ADocument : TTrDocument) :
    Boolean; inline;
  begin
    Result := true;
    try
      AProc(ADocument);
    except
      Result := false;
      ADocument.Valid := false;
    end;
  end;

var
  LMetaExtract : String;
begin
  Result := '';
  if not TryProc(@FStripper.Process, ADocument)
  then Exit('TTrStripper');

  if not TryProc(@FCharsetConverter.Process, ADocument)
  then Exit('TTrCharsetConverter');

  if FUseMetaExtractor
  then if not TryProc(@FMetaExtractor.Process, ADocument)
    then Exit('TTrMetaExtractor');

  if not TryProc(@FSecondPass.Process, ADocument)
  then Exit('TTrSecondPass');
  if not TryProc(@FUtf8Validator.Process, ADocument)
  then Exit('TTrUtf8Validator');

  if FUseDeboilerplater
  then if not TryProc(@FDeboilerplater.Process, ADocument)
    then Exit('TTrDeboilerplater');

  if FUseShingler or FUseTextAssessment
  then if not TryProc(@FUnicodeLetterRangeTokenizer.Process, ADocument)
    then Exit('TTrUnicodeLetterRangeTokenizer');

  if FUseTextAssessment
  then if not TryProc(@FTextAssessment.Process, ADocument)
    then Exit('TTrTextAssessment');

  if FUseShingler
  then if not TryProc(@FShingler.Process, ADocument)
    then Exit('TTrShingler');

  if FUseNormalizer
  then if not TryProc(@FNormalizer.Process, ADocument)
    then Exit('TTrNormalizer');

  if FUseNfcNormalizer
  then if not TryProc(@FNfcNormalizer.Process, ADocument)
    then Exit('TTrNfcNormalizer');

  if FUseDivDeduplicator
  then if not TryProc(@FDivDeduplicator.Process, ADocument)
    then Exit('TTrDivDeduplicator');

  if FUseGeolocator
  then if not TryProc(@FGeolocator.Process, ADocument)
    then Exit('TTrGeolocator');

  // Extract these after all processors have done their work or hosts with
  // www will become urlblank.
  LMetaExtract := TrExtractHost(ADocument.Url);
  ADocument.AddMeta('host', LMetaExtract);
  LMetaExtract := TrExtractTld(LMetaExtract);
  ADocument.AddMeta('tld', LMetaExtract);
end;


function TTrWalker.MakeStep(const AUrl : String;
  const ADocument : TTrDocument) : TTrWalkStep;
var
  i : Integer;
  LLink : String;
  LUri : TUri;
  LLinkDecomposed : TStringArray;
begin

  // We record the information relevant for the walk in a TTrWalkStep data
  // structure.
  Result := TTrWalkStep.Create(AUrl, ADocument.GetMetaByKey('host'),
    ADocument.Id);

  // Extract all links and add to walk step for next step random link selection.
  for i := 0 to ADocument.Number-1
  do begin
    if Assigned(ADocument[i])
    then for LLink in ADocument[i].Links
    do begin

      // A bit of a clumsy workaround not to mess up texrex too much. We parse
      // the string instead of really passing on the single values.
      LLinkDecomposed := TrExplode(LLink, [#9]);
      if Length(LLinkDecomposed) <> 2
      then Report(' malformed URL structure: ' + LLink);

      // Decide whether the link should be used.
      if ( (LLinkDecomposed[1]='trlDifferentHosts') and (FUseExternalLinks) )
      or ( (LLinkDecomposed[1]='trlSameFullHost') and (FUseSameVirtualHostLinks) )
      or ( (LLinkDecomposed[1]='trlSameNonVirtualHost') and (FUseSameHostLinks) )
      then begin

        // Some conditions should be met before we add link to candidates.
        LUri := ParseUri(LLinkDecomposed[0]);
        try
          if ( (LUri.Protocol = 'http') or (LUri.Protocol = 'https') )
          and FHostScopeIcu.Match(LUri.Host, true, true)
          and not FBlockFileIcu.Match(LUri.Document, true, true)
          then Result.AddLink(LLinkDecomposed[0]);
        except
          Report(' malformed URL', true);
        end;

      end;
    end;
  end;
  Report(' ' + IntToStr(Result.MaxLinkNumber) + ' links', true);
  Log('Links    = ' + IntToStr(Result.MaxLinkNumber));
end;


function TTrWalker.Finalize(const AUrl : String; ADocument : TTrDocument) :
  TTrWalkStep;
begin

  // Write everything to disk if not already done.
  if not FBloom.Check(AUrl)
  then begin
    TrWriteShingles(ADocument, FShingleWriter, 0);
    TrWriteLinks(ADocument, FLinkWriter, 0, false);
    TrWriteTarc(ADocument, FTarcWriter, 0);
    TrWriteXmlDoc(ADocument, FWriteDocAttr, FWriteDocMeta,
      FWriteDocContainer, FWriteDivAttr, FWriteDivMeta, FWriteDups, FDupBlank,
      false, true, FXmlWriter, 0);
    FBloom.Add(AUrl);
    Log('Seen     = 0');
  end
  else begin
    Report(' REVISIT ', true);
    Log('Seen     = 1');
  end;

  Result := MakeStep(AUrl, ADocument);

  // Instead of destroying the document, we put it on the cache.
if FCacheSize > 0
then begin
  FCache.Cache(AUrl, ADocument);
  ADocument := nil;
end else FreeAndNil(ADocument);
end;


// This proc implements a stack version of backtracking.
procedure TTrWalker.Walk(const AMaxSteps : Integer;
  const AAllowRandomJumps : Boolean);
var
  LStack : TObjectStack = nil;
  LStep : TTrWalkStep;
  LNextLink : String;

  // Fetch a document, process it, and put it as a node on the stack.
  procedure Step(const AUrl : String); inline;
  var
    LHttpStatus : Integer;
    LDocument : TTrDocument = nil;
    LProcessError : String;
  begin
    Report('[ ' + TrPad(10, IntToStr(LStack.Count)) + ' ] ' +
      TrExtractHost(AUrl) + ' ', true);
    Log('');
    Log('Epoch    = ' + IntToStr(DateTimeToUnix(Now)));
    Log('Step     = ' + TrPad(10, IntToStr(LStack.Count)));
    Log('Host     = ' + TrExtractHost(AUrl));
    Log('Url      = ' + AUrl);

    // First, look in cache.
    if FCacheSize > 0
    then LDocument := FCache.Retrieve(AUrl)
    else LDocument := nil;

    if Assigned(LDocument)
    then begin
      Report('from-cache', true);
      Log('Http     = cached');
      Log('Process  = valid');
      LStep := MakeStep(AUrl, LDocument);
      LStack.Push(LStep);
      LStep := nil;
    end

    else if Fetch(AUrl, LDocument, LHttpStatus)
    then begin
      Log('Http     = ' + IntToStr(LHttpStatus));
      LProcessError := Process(LDocument);
      if (LProcessError <> '')
      or not LDocument.Valid
      then begin
        FreeAndNil(LDocument);
        Report(' invalid', true);
        Log('Process  = invalid');
        if LProcessError <> ''
        then Report(' (' + LProcessError + ')', true);
      end
      else begin
        Report(' valid', true);
        Log('Process  = valid');
        LStep := Finalize(AUrl, LDocument);
        Log('Id       = ' + LStep.Id);
        LStack.Push(LStep);
        LStep := nil;
      end;
    end
    else begin
      Report(' fail', true);
      Log('Http     = error');
      Log('Process  = unknown');
    end;
    Report('');
  end;

begin

  // Create stack and put first item on it.
  LStack := TObjectStack.Create;
  Step(FetchSeed);

  // We walk until we have reached max number steps or until the stack is empty
  // (= we cannot make as many steps from seed as desired).
  while (LStack.Count < AMaxSteps)
  and ( (LStack.Count > 0) or not FBacktrackOnDeadEnd )
  do begin

    // Select next step either as random jump or by using the links of the
    // top step on the stack
    if AAllowRandomJumps
    and (Random < FRandomJumpProbability)
    then begin
      Report('^ Random Jmp');
      Log('Follow   = randomjump');
      LNextLink := FetchSeed;
    end else begin
      LStep := LStack.Peek as TTrWalkStep;
      if Assigned(LStep)
      then LNextLink := LStep.PopRandomLink
      else LNextLink := '';
    end;

    // If there is no next step from here, backtrack – or fail if backtracking
    // is not desired.
    if LNextLink = ''
    then begin

        if FJumpOnDeadEnd
        then begin
          Report('! Forced Jmp');
          Log('Follow   = forcedjump');
          LNextLink := FetchSeed;
          Step(LNextLink);
        end else if FBacktrackOnDeadEnd
        then begin
          Report('< Backtrack');
          Log('Follow   = backtrack');
          LStep := LStack.Pop as TTrWalkStep;
          FreeAndNil(LStep);
        end
        else begin
          Break;
          Log('Follow   = exhausted');
        end

    end
    else begin
      Log('Follow   = step');
      Step(LNextLink);
    end;
  end;
  Report('');

  // Save walk stack and clean up.
  LStep := nil;
  LStep := LStack.Pop as TTrWalkStep;
  while Assigned(LStep)
  do begin
    with LStep do begin
      FDumper.WriteString(Url + #9 + Id + #9 + Host + #9 +
        IntToStr(AccessTime) + #9 + IntToStr(MaxLinkNumber));
    end;
    FreeAndNil(LStep);
    LStep := LStack.Pop as TTrWalkStep;
  end;
  FreeAndNil(LStack);
end;


procedure TTrWalker.SetSeedsFile(const AFile : String);
begin
  FSeedsFile := AFile;

  if not TrFindFile(FSeedsFile)
  then raise ETrWalker.Create('Seeds file not found.');

  if not Assigned(FSeedsList)
  then FSeedsList := TStringList.Create;
  FSeedsList.LoadFromFile(FSeedsFile);
end;


procedure TTrWalker.SetUserAgent(const AUserAgent : String);
begin
  FUserAgent := AUserAgent;
  FInternetConfig.UserAgent := FUserAgent;
end;


procedure TTrWalker.SetHostScopeRegex(const ARegex : String);
begin
  FHostScopeRegex := ARegex;
  FreeAndNil(FHostScopeIcu);
  FHostScopeIcu := TIcuRegex.Create(FHostScopeRegex);
end;


procedure TTrWalker.SetBlockFileRegex(const ARegex : String);
begin
  FBlockFileRegex := ARegex;
  FreeAndNil(FBlockFileIcu);
  FBlockFileIcu := TIcuRegex.Create(FBlockFileRegex);
end;


function TTrWalker.GetDocMeta : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDocMeta)
  do Result += FWriteDocMeta[i];
end;


procedure TTrWalker.SetDocMeta(const AMeta : String);
begin
  FWriteDocMeta := TrExplode(AMeta, ['|']);
end;


function TTrWalker.GetDocContainer : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDocContainer)
  do Result += FWriteDocContainer[i];
end;


procedure TTrWalker.SetDocContainer(const AContainers : String);
begin
  FWriteDocContainer := TrExplode(AContainers, ['|']);
end;


function TTrWalker.GetDivMeta : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDivMeta)
  do Result += FWriteDivMeta[i];
end;


procedure TTrWalker.SetDivMeta(const AMeta : String);
begin
  FWriteDivMeta := TrExplode(AMeta, ['|']);
end;


function TTrWalker.GetDocAttr : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDocAttr)
  do Result += FWriteDocAttr[i];
end;


procedure TTrWalker.SetDocAttr(const AAttr : String);
begin
  FWriteDocAttr := TrExplode(AAttr, ['|']);
end;


function TTrWalker.GetDivAttr : String;
var
  i : Integer;
begin
  Result := '';
  for i := 0 to High(FWriteDivAttr)
  do Result += FWriteDivAttr[i];
end;


procedure TTrWalker.SetDivAttr(const AAttr : String);
begin
  FWriteDivAttr := TrExplode(AAttr, ['|']);
end;


{ *** Procedural *** }



function GetWalkerClass(const AName : String) : TTrWalkerClass;
begin
  case AName of
    'TTrWalker' : Result := TTrWalker;
  else
    Result := nil;
  end;
end;



initialization


end.
