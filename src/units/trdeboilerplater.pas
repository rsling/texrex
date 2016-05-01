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


unit TrDeboilerplater;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  SysUtils,
  StrUtils,
  Classes,
  IniFiles,
  IcuWrappers,
  Math,
  Fann,
  TrDocumentProcessor,
  TrData,
  TrUtilities;


type

  ETrDeboilerplater = class(Exception);

  TTrDeboilerplater = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;

    // The call which cleans exactly one paragraph. Strings are assumed
    // to be UTF-8!
    destructor Destroy; override;
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FTrainingMode : Boolean;

    // libfann data.
    FFannFile : String;        // The network file name.
    FFann : PFann;              // The network structure.
    FThreshold : Real;          // When is doc bad?
    FMinDivsBelowThreshold : Integer;
    FMinDivProportionBelowThreshold : Real;
    FMinCharsBelowThreshold : Integer;
    FMinCharProportionBelowThreshold : Real;

    FCurrentDocument : TTrDocument;
    FCurrentDocumentLength : Integer;
    FCurrentDocumentMarkupRatio : Real;

    // For counting diverse character classes. At some point, we might
    // change this from ICU matching to something faster.
    FPunctuationRegex : String;
    FSentenceRegex : String;
    FNumberRegex : String;
    FUpcaseRegex : String;
    FLowercaseRegex : String;
    FEndsInPunctuationRegex : String;
    FYearRegex : String;
    FCustomRegex : String;

    // Regexes which help us to count character classes. Settable.
    FPunctuationIcu : TIcuRegex;
    FSentenceIcu : TIcuRegex;
    FNumberIcu : TIcuRegex;
    FUpcaseIcu : TIcuRegex;
    FLowercaseIcu : TIcuRegex;
    FEndsInPunctuationIcu : TIcuRegex;
    FYearIcu : TIcuRegex;
    FCustomIcu : TIcuRegex;

    // Not settable.
    FWhitespaceIcu : TIcuRegex;
    FCopyrightIcu : TIcuRegex;

    // Where text/sentence length is clamped.
    FTextClamp : Integer;
    FSentenceClamp : Integer;
    FSentenceLengthClamp : Integer;
    FSkippedClamp : Integer;

    // Prepare single-paragraph metrics.
    procedure PrepareValues;

    // Prepare values for which (all) others must be known.
    procedure PrepareValuesSecondPass;

    // Run the MLP.
    procedure DecideMlp;

    procedure DecideThreshs;

    // Setters / getters.
    procedure SetFannFile(const AFileName : String);
    procedure SetPunctuationRegex(const ARegex : String);
    procedure SetSentenceRegex(const ARegex : String);
    procedure SetNumberRegex(const ARegex : String);
    procedure SetUpcaseRegex(const ARegex : String);
    procedure SetLowercaseRegex(const ARegex : String);
    procedure SetEndsInPunctuationRegex(const ARegex : String);
    procedure SetYearRegex(const ARegex : String);
    procedure SetCustomRegex(const ARegex : String);

  public

    // These default to German/English-compatible settings, some need
    // to be re-set for other languages.
    property PunctuationRegex : String read FPunctuationRegex
      write SetPunctuationRegex;
    property SentenceRegex : String read FSentenceRegex
      write SetSentenceRegex;
    property NumberRegex : String read FNumberRegex
      write SetNumberRegex;
    property UpcaseRegex : String read FUpcaseRegex
      write SetUpcaseRegex;
    property LowercaseRegex : String read FLowercaseRegex
      write SetLowercaseRegex;
    property EndsInPunctuationRegex : String
      read FEndsInPunctuationRegex write SetEndsInPunctuationRegex;
    property YearRegex : String read FYearRegex write SetYearRegex;
    property TextClamp : Integer read FTextClamp
      write FTextClamp;
    property SentenceClamp : Integer read FSentenceClamp
      write FSentenceClamp;
    property SentenceLengthClamp : Integer read FSentenceLengthClamp
      write FSentenceLengthClamp;
    property SkippedClamp : Integer read FSkippedClamp
      write FSkippedClamp;

  published

    // Set this to keep feature extraction, but always make -1 decision.
    property TrainingMode : Boolean read FTrainingMode
      write FTrainingMode default false;

    // Set the network file. Raises exception if file does not exist.
    // If it is NOT set at all, we assume we are in training data mode.
    property FannFile : String read FFannFile
      write SetFannFile;

    // The FANN-threshold above which a paragraph should not be used
    // in further computations, and for output.
    property Threshold : Real read FThreshold write FThreshold;
    property MinDivsBelowThreshold : Integer
      read  FMinDivsBelowThreshold write FMinDivsBelowThreshold
      default 1;
    property MinDivProportionBelowThreshold : Real
      read FMinDivProportionBelowThreshold
      write FMinDivProportionBelowThreshold;
    property MinCharsBelowThreshold : Integer
      read  FMinCharsBelowThreshold write FMinCharsBelowThreshold
      default 500;
    property MinCharProportionBelowThreshold : Real
      read FMinCharProportionBelowThreshold
      write FMinCharProportionBelowThreshold;

    property CustomRegex : String read FCustomRegex
      write SetCustomRegex;
  end;



