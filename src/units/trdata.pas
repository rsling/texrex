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


unit TrData;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  Classes,
  Contnrs,
  SysUtils,
  StrUtils,
  TypInfo,
  Md5,
  Math,
  Fann,
  IcuWrappers,
  TrUtilities;



type

  ETrData = class(Exception);

  // A type is a word form string plus its frequency in a text.
  TTrType = record
    TypeString : String;
    Tokens : Integer;
    Frequency : Extended;
  end;
  PTrType = ^TTrType;


  TTrTypeTokenData = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;

    // Adds a token to the sequence and updates the type/token
    // frequencies.
    procedure AddToken(AToken : String);

    // Sorts the list alphabetically by type.
    procedure SortTypesByType;

    // Sorts the list by token frequency.
    procedure SortTypesByFrequency;

    function Item(AIndex : Integer) : PTrType;
    function Item(AType : String) : PTrType;

    // Update relative token frequencies.
    procedure UpdateTypes;

    // Emits a deep copy of self.
    function Clone : TTrTypeTokenData;
  protected

    // The raw token sequence.
    FTokenSequence : TStringArray;
    FAlphaSorted : Boolean;

    // The type-token counter structure.
    FTypeList : TFPList;
    function GetTypeCount : Integer;
    procedure FreeAll;

    // Finds the index of a type in the list. If not found, returns
    // nearest position (e.g., for insert).
    procedure FindType(const AType : String; out Found : Boolean;
      out APosition : Integer);
    function GetTokenCount : Integer;
    function GetTypeCsv : TStringList;
  public

    // The tokens in the order as passed.
    property TokenSequence : TStringArray read FTokenSequence;
    property AlphaSorted : Boolean read FAlphaSorted;
    property TypeCount : Integer read GetTypeCount;
    property TokenCount : Integer read GetTokenCount;

    // This produces a "CSV" list of Type<TAB>TokenCount pairs. Has to
    // be freed by the caller.
    property TypeCsv : TStringList read GetTypeCsv;
  end;
  TTrTypeTokenDataArray = array of TTrTypeTokenData;


  TTrMetaDatum = record
    Key : String;
    Value : String;
  end;
  TTrMetaDatumArray = array of TTrMetaDatum;


  TTrMetaDataCallback = procedure(var AKey : String;
    var AValue : String) of object;


  TTrMetaData = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AKey : String; const AValue : String);
    function GetByKey(const AKey : String) : String;

    // Return a value for a key or default, if not available.
    function GetByKeyDefault(const AKey : String;
      const ADefault : String) : String;
    function GetKeyIndex(const AKey : String) : Integer;
    procedure GetMetaKeyValueByIndex(const AIndex : Integer;
      out AKey : String; out AValue : String);
    procedure Iterate(AProc : TTrMetaDataCallback);
  protected
    FMetaDatumArray : TTrMetaDatumArray;
    function GetSize : Integer;
  public
    property Size : Integer read GetSize;
  end;

  RealArray = array of Real;

  TTrContainerType = (
    tctUnk      := 0,
    tctArticle  := 1,
    tctSection  := 2,
    tctDiv      := 3,
    tctP        := 4,
    tctH        := 5,
    tctBlock    := 6,
    tctTd       := 7,
    tctLi       := 8
  );

  // Forward declaration, needed for FDocument in TTrDiv.
  TTrDocument = class;

  TTrFannMetrics = array[0..36] of fann_type;

  // A class for one paragraph.
  TTrDiv = class(TObject)
  public
    constructor Create(ADocument : TTrDocument = nil);
    destructor Destroy; override;

    // Add a piece of meta-information.
    procedure AddMeta(const AKey : String; const AValue : String);
    function GetMetaByKey(const AKey : String) : String;
    function GetMetaKeyIndex(const AKey : String) : Integer;
    procedure AddMetric(const AValue : fann_type;
      const AIndex : Integer);
    procedure AddLink(ALink : String);

    // Deletes the text string of this paragraph.
    procedure Erase;
  protected
    FDocument : TTrDocument;

    FValid : Boolean;
    FIsDuplicateOf : Integer;
    FText : String;
    FLinks : TStringArray;
    FMeta : TTrMetaData;
    FMetrics : TTrFannMetrics;
    FBoilerplate : Boolean;
    FBoilerplateScore : Real;
    FFirstRaw : Integer;
    FLastRaw : Integer;

    FOpenTags : Integer;
    FCloseTags : Integer;
    FAnchors : Integer;
    FSkippedDivs : Integer;
    FContainer : TTrContainerType;
    FContainerClosingStart : Boolean;
    FCleansedTags : Integer;
    FCleansedEmails : Integer;
    FCleansedUris : Integer;
    FCleansedHashTags : Integer;

    function GetLengthRaw : Integer;
    function GetSize : Integer;
    function GetUtf8Size : Integer;
    function GetMetricsCount : Integer;
  public

    // Whether the paragraph is well-formed.
    property Valid : Boolean read FValid write FValid;

    // Of which other par this is a duplicate. -1 if not duplicate.
    property IsDuplicateof : Integer read FIsDuplicateOf
      write FIsDuplicateOf;

    // The textual value of the paragraph.
    property Text : String read FText write FText;

    // Links found in the paragraph source.
    property Links : TStringArray read FLinks write FLinks;

    // An array of values as strings for some form of boilerplate
    // detection or similar.
    property Meta : TTrMetaData read FMeta;

    property Metrics : TTrFannMetrics read FMetrics;
    property MetricsCount : Integer read GetMetricsCount;

    property Boilerplate : Boolean read FBoilerplate
      write FBoilerplate default false;
    property BoilerplateScore : Real read FBoilerplateScore
      write FBoilerplateScore;

    // Position within the raw buffer.
    property FirstRaw : Integer read FFirstRaw write FFirstRaw
      default 0;
    property LastRaw : Integer read FLastRaw write FLastRaw
      default 0;
    property LengthRaw : Integer read GetLengthRaw;

    // How many bytes in paragraph?
    property Size : Integer read GetSize;

    // How many bytes in paragraph?
    property Utf8Size : Integer read GetUtf8Size;

    property OpenTags : Integer read FOpenTags write FOpenTags;
    property CloseTags : Integer read FCloseTags write FCloseTags;
    property Anchors : Integer read FAnchors write FAnchors;
    property SkippedDivs : Integer read FSkippedDivs
      write FSkippedDivs;
    property Container : TTrContainerType read FContainer
      write FContainer;
    property ContainerClosingStart : Boolean
      read FContainerClosingStart write FContainerClosingStart;
    property CleansedTags : Integer read FCleansedTags
      write FCleansedTags;
    property CleansedEmails : Integer read FCleansedEmails
      write FCleansedEmails;
    property CleansedUris : Integer read FCleansedUris
      write FCleansedUris;
    property CleansedHashTags : Integer read FCleansedHashTags
      write FCleansedHashTags;
  end;


  TQWordArray = array of QWord;


  TTrPrerequisite = (
    trpreIsUtf8,
    trpreDeboilerplated,
    trpreUniqueDivs,
    trpreEntityFree,
    trpreIdentifierBlanked,
    trpreStripped,
    trpreTextAssessed,
    trpreTokenized,
    trpreIsValidUtf8,
    trpreIsNfcNormal
  );
  TTrPrerequisites = set of TTrPrerequisite;

  TTrDoctype = (
    tdtUnknown := 0,
    tdtXhtml   := 1,
    tdtHtml4   := 2,
    tdtHtml5   := 3
  );

  TTrDocument = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;

    // Cleanup raw data.
    procedure CleanRaw;

    // Cleanup all paragraphs.
    procedure CleanDivs;

    // Add raw material.
    procedure AddRaw(const AText : String);
    procedure AddRawLine(const ALine : String);


    // Add a new paragraph (at the end) and return its index.
    function AddDiv : TTrDiv;

    // Returns true iff the paragraph of index AIndex was deleted.
    function DeleteDiv(AIndex : Integer) : Boolean;

    // Add a piece of meta-information.
    procedure AddMeta(const AKey : String; const AValue : String);
    function GetMetaByKey(const AKey : String) : String;
    function GetMetaKeyIndex(const AKey : String) : Integer;
    procedure GetMetaKeyValueByIndex(const AIndex : Integer;
      out AKey : String; out AValue : String);
    function GetMetaNumber : Integer;
    function GetTokens : Integer;
    function GetTypes : Integer;

    function SimpleFingerprint(const ASize : Integer) :
      String;
  protected
    FUrl : String;
    FId : String;
    FIp : String;

    FPassed : TTrPrerequisites;

    FValid : Boolean;
    FRawText : String;                // The raw text buffer incl. markup.
    FRawHeader : String;              // The header (pre-HTML-Body) goes here.
    FDivs : TFPObjectList;            // Cleaned paragraphs.
    FMeta : TTrMetaData;              // Extracted meta-data.
    FBadness : Real;
    FSourceCharset : String;
    FDoctype : TTrDoctype;

    FTypeTokenData : TTrTypeTokenData;
    FFingerprint : TQWordArray;

    FNonBoilerplateDivs : Integer;
    FNonBoilerplateCharacters : Integer;
    FBoilerplateDivs : Integer;
    FBoilerplateCharacters : Integer;
    FNonBoilerplateDivProportion : Real;
    FNonBoilerplateCharacterProportion : Real;

    FAverageBoilerplateCharacter : Real;
    FAverageBoilerplateDiv : Real;

    // Retrieve a TTrDiv-typed object from FDivs.
    function GetRawSize : Integer;
    function GetDiv(AIndex : Integer) : TTrDiv;
    function GetFingerprintSize : Integer;
    procedure SetFingerprintSize(const ASize : Integer);
    procedure SetSourceCharset(const ACharset : String);
    function GetNumber : Integer;
    function GetSize : Integer;
    function GetValidNumber : Integer;
    function GetValidSize : Integer;
    function GetUtf8Size : Integer;
    function GetValidUtf8Size : Integer;
    procedure SetUrl(const AUrl : String);

  public
    property Url : String read FUrl write SetUrl;
    property Id : String read FId;
    property Ip : String read FIp write FIp;

    // A record of the documents processing history.
    property Passed : TTrPrerequisites read FPassed write FPassed;

    // Whether the document is well-formed.
    property Valid : Boolean read FValid write FValid;

    // The string with the raw text.
    property RawText : String read FRawText;
    property RawSize : Integer read GetRawSize;
    property RawHeader : String read FRawHeader write FRawHeader;

    // The paragraphs. Maybe later we want to add write-protection and
    // put modifications under the control of getter/setter.
    property Divs[i: Integer] : TTrDiv read GetDiv;
      default;

    // For diverse purposes.
    property TypeTokenData : TTrTypeTokenData read FTypeTokenData;

    // Shingling data structure.
    property Fingerprint : TQWordArray read FFingerprint
      write FFingerprint;
    property FingerprintSize : Integer read GetFingerprintSize
      write SetFingerprintSize;

    // Arbitrary meta-data. Can be modified freely.
    property Meta : TTrMetaData read FMeta;

    // Text quality assessment.
    property Badness : Real read FBadness write FBadness;

    property SourceCharset : String read FSourceCharset
      write SetSourceCharset;
    property Doctype : TTrDoctype read FDoctype write FDoctype
      default tdtUnknown;

    // The number of paragraphs.
    property Number : Integer read GetNumber;

    // How many bytes in document?
    property Size : Integer read GetSize;

    // The number of paragraphs.
    property ValidNumber : Integer read GetValidNumber;

    // How many bytes in document in valid paragraphs?
    property ValidSize : Integer read GetValidSize;

    // How many Utf8 characters in document?
    property Utf8Size : Integer read GetUtf8Size;

    // How many Utf8 characters in document in valid paragraphs?
    property ValidUtf8Size : Integer read GetUtf8Size;

    // How many meta data packages there are.
    property MetaNumber : Integer read GetMetaNumber;

    // A convenient way of accessing the lower-level TTrTypeTokenData.
    property Tokens : Integer read GetTokens;
    property Types : Integer read GetTypes;

    // More quality metrics, filled by deboilerplater.
    property NonBoilerplateDivs : Integer read FNonBoilerplateDivs
      write FNonBoilerplateDivs default 0;
    property NonBoilerplateCharacters : Integer
      read FNonBoilerplateCharacters write FNonBoilerplateCharacters
      default 0;

    property BoilerplateDivs : Integer read FBoilerplateDivs
      write FBoilerplateDivs default 0;
    property BoilerplateCharacters : Integer
      read FBoilerplateCharacters write FBoilerplateCharacters
      default 0;

    property NonBoilerplateCharacterProportion : Real
      read FNonBoilerplateCharacterProportion
      write FNonBoilerplateCharacterProportion;
    property NonBoilerplateDivProportion : Real
      read FNonBoilerplateDivProportion
      write FNonBoilerplateDivProportion;

    property AverageBoilerplateCharacter : Real
      read FAverageBoilerplateCharacter
      write FAverageBoilerplateCharacter;

    property AverageBoilerplateDiv : Real
      read FAverageBoilerplateDiv
      write FAverageBoilerplateDiv;

  end;

  TTrDocumentArray = array of TTrDocument;


