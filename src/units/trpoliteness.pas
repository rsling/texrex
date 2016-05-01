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

unit TrPoliteness;


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
  Math,
  UriParser,
  InternetAccess,
  SynapseInternetAccess,
  IcuWrappers,
  TrUtilities;



type
  // Forward decl.
  TTrPolitenessManager = class;


  // This just stores the information about hosts. Most code goes into the
  // TTrPolitenessManager class.
  TTrHostAccessInfo = class(TObject)
  public
    constructor Create(const AManager : TTrPolitenessManager;
      const AHost : String; const ARespectRobots : Boolean);
    destructor Destroy; override;

    // Refresh robots.txt information.
    procedure Update;

    // Mark as accessed now.
    procedure MarkAsAccessed;

  private
    FManager : TTrPolitenessManager;
    FRespectRobots : Boolean;
    FHasRobots : Boolean;
    FHost : String;
    FLastAccess : Int64;         // Unix epoch.
    FLastRobotsUpdate : Int64;   // Unix epoch.
    FRobotsCrawlDelay : Int64;   // Seconds.
    FRobotsDisallows : TStringArray;
    FDirectiveIcu : TIcuRegex;
  end;



  TTrPolitenessManager = class(TPersistent)
  public
    constructor Create(const AIni : TIniFile);
    destructor Destroy; override;

    // Test for politeness interval and Robots Exclusion. Returns -1 if the
    // document should never be retrieved. If LMarkAsAccessedIfZero is true,
    // then in case the function returns 0, it will also automatically mark
    // the host as accessed now.
    function SecondsUntilRetrieval(const AUrl : String;
      const LMarkAsAccessedIfZero : Boolean = false) : Integer;

    // Call this to inform the manager that you have actually just downloaded
    // the document.
    procedure Retrieved(const AUrl : String);
  private
    FUserAgentPrefix : String;
    FMinPoliteness : Integer;
    FMaxPoliteness : Integer;
    FRespectRobots : Boolean;
    FRobotsRefreshInterval : Integer;
    FRespectRobotsCrawlDelay : Boolean;

    // For each host, we keep one TTrHostAccessInfo object.
    FHostAccessInfos : TFPHashObjectList;

    FPathExtractIcu : TIcuRegex;

    // Returns the index of the new host, whether just retrieved or added.
    // This makes sure the retrieved host is up-to-date.
    function FindOrAddHost(const AHost : String) : Integer;
  published
    property UserAgentPrefix : String read FUserAgentPrefix
      write FUserAgentPrefix;
    property MinPoliteness : Integer read FMinPoliteness write FMinPoliteness;
    property MaxPoliteness : Integer read FMaxPoliteness write FMaxPoliteness;
    property RespectRobots : Boolean read FRespectRobots write FRespectRobots;
    property RobotsRefreshInterval : Integer read FRobotsRefreshInterval
      write FRobotsRefreshInterval;
    property RespectRobotsCrawlDelay : Boolean read FRespectRobotsCrawlDelay
      write FRespectRobotsCrawlDelay;
  end;



implementation




{ *** TTrHostAccessInfo *** }



constructor TTrHostAccessInfo.Create(const AManager : TTrPolitenessManager;
  const AHost : String; const ARespectRobots : Boolean);
const
  DirectiveRegex = '^ *(User-agent|Allow|Disallow|Crawl-delay|Sitemap) *: *(|[^ ]|[^ ].*[^ ]) *$';
begin
  FManager := AManager;
  FRespectRobots := ARespectRobots;
  FHost := AHost;
  FDirectiveIcu := TIcuRegex.Create(DirectiveRegex, UREGEX_CASE_INSENSITIVE);
  FLastAccess := -1;
  FLastRobotsUpdate := -1;
  FRobotsCrawlDelay := -1;
  Update;
end;


destructor TTrHostAccessInfo.Destroy;
begin
  FreeAndNil(FDirectiveIcu);
  inherited;
end;


procedure TTrHostAccessInfo.Update;
var
  LInternetAccess : TSynapseInternetAccess;
  LData : String;
  LUrl : String;
  LRobotsLines : TStringArray;
  LDirectiveName : String;
  LDirectiveContent: String;
  i : Integer;
  LRelevantSectionOffset : Integer = -1;