implementation

const

  // Index into Metrics to value of markup proportion.
  MarkIdx = 5;


constructor TTrDeboilerplater.Create(const AIni : TIniFile);
begin
  FMinDivProportionBelowThreshold := 0.1;
  FMinCharProportionBelowThreshold := 0.25;
  FPunctuationIcu := nil;
  FSentenceIcu := nil;
  FNumberIcu := nil;
  FUpcaseIcu := nil;
  FLowercaseIcu := nil;
  FEndsInPunctuationIcu := nil;
  FYearIcu := nil;
  FCustomIcu := nil;
  NumberRegex := '\p{N}';
  UpcaseRegex := '\p{Lu}';
  LowercaseRegex := '\p{Ll}';
  PunctuationRegex := '\p{P}';
  SentenceRegex := '[.?!](?:\s|$)';
  EndsInPunctuationRegex := '.*[.?!] *$';
  YearRegex := '[^0-9](20[01][0-9])([^0-9]|$)';
  FWhitespaceIcu := TIcuRegex.Create('\s');
  FCopyrightIcu := TIcuRegex.Create('.*©.*');
  FTextClamp := 1000;
  FSentenceClamp := 10;
  FSentenceLengthClamp := 100;
  FSkippedClamp := 20;

  inherited Create(AIni);
end;


destructor TTrDeboilerplater.Destroy;
begin
  FreeAndNil(FPunctuationIcu);
  FreeAndNil(FSentenceIcu);
  FreeAndNil(FNumberIcu);
  FreeAndNil(FUpcaseIcu);
  FreeAndNil(FLowercaseIcu);
  FreeAndNil(FEndsInPunctuationIcu);
  FreeAndNil(FYearIcu);
  FreeAndNil(FCustomIcu);
  FreeAndNil(FWhitespaceIcu);
  FreeAndNil(FCopyrightIcu);
  inherited Destroy;
end;


procedure TTrDeboilerplater.Process(const ADocument : TTrDocument);
begin
  inherited;

  // Get total number of codepoints in text once (costly).
  FCurrentDocument := ADocument;
  FCurrentDocumentLength := ADocument.Utf8Size;

  if  (FCurrentDocument.RawSize > 1)
  and (FCurrentDocumentLength > 1)
  then FCurrentDocumentMarkupRatio :=
    FCurrentDocumentLength / FCurrentDocument.RawSize
  else begin
    FCurrentDocument.Valid := false;
    Exit;
  end;

  // Create values paragraph-internally.
  PrepareValues;

  // This passes through all paragraphs again to calculate/add window
  // values and whole-document values.
  PrepareValuesSecondPass;

  if not FTrainingMode
  then begin

    // Call the network to get a decision. If we are in training mode,
    // BoilerplateScore is set to -1 for all divs by default, and we skip.
    DecideMlp;

    // Now make decision to remove the document if overall boilerplateness
    // is to high.
    DecideThreshs;
  end;

end;