// Callback functions to sort TTrTypeTokenData
function TypeAlphaCmp(Item1: Pointer; Item2: Pointer) : Integer;
function TypeFrequencyCmp(Item1: Pointer; Item2: Pointer) : Integer;


type
  TTrHeaderMatcher = packed record
    Id : String;
    IcuRegex : TIcuRegex;
  end;
  TTrHeaderMatchers = array of TTrHeaderMatcher;

  TTrMatchPack = record
    Id : String;
    Content : String;
  end;
  TTrMatchPacks = array of TTrMatchPack;

  TTrMetaMatcher = class(TObject)
  public
    constructor Create(const AMatchers : String;
      const APrefix : String; const ASuffix : String);
    destructor Destroy; override;

    // This returns only the first matching meta information.
    function Match(const ALine : String; out AMatch : TTrMatchPack) :
      Boolean;

    // This returns all pieces of matching meta information. Use this
    // if your buffer in ALine could contain several meta strings.
    function Matches(const ALine : String;
      out AMatches : TTrMatchPacks) : Integer;

  protected
    FExtracts : TTrHeaderMatchers;
    procedure ResetMatchers;
  end;


function TrDoctypeToStr(const ADoctype : TTrDoctype) : String;


implementation


constructor TTrMetaMatcher.Create(const AMatchers : String;
  const APrefix : String; const ASuffix : String);