begin
  // This is not a very nice implementation. However, were not going to use
  // robots.txt anyway, so I kept this to an hour's effort.

  // Only update at designated intervals.
  if (not FRespectRobots)
  or ( (FLastRobotsUpdate <> -1)
    and (TrEpoch - FLastRobotsUpdate < FManager.FRobotsRefreshInterval) )
  then Exit;

  // Request the file on http. The exeption-on-failure idea in internettools
  // is NOT good. But now where here anyway.
  LInternetAccess := TSynapseInternetAccessClass.Create();
  try
    LUrl := 'http://' + FHost + '/robots.txt';
    LData := LInternetAccess.Request('GET', LUrl, '');
    FHasRobots := true;
  except
    FHasRobots := false;
  end;

  // Request the file on https if http failed.
  if not FHasRobots
  then begin
    LInternetAccess := TSynapseInternetAccessClass.Create();
    try
      LUrl := 'https://' + FHost + '/robots.txt';
      LData := LInternetAccess.Request('GET', LUrl, '');
      FHasRobots := true;
    except
      FHasRobots := false;
    end;
  end;

  FLastRobotsUpdate := TrEpoch;
  FreeAndNil(LInternetAccess);
  if not FHasRobots
  then Exit;

  // Parse if request succeeded.
  LRobotsLines := TrExplode(LData, [#10,#13], false);

  // Step 1: Remove comments.
  for i := 0 to High(LRobotsLines)
  do begin
    if (Pos('#', LRobotsLines[i]) > 0)
    then LRobotsLines[i] := AnsiLeftStr(LRobotsLines[i],
      Pos('#', LRobotsLines[i])-1);
  end;

  // Step 2: Find the appropriate section.
  for i := 0 to High(LRobotsLines)
  do begin
    if LRobotsLines[i] = ''
    then Continue;

    // If we have found a specific section
    LDirectiveName := FDirectiveIcu.Replace(LRobotsLines[i], '$1', true, true);
    if (AnsiLowerCase(LDirectiveName) = 'user-agent')
    then begin
      LDirectiveContent := FDirectiveIcu.Replace(LRobotsLines[i], '$2' , true,
        true);

      // If we have found a perfect match, we can stop.
      // If there is a partial match, we record the position and keep searching.
      // If there is a match-all (*) section, we record the position ONLY if
      // we haven't found anything better yet (LRelevantSectionOffset = -1).
      if (FManager.UserAgentPrefix = LDirectiveContent)
      then begin
        LRelevantSectionOffset := i;
        Break;
      end else if AnsiStartsText(FManager.UserAgentPrefix, LDirectiveContent)
      then LRelevantSectionOffset := i
      else if (LDirectiveContent = '*') and (LRelevantSectionOffset = -1)
      then LRelevantSectionOffset := i;
    end;
  end;

  // Step 3: Parse the section.
  if (LRelevantSectionOffset = -1)
  then begin
    FHasRobots := false;
    Exit;
  end;

  for i := LRelevantSectionOffset + 1 to High(LRobotsLines)
  do begin
    LDirectiveName := AnsiLowerCase(FDirectiveIcu.Replace(LRobotsLines[i], '$1',
      true, true));

    // We might have reached the end of the section.
    if LDirectiveName = 'user-agent'
    then Break;

    // Use only disallow and crawl-delay.
    if LDirectiveName = 'disallow'
    then begin
      LDirectiveContent := FDirectiveIcu.Replace(LRobotsLines[i], '$2' , true,
        true);
      SetLength(FRobotsDisallows, Length(FRobotsDisallows)+1);
      FRobotsDisallows[High(FRobotsDisallows)] := LDirectiveContent;
    end

    else if LDirectiveName = 'crawl-delay'
    then begin
      LDirectiveContent := FDirectiveIcu.Replace(LRobotsLines[i], '$2' , true,
        true);
      FRobotsCrawlDelay := StrToIntDef(LDirectiveContent, -1);
    end;

  end;
end;


procedure TTrHostAccessInfo.MarkAsAccessed;
begin
  FLastAccess := TrEpoch;
end;





{ *** TTrPolitenessManager *** }


constructor TTrPolitenessManager.Create(const AIni : TIniFile);
const
  PathExtractRegex = '^https{0,1}://([^/]+)(|/.*)$';
begin
  FPathExtractIcu := TIcuRegex.Create(PathExtractRegex,
    UREGEX_CASE_INSENSITIVE);
  FHostAccessInfos := TFPHashObjectList.Create(true);
  TrReadProps(self, AIni);
end;


destructor TTrPolitenessManager.Destroy;
begin
  FreeAndNil(FPathExtractIcu);
  FreeAndNil(FHostAccessInfos);
  inherited;
end;



function TTrPolitenessManager.SecondsUntilRetrieval(const AUrl : String;
  const LMarkAsAccessedIfZero : Boolean = false) : Integer;
var
  LHostName : String;
  LPath : String;
  LHost : TTrHostAccessInfo;
  S : String;
  LAllowsAccess : Boolean;
  LInterval : Int64;
begin
  LHostName := FPathExtractIcu.Replace(AUrl, '$1', true, true);
  LHost := FHostAccessInfos[FindOrAddHost(LHostName)] as TTrHostAccessInfo;

  if FRespectRobots
  then begin
    LPath := FPathExtractIcu.Replace(AUrl, '$2', true, true);
    if LPath = ''
    then LPath := '/';
    LAllowsAccess := true;
    if LHost.FHasRobots
    then begin
      for S in LHost.FRobotsDisallows
      do if AnsiStartsStr(S, LPath)
        then LAllowsAccess := false;
    end;
  end else LAllowsAccess := true;

  // If we cannot access the document at all, just exit with -1.
  if not LAllowsAccess
  then Exit(-1);

  // If there never was an access, just go!
  if LHost.FLastAccess = -1
  then begin
    if LMarkAsAccessedIfZero
    then LHost.MarkAsAccessed;
    Exit(0);
  end;

  // How long since last access.
  LInterval := TrEpoch - LHost.FLastAccess;
  Result := Max(Max(LHost.FRobotsCrawlDelay, FMinPoliteness)-LInterval, 0);
end;



procedure TTrPolitenessManager.Retrieved(const AUrl : String);
var
  LHostName : String;
begin
  LHostName := FPathExtractIcu.Replace(AUrl, '$1', true, true);
  with FHostAccessInfos[FindOrAddHost(LHostName)] as TTrHostAccessInfo
  do MarkAsAccessed;
end;


function TTrPolitenessManager.FindOrAddHost(const AHost : String) : Integer;
var
  LHostInfo : TTrHostAccessInfo = nil;
begin

  // Create updates the info, and in case this host is already known, we call
  // update manually at the end.
  Result := FHostAccessInfos.FindIndexOf(AHost);
  if Result = (-1)
  then begin
    LHostInfo := TTrHostAccessInfo.Create(self, AHost, FRespectRobots);
    Result := FHostAccessInfos.Add(AHost, LHostInfo);
  end
  else (FHostAccessInfos[Result] as TTrHostAccessInfo).Update;
end;



end.