procedure TTrDeboilerplater.DecideThreshs;
begin

  with FCurrentDocument
  do begin

    // Filter if too frew non-boiler divs.
    if (NonBoilerplateDivs < FMinDivsBelowThreshold)
    then Valid := false;

    // Filter if too frew non-boiler chars.
    if (NonBoilerplateCharacters < FMinCharsBelowThreshold)
    then Valid := false;

    // 0-Check for NonBoilerplateCharacterProportion.
    if (BoilerplateCharacters+NonBoilerplateCharacters) > 0
    then begin
      NonBoilerplateCharacterProportion := NonBoilerplateCharacters/
        (BoilerplateCharacters+NonBoilerplateCharacters);

      // Now filter.
      if (NonBoilerplateCharacterProportion <
        FMinCharProportionBelowThreshold)
      then Valid := false;
    end else begin
      NonBoilerplateCharacterProportion := (-1);
      Valid := false;
    end;

    // 0-Check for NonBoilerplateCharacterProportion.
    if (BoilerplateDivs+NonBoilerplateDivs) > 0
    then begin
      NonBoilerplateDivProportion := NonBoilerplateDivs/
        (BoilerplateDivs+NonBoilerplateDivs);

      // Now filter.
      if (NonBoilerplateDivProportion <
        FMinDivProportionBelowThreshold)
      then Valid := false;
    end else begin
      NonBoilerplateDivProportion := (-1);
      Valid := false;
    end;

  end; // htiw
end;


procedure TTrDeboilerplater.PrepareValues;
var
  TextMass : Integer = 0;
  i : Integer;
  k : TTrDoctype;
  l : TTrContainerType;
  LLengthRaw : Integer;
  LLengthText : Integer;
  LPercentile : Real;
  LDivPercentile : Real;
  LPunctuation : Integer;
  LSentence : Integer;
  LLetter : Integer;
  LTrueTextLength : Integer;
  LUppercase, LLowercase : Integer;
  LNumber : Integer;
  LYear : Integer;