var
  LStrings : TStringArray;
  i : Integer;
begin
  LStrings := TrExplode(AMatchers, ['|']);
  SetLength(FExtracts, Length(LStrings));

  for i := 0 to High(LStrings)
  do with FExtracts[i]
  do begin
    Id := LStrings[i];
    IcuRegex := TIcuRegex.Create(APrefix + LStrings[i] + ASuffix);
  end;
end;


destructor TTrMetaMatcher.Destroy;
begin
  ResetMatchers;
end;


function TTrMetaMatcher.Match(const ALine : String;
  out AMatch : TTrMatchPack) : Boolean;
var
  i : Integer;
begin
  Result := false;
  for i := 0 to High(FExtracts)
  do begin
    if FExtracts[i].IcuRegex.Match(ALine, true, true)
    then begin
      AMatch.Id := FExtracts[i].Id;
      AMatch.Content := FExtracts[i].IcuRegex.Replace(ALine,
        '$1', true, true);
      Result := true;
      Break;
    end;
  end;
end;


function TTrMetaMatcher.Matches(const ALine : String;
  out AMatches : TTrMatchPacks) : Integer;
var
  i : Integer;
begin
  SetLength(AMatches, 0);

  for i := 0 to High(FExtracts)
  do begin
    if FExtracts[i].IcuRegex.Match(ALine, true, true)
    then begin
      SetLength(AMatches, Length(AMatches)+1);
      with AMatches[High(AMatches)]
      do begin
        Id := FExtracts[i].Id;
        Content := FExtracts[i].IcuRegex.Replace(ALine, '$1', true,
          true);
      end;
    end;
  end;

  Result := Length(AMatches);
