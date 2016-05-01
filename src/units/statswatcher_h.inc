  TTrStatsWatcher = class(TThread)
  public
    constructor Create(const AApplication : TTrApplication);
      overload;
    destructor Destroy; override;
  protected
    FApplication : TTrApplication;
    FLastCheckTime : TDateTime;
    FStatsWriter : TTrFileOut;

    // Last calculated stats.
    FTime         : TDateTime;
    FSecsUpNow    : QWord;
    FReaders      : Integer;
    FWorkers      : Integer;
    FWriters      : Integer;
    FDocsRead     : QWord;
    FDocsRPerSec  : Integer;
    FBRead        : QWord;
    FBRPerSec     : Integer;
    FDocsWritten  : QWord;
    FDocsWPerSec  : Integer;
    FDocRatio     : Real;
    FBWritten     : QWord;
    FBWPerSec     : Integer;
    FBRatio       : Real;
    FLinks        : QWord;
    FAvgLinksPDoc : Real;
    FFilesTotal   : QWord;
    FFilesDone    : QWord;
    FAvgDocBad    : Real;
    FLowestBad    : Real;
    FHighestBad   : Real;
    FAvgTokC      : Real;
    FLowestTokC   : Integer;
    FHighestTokC  : Integer;

    FInvStripper : QWord;
    FInvDupDet : QWord;
    FInvCharConv : QWord;
    FInv2Pass : QWord;
    FInvUtf8Val : QWord;
    FInvDocFilt : QWord;
    FInvDeboiler : QWord;
    FInvTokenizer : QWord;
    FInvTAss : QWord;
    FInvShingler : QWord;
    FInvNorm : QWord;
    FInvGeoloc : QWord;

    procedure Execute; override;
  end;