begin

  // Iterate over the paragraphs.
  for i := 0 to FCurrentDocument.Number-1
  do begin

    // TEXT-MASS RELATED METRICS

    // Calculate raw length from meta.
    LLengthRaw := FCurrentDocument[i].LengthRaw;
    if LLengthRaw < 1
    then LLengthRaw := 1;

    // Set text length meta. We want codepoints, not bytes.
    LLengthText := FCurrentDocument[i].Utf8Size;
    if LLengthText < 1
    then LLengthText := 1;

    // [0] Clamped text length.
    if LLengthText > FTextClamp
    then FCurrentDocument[i].AddMetric(1, 0)
    else FCurrentDocument[i].AddMetric(LLengthText / FTextClamp, 0);

    // Get whitespace count to subtract from "text" count.
    LTrueTextLength := LLengthText -
      FWhitespaceIcu.MatchCount(FCurrentDocument[i].Text, true);

    // If we have nothing left, this paragraph is invalid.
    if LTrueTextLength < 1
    then begin
      FCurrentDocument[i].Valid := false;
      Continue;
    end;

    // [1] How much of the whole page is this paragraph.
    if FCurrentDocumentLength > 0
    then
      FCurrentDocument[i].AddMetric(LLengthText/FCurrentDocumentLength, 1)
    else FCurrentDocument[i].AddMetric(0, 1);

    // [2] How far in the text mass is this div located in text mass?
    if FCurrentDocumentLength > 0
    then begin

      // We take the middle point of this paraghraph as its "location".
      LPercentile := (TextMass + (LLengthText / 2)) /
        FCurrentDocumentLength;

      // Since the middle is good, and the margins are bad, we
      // recalculate as: "How far from the middle are we?"
      if (LPercentile > 0.5)
      then LPercentile := (LPercentile - 0.5)*2
      else LPercentile := (0.5 - LPercentile)*2;
    end else LPercentile := 1;
    FCurrentDocument[i].AddMetric(LPercentile, 2);
    Inc(TextMass, LLengthText);

    // [3] How far is this div located in par count?
    if FCurrentDocument.Number > 0
    then begin
      LDivPercentile := i / FCurrentDocument.Number;

      // Since the middle is good, and the margins are bad, we
      // recalculate as: "How far from the middle are we?"
      if (LDivPercentile > 0.5)
      then LDivPercentile := (LDivPercentile - 0.5)*2
      else LDivPercentile := (0.5 - LDivPercentile)*2;
    end else LDivPercentile := 1;
    FCurrentDocument[i].AddMetric(LDivPercentile, 3);

    // [4] We add this whole-document weighting value.
    FCurrentDocument[i].AddMetric(FCurrentDocumentMarkupRatio, 4);

    // CHARACTER-CLASS RELATED FEATURES

    // Match regexes to get raw values.
    LSentence := FSentenceIcu.MatchCount(FCurrentDocument[i].Text,
      true);
    LUppercase := FUpcaseIcu.MatchCount(FCurrentDocument[i].Text, true);
    LLowercase := FLowercaseIcu.MatchCount(FCurrentDocument[i].Text,
      true);
    LLetter := LUppercase + LLowercase;
    LNumber := FNumberIcu.MatchCount(FCurrentDocument[i].Text, true);
    LPunctuation := FPunctuationIcu.MatchCount(FCurrentDocument[i].Text,
      true);
    LYear := FYearIcu.MatchCount(FCurrentDocument[i].Text, true);

    // [5..14] Write metrics.
    FCurrentDocument[i].AddMetric(
      (LLengthRaw - LLengthText) / LLengthRaw, 5); // Markup proportion.

    FCurrentDocument[i].AddMetric(LPunctuation / LLengthText, 6);
    FCurrentDocument[i].AddMetric(LLetter / LTrueTextLength, 7);
    FCurrentDocument[i].AddMetric(LNumber / LTrueTextLength, 8);
    FCurrentDocument[i].AddMetric(
      FCurrentDocument[i].CleansedTags / LTrueTextLength, 9);
    FCurrentDocument[i].AddMetric(
      FCurrentDocument[i].CleansedEmails / LTrueTextLength, 10);
    FCurrentDocument[i].AddMetric(
      FCurrentDocument[i].CleansedUris / LTrueTextLength, 11);
    FCurrentDocument[i].AddMetric(
      FCurrentDocument[i].CleansedHashtags / LTrueTextLength, 12);
    FCurrentDocument[i].AddMetric(LYear / LTrueTextLength, 13);
    FCurrentDocument[i].AddMetric(FCurrentDocument[i].Anchors /
      LTrueTextLength, 14);

    // [15] Ratio of upper vs. lowercase.
    if (LUppercase + LLowercase > 0)
    then FCurrentDocument[i].AddMetric(
      LUppercase / (LUppercase + LLowercase), 15)
    else FCurrentDocument[i].AddMetric(0, 15);

    // [16] Is sentence length a guessed value (i.e., no punctuation)?
    if LSentence > 0
    then
      FCurrentDocument[i].AddMetric(0, 16)     // Ok sentence length.
    else begin
      LSentence := 1;
      FCurrentDocument[i].AddMetric(1, 16);    // Bogus sentence length.
    end;

    // [17] We clamp sentence count and length to make it fit into [0,1].
    if (LLengthText div LSentence) > FSentenceLengthClamp
    then FCurrentDocument[i].AddMetric(1, 17)
    else FCurrentDocument[i].AddMetric(
      (LLengthText div LSentence) / FSentenceLengthClamp, 17);

    // [18] Sentence count.
    if LSentence > FSentenceClamp
    then FCurrentDocument[i].AddMetric(1, 18)
    else FCurrentDocument[i].AddMetric(LSentence / FSentenceClamp, 18);

    // BOOLEAN METRICS

    // [19] Contains ©?
    if FCopyrightIcu.Match(FCurrentDocument[i].Text, false, true)
    then FCurrentDocument[i].AddMetric(1, 19)
    else FCurrentDocument[i].AddMetric(0, 19);

    // [20] Ends in punctuation?
    if FEndsInPunctuationIcu.Match(FCurrentDocument[i].Text, false,
      true)
    then FCurrentDocument[i].AddMetric(1, 20)
    else FCurrentDocument[i].AddMetric(0, 20);

    // [21..23] We need three values to encode the doctype.
    for k := tdtXhtml to tdtHtml5
    do begin
      if FCurrentDocument.Doctype = k
      then FCurrentDocument[i].AddMetric(1, Integer(k)+20)
      else FCurrentDocument[i].AddMetric(0, Integer(k)+20);
    end;

    // [24..31] We need 8 values to encode the enclosing block type.
    for l := tctArticle to tctLi
    do begin
      if FCurrentDocument[i].Container = l
      then FCurrentDocument[i].AddMetric(1, Integer(l)+23)
      else FCurrentDocument[i].AddMetric(0, Integer(l)+23);
    end;

    // [32] Was the opening tag a closing tag with / (=potential rogue
    // content not in proper container).
    if FCurrentDocument[i].ContainerClosingStart
    then FCurrentDocument[i].AddMetric(1, 32)
    else FCurrentDocument[i].AddMetric(0, 32);

    // [33] Ratio open/close tags.
    with FCurrentDocument[i]
    do begin
      if (OpenTags + CloseTags) > 0
      then AddMetric(OpenTags/(OpenTags + CloseTags), 33)
      else AddMetric(0, 33);
    end;

    // [34] Skipped divs before this one.
    if FCurrentDocument[i].SkippedDivs > FSkippedClamp
    then FCurrentDocument[i].AddMetric(1, 34)
    else FCurrentDocument[i].AddMetric(
      FCurrentDocument[i].SkippedDivs / FSkippedClamp, 34);

  end;