end;


procedure TTrMetaMatcher.ResetMatchers;
var
  i : Integer;
begin
  for i := 0 to High(FExtracts)
  do FreeAndNil(FExtracts[i].IcuRegex);
  SetLength(FExtracts, 0);
end;


{ * TTrTypeTokenData * }


constructor TTrTypeTokenData.Create;
begin
  SetLength(FTokenSequence, 0);
  FTypeList := TFPList.Create;
  FAlphaSorted := true;
end;


destructor TTrTypeTokenData.Destroy;
begin
  SetLength(FTokenSequence, 0);
  FreeAll;
  FreeAndNil(FTypeList);
  inherited;
end;


function TTrTypeTokenData.GetTypeCount : Integer;
begin
  if Assigned(FTypeList)
  then Result := FTypeList.Count
  else Result := 0;
end;


procedure TTrTypeTokenData.FreeAll;
var
  i : Integer;
begin
  for i := 0 to FTypeList.Count - 1
  do
    if FTypeList.Items[i] <> nil
    then begin
      Dispose(PTrType(FTypeList.Items[i]));
      FTypeList.Items[i] := nil;
    end;
end;


procedure TTrTypeTokenData.FindType(const AType : String;
  out Found : Boolean; out APosition : Integer);
var
  Upper : Integer;
  Lower : Integer;
  Split : Integer;