end;


procedure TTrDeboilerplater.PrepareValuesSecondPass;
var
  i : Integer;
  LRatio, LWindow2Ratio : Real;
begin

  // Add the "smoothing" meta information by going through the
  // paragraphs again.
  for i := 0 to FCurrentDocument.Number-1
  do begin

      // If this par is invalid, do nothing.
      if not FCurrentDocument[i].Valid
      then Continue;

      LRatio := FCurrentDocument[i].Metrics[MarkIdx];

      // One to the left.
      if i > 0
      then begin
        if FCurrentDocument[i-1].Valid
        then LRatio += FCurrentDocument[i-1].Metrics[MarkIdx]
        else LRatio += LRatio;
      end else begin
        if FCurrentDocument[0].Valid
        then LRatio += FCurrentDocument[0].Metrics[MarkIdx]
        else LRatio += LRatio;
      end;

      // One to the right.
      if i < FCurrentDocument.Number-1
      then begin
        if FCurrentDocument[i+1].Valid
        then LRatio += FCurrentDocument[i+1].Metrics[MarkIdx]
        else LRatio += LRatio;
      end else begin
        if FCurrentDocument[FCurrentDocument.Number-1].Valid
        then LRatio +=
          FCurrentDocument[FCurrentDocument.Number-1].Metrics[MarkIdx]
        else LRatio += LRatio;
      end;

      // [35] Add window +1 value;
      FCurrentDocument[i].AddMetric(LRatio / 3, 35);

      LWindow2Ratio := 0;

      // Two to the left.
      if i > 1
      then begin
        if FCurrentDocument[i-2].Valid
        then LWindow2Ratio += FCurrentDocument[i-2].Metrics[MarkIdx]
        else LWindow2Ratio += LRatio/2
      end else begin
        if FCurrentDocument[0].Valid
        then LWindow2Ratio := FCurrentDocument[0].Metrics[MarkIdx]
        else LWindow2Ratio += LRatio/2
      end;

      // Two to the right.
      if i < FCurrentDocument.Number-2
      then begin
        if FCurrentDocument[i+2].Valid
        then LWindow2Ratio += FCurrentDocument[i+2].Metrics[MarkIdx]
        else LWindow2Ratio += LRatio/2;
      end else begin
        if FCurrentDocument[FCurrentDocument.Number-1].Valid
        then LWindow2Ratio :=
          FCurrentDocument[FCurrentDocument.Number-1].Metrics[MarkIdx]
        else LWindow2Ratio += LRatio/2;
      end;

      // [36]  Add window +2 value;
      LRatio += LWindow2Ratio;
      FCurrentDocument[i].AddMetric(LRatio / 5, 36);
  end;
end;


procedure TTrDeboilerplater.DecideMlp;
var
  i : Integer;
  LFannOut : PFann_Type_Array;
begin

  // We do not raise an exception, because using this without a valid
  // network means we are in training data generation mode.
  if FFann = nil
  then Exit;

  // Go through all paragraphs of document...
  for i := 0 to FCurrentDocument.Number-1
  do begin

    // Only process valid divs.
    if not FCurrentDocument[i].Valid
    then Continue;

    // Model-specific match = "[read more]" or "(...)" etc.
    if Assigned(FCustomIcu)
    and (FCustomIcu.Match(FCurrentDocument[i].Text, false, true))
    then FCurrentDocument[i].Boilerplate := true
    else FCurrentDocument[i].Boilerplate := false;

    // Make decision.
    LFannOut :=
      fann_run(FFann, Pfann_type(FCurrentDocument[i].Metrics));

    if LFannOut = nil
    then raise ETrDeboilerplater.Create('FANN result was nil.');

    FCurrentDocument[i].BoilerplateScore := LFannOut^[0];

    // Now make decision and record statistics for whole-document
    // boilerplate level detection.
    if (FCurrentDocument[i].BoilerplateScore > FThreshold)
    then begin
      FCurrentDocument[i].Boilerplate := true;

      // Add satistics for whole document.
      FCurrentDocument.BoilerplateDivs :=
        FCurrentDocument.BoilerplateDivs + 1;
      FCurrentDocument.BoilerplateCharacters :=
        FCurrentDocument.BoilerplateCharacters +
        FCurrentDocument[i].Utf8Size;
    end
    else begin
      FCurrentDocument.NonBoilerplateDivs :=
        FCurrentDocument.NonBoilerplateDivs + 1;
      FCurrentDocument.NonBoilerplateCharacters :=
        FCurrentDocument.NonBoilerplateCharacters +
        FCurrentDocument[i].Utf8Size;
    end;

    // Add to weighted averages of boilerplateness. This requires that
    // at the end, we divide by the Utf8 length of the whole document,
    // resp. the div count, which happens in DecideThreshs.

    FCurrentDocument.AverageBoilerplateDiv :=
      FCurrentDocument.AverageBoilerplateDiv +
      FCurrentDocument[i].BoilerplateScore;

    // The same for characters.
    FCurrentDocument.AverageBoilerplateCharacter :=
      FCurrentDocument.AverageBoilerplateCharacter +
      FCurrentDocument[i].BoilerplateScore *
      FCurrentDocument[i].Utf8Size;

  end;

  // Finally, fix the AverageBoilerplate~ variables by dividing by
  // document totals.
  with FCurrentDocument
  do begin
    AverageBoilerplateCharacter :=
      AverageBoilerplateCharacter / ValidUtf8Size;
    AverageBoilerplateDiv := AverageBoilerplateDiv / ValidNumber;
  end;

end;


procedure TTrDeboilerplater.SetFannFile(const AFileName : String);
begin
  FFannFile := AFileName;
  TrAssert(TrFindFile(FFannFile), 'FANN file exists.');
  FFann := fann_create_from_file(PChar(FFannFile));
end;



procedure TTrDeboilerplater.SetPunctuationRegex(
  const ARegex : String);
begin
  FPunctuationRegex := ARegex;
  if Assigned(FPunctuationIcu)
  then FreeAndNil(FPunctuationIcu);
  FPunctuationIcu := TIcuRegex.Create(FPunctuationRegex);
end;


procedure TTrDeboilerplater.SetSentenceRegex(const ARegex : String);
begin
  FSentenceRegex := ARegex;
  if Assigned(FSentenceIcu)
  then FreeAndNil(FSentenceIcu);
  FSentenceIcu := TIcuRegex.Create(FSentenceRegex);
end;


procedure TTrDeboilerplater.SetNumberRegex(const ARegex : String);
begin
  FNumberRegex := ARegex;
  if Assigned(FNumberIcu)
  then FreeAndNil(FNumberIcu);
  FNumberIcu := TIcuRegex.Create(FNumberRegex);
end;


procedure TTrDeboilerplater.SetUpcaseRegex(const ARegex : String);
begin
  FUpcaseRegex := ARegex;
  if Assigned(FUpcaseIcu)
  then FreeAndNil(FUpcaseIcu);
  FUpcaseIcu := TIcuRegex.Create(FUpcaseRegex);
end;


procedure TTrDeboilerplater.SetLowercaseRegex(const ARegex : String);
begin
  FLowercaseRegex := ARegex;
  if Assigned(FLowercaseIcu)
  then FreeAndNil(FLowercaseIcu);
  FLowercaseIcu := TIcuRegex.Create(FLowercaseRegex);
end;


procedure TTrDeboilerplater.SetEndsInPunctuationRegex(
  const ARegex : String);
begin
  FEndsInPunctuationRegex := ARegex;
  if Assigned(FEndsInPunctuationIcu)
  then FreeAndNil(FEndsInPunctuationIcu);
  FEndsInPunctuationIcu := TIcuRegex.Create(FEndsInPunctuationRegex);
end;


procedure TTrDeboilerplater.SetYearRegex(const ARegex : String);
begin
  FYearRegex := ARegex;
  if Assigned(FYearIcu)
  then FreeAndNil(FYearIcu);
  FYearIcu := TIcuRegex.Create(FYearRegex);
end;


procedure TTrDeboilerplater.SetCustomRegex(const ARegex : String);
begin
  FCustomRegex := ARegex;
  if Assigned(FCustomIcu)
  then FreeAndNil(FCustomIcu);
  FCustomIcu := TIcuRegex.Create(FCustomRegex);
end;


class function TTrDeboilerplater.Achieves : TTrPrerequisites;
begin
  Result := [trpreDeboilerplated];
end;


class function TTrDeboilerplater.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped, trpreIsUtf8];
end;


end.