begin

  // Nothing found yet.
  Found := false;
  APosition := 0;

  if FTypeList.Count <= 0
  then Exit;

  // Make sure that the list is alpha-sorted (should only happen after
  // any other sort was explicitly performed). One of the purposes of
  // this function is to keep inserts alpha-sorted.
  if not FAlphaSorted
  then SortTypesByType;

  // This is a binary search which also finds the index at which an
  // item which was not found would have to be inserted (for sorted
  // inserts).

  // Search range initially is whole list.
  Lower := 0;
  Upper := FTypeList.Count - 1;

  while (Upper - Lower > 1)
  and (Found = false)
  do begin
    Split := Lower + ((Upper - Lower) div 2);
    APosition := Split;

    // Continue in lower half.
    if AType < PTrType(FTypeList.Items[Split])^.TypeString
    then Upper := Split

    // Continue in upper half.
    else if AType > PTrType(FTypeList.Items[Split])^.TypeString
    then Lower := Split

    // String found. AType = the other thing...
    else Found := true;

  end;

  // Final check whether it's one of the boundaries.
  if not Found
  then begin
    if ( AType = PTrType(FTypeList.Items[Lower])^.TypeString )
    then begin
      Found := true;
      APosition := Lower;
    end else if ( AType = PTrType(FTypeList.Items[Upper])^.TypeString )
    then begin
      Found := true;
      APosition := Upper;
    end else if ( AType < PTrType(FTypeList.Items[Upper])^.TypeString )
    then APosition := Upper
    else APosition := Upper + 1;
  end;
end;


function TTrTypeTokenData.GetTokenCount : Integer;
begin
  Result := Length(FTokenSequence);
end;


function TTrTypeTokenData.GetTypeCsv : TStringList;
var
  i : Integer;
begin
  Result := TStringList.Create;

  // Fill the list by iterating over the type-token list.
  for i := 0 to FTypeList.Count - 1
  do if FTypeList.Items[i] <> nil
    then
      with PTrType(FTypeList.Items[i])^
      do Result.Add(TypeString + #9 + IntToStr(Tokens) + #9 +
        FloatToStrF(Frequency, ffGeneral, 6, 4));
end;


procedure TTrTypeTokenData.AddToken(AToken : String);
var
  LToken : String;
  APosition : Integer = 0;
  Found : Boolean = false;
  NewTy : PTrType;
begin

  // Use our own ICU language-unspecific upcasing.
  LToken := Utf8UpCaseIcu(AToken);

  SetLength(FTokenSequence, Length(FTokenSequence)+1);
  FTokenSequence[High(FTokenSequence)] := LToken;

  // Update type list.
  FindType(LToken, Found, APosition);
  if Found
  then begin
    Inc(PTrType(FTypeList.Items[APosition])^.Tokens);
  end else begin
    New(NewTy);
    NewTy^.TypeString := LToken;
    NewTy^.Tokens := 1;
    FTypeList.Insert(APosition, NewTy);
  end;
end;


procedure TTrTypeTokenData.SortTypesByType;
begin
  FTypeList.Sort(@TypeAlphaCmp);
  FAlphaSorted := true;
end;


procedure TTrTypeTokenData.SortTypesByFrequency;
begin
  FTypeList.Sort(@TypeFrequencyCmp);
  FAlphaSorted := false;
end;


function TTrTypeTokenData.Item(AIndex : Integer) : PTrType;
begin
  Result := nil;
  try
    Result := PTrType(FTypeList.Items[AIndex]);
  except
    Result := nil;
  end;
end;


function TTrTypeTokenData.Item(AType : String) : PTrType;
var
  Found : Boolean = false;
  APosition : Integer = (-1);
begin
  Result := nil;
  FindType(AType, Found, APosition);
  if Found
  then try
    Result := PTrType(FTypeList.Items[APosition]);
  except
    Result := nil;
  end;
end;


procedure TTrTypeTokenData.UpdateTypes;
var
  i : Integer;
begin
  for i := 0 to TypeCount - 1
  do begin
    if FTypeList.Items[i] <> nil
    then with PTrType(FTypeList.Items[i])^
    do begin
      if (Tokens <> 0)
      and (TokenCount <> 0)
      then Frequency := Tokens / TokenCount;
    end;
  end;
end;


function TTrTypeTokenData.Clone : TTrTypeTokenData;
var
  i : Integer;
begin
  if (not Assigned(self))
  then begin
    Result := nil;
    Exit;
  end;

  // This is not the most efficient way, but safe.
  Result := TTrTypeTokenData.Create;
  for i := 0 to High(FTokenSequence)
  do Result.AddToken(FTokenSequence[i]);
end;


{ *** TTrMetaData *** }


constructor TTrMetaData.Create;
begin
  SetLength(FMetaDatumArray, 0);
end;


destructor TTrMetaData.Destroy;
begin
  SetLength(FMetaDatumArray, 0);
  inherited Destroy;
end;


procedure TTrMetaData.Add(const AKey : String;
  const AValue : String);
var
  LIndex : Integer;
  LKey : String;
begin

  // Don't add empty meta information.
  if (AKey = '')
  or (AValue = '')
  then Exit;

  LKey := AnsiLowerCase(AKey);

  // First see if key already known.
  LIndex := GetKeyIndex(LKey);
  if LIndex <> (-1)
  then FMetaDatumArray[LIndex].Value := AValue
  else begin

    // Make room in meta information array and set values.
    SetLength(FMetaDatumArray, Length(FMetaDatumArray)+1);
    with FMetaDatumArray[High(FMetaDatumArray)]
    do begin
      Key := LKey;
      Value := AValue;
    end;
  end;
end;


function TTrMetaData.GetByKey(const AKey : String) : String;
var
  LIndex : Integer;
begin

  // Get numerical index.
  LIndex := GetKeyIndex(AnsiLowerCase(AKey));
  if (LIndex = (-1))
  then Result := ''
  else Result := FMetaDatumArray[LIndex].Value;
end;


function TTrMetaData.GetByKeyDefault(const AKey : String;
  const ADefault : String) : String;
begin
  Result := GetByKey(AnsiLowerCase(AKey));
  if Result = ''
  then Result := ADefault;
end;


function TTrMetaData.GetKeyIndex(const AKey : String) : Integer;
var
  i : Integer;
begin
  Result := (-1);
  if AKey = ''
  then Exit;

  // This is a slow linear search in an unordered list.
  for i := 0 to High(FMetaDatumArray)
  do begin
    if FMetaDatumArray[i].Key = AnsiLowerCase(AKey)
    then Result := i;
  end;
end;


procedure TTrMetaData.GetMetaKeyValueByIndex(const AIndex : Integer;
  out AKey : String; out AValue : String);
begin
  if (AIndex < 0)
  or (AIndex > Length(FMetaDatumArray)-1)
  then begin
    AKey := '';
    AValue := '';
  end else begin
    AKey := FMetaDatumArray[AIndex].Key;
    AValue := FMetaDatumArray[AIndex].Value;
  end;
end;


procedure TTrMetaData.Iterate(AProc : TTrMetaDataCallback);
var
  i : Integer;
begin
  if Assigned(AProc)
  then for i := 0 to High(FMetaDatumArray)
    do with FMetaDatumArray[i]
      do AProc(Key, Value);
end;


function TTrMetaData.GetSize : Integer;
begin
  Result := Length(FMetaDatumArray);
end;


{ *** TTrDiv *** }


constructor TTrDiv.Create(ADocument : TTrDocument = nil);
begin
  FDocument := ADocument;
  FValid := true;
  FIsDuplicateOf := (-1);
  FText := '';
  FOpenTags := 0;
  FCloseTags := 0;
  FAnchors := 0;
  FSkippedDivs := 0;
  FContainer := tctUnk;
  FContainerClosingStart := false;
  FCleansedTags := 0;
  FCleansedEmails := 0;
  FCleansedUris := 0;
  FCleansedHashTags := 0;
  FBoilerplateScore := -1;
  FMeta := TTrMetaData.Create;
  SetLength(FLinks, 0);
end;


destructor TTrDiv.Destroy;
begin
  FreeAndNil(FMeta);
  inherited Destroy;
end;


procedure TTrDiv.AddMeta(const AKey : String;
  const AValue : String);
begin
  FMeta.Add(AKey, AValue);
end;


function TTrDiv.GetMetaByKey(const AKey : String) : String;
begin
  Result := FMeta.GetByKey(AKey);
end;


function TTrDiv.GetMetaKeyIndex(const AKey : String) : Integer;
begin
  Result := FMeta.GetKeyIndex(AKey);
end;


procedure TTrDiv.AddMetric(const AValue : fann_type;
  const AIndex : Integer);
begin
  FMetrics[AIndex] := AValue;
end;


procedure TTrDiv.AddLink(ALink : String);
begin
  SetLength(FLinks, Length(FLinks)+1);
  FLinks[High(FLinks)] := ALink;
end;


procedure TTrDiv.Erase;
begin
  SetLength(FText, 0);
end;


function TTrDiv.GetLengthRaw : Integer;
begin
  Result := FLastRaw - FFirstRaw;
end;


function TTrDiv.GetSize : Integer;
begin
  Result := Length(FText);
end;


function TTrDiv.GetUtf8Size : Integer;
begin
  Result := TrUtf8Length(FText)
end;


function TTrDiv.GetMetricsCount : Integer;
begin
  Result := Length(FMetrics);
end;


{ *** TTrDocument *** }


constructor TTrDocument.Create;
begin
  FUrl := '';
  FId := '';
  FIp := '';
  FPassed := [];
  FValid := true;
  FRawText := '';
  FSourceCharset := '';
  FMeta := TTrMetaData.Create;
  FBadness := 0;
  FNonBoilerplateCharacterProportion := 0;
  FNonBoilerplateDivProportion := 0;
  FAverageBoilerplateCharacter := 0;
  FAverageBoilerplateDiv := 0;
  FFingerprint := nil;
  FTypeTokenData := TTrTypeTokenData.Create;
  FDivs := TFPObjectList.Create(true);
end;


destructor TTrDocument.Destroy;
begin
  SetLength(FRawText, 0);
  FreeAndNil(FTypeTokenData);
  FreeAndNil(FDivs);
  FreeAndNil(FMeta);
  inherited Destroy;
end;


procedure TTrDocument.CleanRaw;
begin
  FRawText := '';
end;


procedure TTrDocument.CleanDivs;
begin

  // Free paragraphs.
  FDivs.Clear;
end;


procedure TTrDocument.AddRaw(const AText : String);
begin
  FRawText += ' ' + AText;
end;


procedure TTrDocument.AddRawLine(const ALine : String);
begin
  FRawText += Trim(ALine) + #10;
end;


function TTrDocument.AddDiv : TTrDiv;
var
  LDiv : TTrDiv = nil;
  LIndex : Integer;
begin

  // Create Div.
  LDiv := TTrDiv.Create(self);

  // Add it.
  LIndex := FDivs.Add(LDiv);
  Result := FDivs[LIndex] as TTrDiv;
end;


function TTrDocument.DeleteDiv(AIndex : Integer) : Boolean;
begin
  Result := false;

  if AIndex < FDivs.Count
  then begin
    FDivs.Delete(AIndex);
    Result := true;
  end;
end;


function TTrDocument.GetRawSize : Integer;
begin
  Result := Length(FRawText);
end;


function TTrDocument.GetDiv(AIndex : Integer) : TTrDiv;
begin
  if FDivs.Count > AIndex
  then Result := FDivs[AIndex] as TTrDiv
  else Result := nil;
end;


procedure TTrDocument.SetFingerprintSize(const ASize : Integer);
begin
  SetLength(FFingerprint, ASize);
end;


procedure TTrDocument.SetSourceCharset(const ACharset : String);
begin
  FSourceCharset := UpCase(ACharset);
end;


function TTrDocument.GetFingerprintSize : Integer;
begin
  Result := Length(FFingerprint);
end;


procedure TTrDocument.AddMeta(const AKey : String;
  const AValue : String);
begin
  FMeta.Add(AKey, AValue);
end;


function TTrDocument.GetMetaByKey(const AKey : String) : String;
begin
  Result := FMeta.GetByKey(AKey);
end;


function TTrDocument.GetMetaKeyIndex(const AKey : String) : Integer;
begin
  Result := FMeta.GetKeyIndex(AKey);
end;


procedure TTrDocument.GetMetaKeyValueByIndex(const AIndex : Integer;
  out AKey : String; out AValue : String);
begin
  FMeta.GetMetaKeyValueByIndex(AIndex, AKey, AValue);
end;


function TTrDocument.SimpleFingerprint(const ASize : Integer) :
  String;
var
  i : Integer;
  LInterval : Integer;
begin
  if ASize >= Length(FRawText)
  then Result := FRawText
  else begin
    SetLength(Result, ASize);
    LInterval := Length(FRawText) div ASize;

    // Generate a FFingerprintSize-byte fingerprint from RAW document.
    for i := 1 to ASize
    do Result[i] := FRawText[i*LInterval];
  end;
end;


function TTrDocument.GetNumber : Integer;
begin
  Result := FDivs.Count;
end;


function TTrDocument.GetSize : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to FDivs.Count-1
  do if Assigned(FDivs[i])
  then Result += (FDivs[i] as TTrDiv).Size;
end;


function TTrDocument.GetValidNumber : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to FDivs.Count-1
  do if (Assigned(FDivs[i]))
  and ((FDivs[i] as TTrDiv).Valid)
  then Inc(Result);
end;


function TTrDocument.GetValidSize : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to FDivs.Count-1
  do
    if  Assigned(FDivs[i])
    and ((FDivs[i] as TTrDiv).Valid)
    then Result += (FDivs[i] as TTrDiv).Size;
end;


function TTrDocument.GetUtf8Size : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to FDivs.Count-1
  do if Assigned(FDivs[i])
  then Result += (FDivs[i] as TTrDiv).Utf8Size;
end;


function TTrDocument.GetValidUtf8Size : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to FDivs.Count-1
  do if Assigned(FDivs[i])
  and ((FDivs[i] as TTrDiv).Valid)
  then Result += (FDivs[i] as TTrDiv).Utf8Size;
end;


function TTrDocument.GetMetaNumber : Integer;
begin
  Result := FMeta.Size;
end;


procedure TTrDocument.SetUrl(const AUrl : String);
begin
  FUrl := AUrl;

  // The Id has 32 chars for Md5 hash plus 4 random chars to allow
  // re-crawled Urls with different Ids.
  FId := Md5Print(Md5String(FUrl)) +
    LowerCase(IntToHex(Random($ffff), 4));
end;


{ *** Helper functions/callbacks. *** }


function TypeAlphaCmp(Item1: Pointer; Item2: Pointer) : Integer;
begin
  if PTrType(Item1)^.TypeString > PTrType(Item2)^.TypeString
  then Result := 1
  else if PTrType(Item2)^.TypeString > PTrType(Item1)^.TypeString
  then Result := (-1)
  else Result := 0;
end;


function TypeFrequencyCmp(Item1: Pointer; Item2: Pointer) : Integer;
begin
  if PTrType(Item1)^.Tokens < PTrType(Item2)^.Tokens
  then Result := 1
  else if PTrType(Item2)^.Tokens < PTrType(Item1)^.Tokens
  then Result := (-1)
  else Result := 0;
end;


function TTrDocument.GetTokens : Integer;
begin
  if Assigned(FTypeTokenData)
  then Result := FTypeTokenData.TokenCount
  else Result := (-1);
end;


function TTrDocument.GetTypes : Integer;
begin
  if Assigned(FTypeTokenData)
  then Result := FTypeTokenData.TypeCount
  else Result := (-1);
end;


function TrDoctypeToStr(const ADoctype : TTrDoctype) : String;
begin
  case ADoctype
  of
    tdtUnknown : Result := 'UNKNOWN';
    tdtXhtml   : Result := 'XHTML';
    tdtHtml4   : Result := 'HTML4';
    tdtHtml5   : Result := 'HTML5';
  end;
end;


end.
