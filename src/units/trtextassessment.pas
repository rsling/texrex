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


unit TrTextAssessment;

{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  Classes,
  SysUtils,
  StrUtils,
  Math,
  IniFiles,
  TrUtilities,
  TrData,
  TrDocumentProcessor;


type

  ETrTextAssessment = class(Exception);

  TTrAssessorType = packed record
    Meen : Real;
    Stdev : Real;
    Limit : Real;
    Name : String;
  end;

  TTrAssessorTypeArray = array of TTrAssessorType;


  TTrTextAssessment = class(TTrDocumentProcessor)
  public

    procedure Process(const ADocument : TTrDocument); override;
    destructor Destroy; override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FProfileFile : String;
    FLanguageCode : String;
    FThreshold : Real;
    FStoplist : TStringArray;
    FAssessorTypes : TTrAssessorTypeArray;

    procedure SetProfileFile(const AProfileFile : String);
  published
    property ProfileFile : String read FProfileFile
      write SetProfileFile;
    property LanguageCode : String read FLanguageCode write FLanguageCode;
    property Threshold : Real read FThreshold write FThreshold;
  end;

  TTrTextAssessmentArray =   array of TTrTextAssessment;


  // This one hosts several Assessors for multiple-langugage crawls (i.e.,
  // CommonCrawl for CommonCOW.)
  TTrTextAssessmentMulti = class(TTrDocumentProcessor)
  public
    procedure Process(const ADocument : TTrDocument); override;
    destructor Destroy; override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected
    FProfiles : String;
    FAssessmentChilds : TTrTextAssessmentArray;
    FMetaThreshold : Real;
    FBreakThreshold : Real;
    procedure SetProfiles(const AProfiles : String);
  published
    property Profiles : String read FProfiles write SetProfiles;
    property MetaThreshold : Real read FMetaThreshold write FMetaThreshold;
    property BreakThreshold : Real read FBreakThreshold write FBreakThreshold;
  end;


implementation


destructor TTrTextAssessmentMulti.Destroy;
var
  LAssessment : TTrTextAssessment;
begin
  for LAssessment in FAssessmentChilds
  do begin
    FreeAndNil(LAssessment);
  end;
  SetLength(FAssessmentChilds, 0);
end;

procedure TTrTextAssessmentMulti.Process(const ADocument : TTrDocument);
var
  LAssessment : TTrTextAssessment;
  LBestLanguage : String = '';
  LBestBadness : Real = 99999;
begin

  // Call one after the other, keep track of what the single-language
  // assessments did.
  for LAssessment in FAssessmentChilds
  do begin
    LAssessment.Process(ADocument);

    // Single assessments potentially mark the document as invalid. But we have
    // to keep going. Reverse potential invalidity.
    ADocument.Valid := true;

    // See if the last badness is better than all previous ones.
    if ADocument.Badness < LBestBadness
    then begin
      LBestBadness := ADocument.Badness;
      LBestLanguage := LAssessment.LanguageCode;

      // If the badness was reached at which we are "absolutely sure", do not
      // keep checking.
      if ADocument.Badness <= BreakThreshold
      then Break;
    end;
  end;

  // Select best matching and add meta to doc.
  ADocument.Badness := LBestBadness;
  ADocument.AddMeta('language', LBestLanguage);

  // Filter.
  if ADocument.Badness > FMetaThreshold
  then ADocument.Valid := false;

end;

procedure TTrTextAssessmentMulti.SetProfiles(const AProfiles : String);
var
  LAssessmentNames : TStringArray;
  LAssessmentName : String;
begin

  FProfiles := AProfiles;
  // Create all, using alternative constructor.
  // First, split string containing names of the profiles.
  LAssessmentNames := TrExplode(FProfiles, ['|']);
  TrAssert((Length(LAssessmentNames) > 0),
    'Length of assessment processors for AssessmentMulti <= 0.');

  // Create processors.
  SetLength(FAssessmentChilds, 0);
  for LAssessmentName in LAssessmentNames
  do begin
    SetLength(FAssessmentChilds, Length(FAssessmentChilds)+1);
    FAssessmentChilds[High(FAssessmentChilds)] :=
      TTrTextAssessment.Create(FIni, LAssessmentName);
  end;
end;

class function TTrTextAssessmentMulti.Achieves : TTrPrerequisites;
begin
  Result := [];
end;

class function TTrTextAssessmentMulti.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8,trpreTokenized];
end;




destructor TTrTextAssessment.Destroy;
begin
  SetLength(FStoplist, 0);
  SetLength(FAssessorTypes, 0);
end;


procedure TTrTextAssessment.Process(const ADocument : TTrDocument);
var
  i : Integer;
  LType : PTrType;
  LFreqDiff : Real;
begin
  inherited;

  // Initialize badness to 0.
  ADocument.Badness := 0;

  // Make sure relative frequencies are calculated properly.
  ADocument.TypeTokenData.UpdateTypes;

  // Now request frequencies for the profile items.
  for i := 0 to High(FAssessorTypes)
  do begin

    // Get the type from the documents type/token data structure.
    LType := ADocument.TypeTokenData.Item(FAssessorTypes[i].Name);

    if Assigned(LType)
    then begin

      // Calculate how the measured frequency deviates from expected.
      LFreqDiff := Log10(LType^.Frequency) - FAssessorTypes[i].Meen;

      // Only continue if the deviation is negative.
      if LFreqDiff < 0
      then begin

        // Reuse LFReqDiff to store the standardized negative deviation.
        LFreqDiff := Abs(LFreqDiff / FAssessorTypes[i].Stdev);

        // Clamp and add.
        if LFreqDiff > FAssessorTypes[i].Limit
        then LFreqDiff := FAssessorTypes[i].Limit;
        ADocument.Badness := ADocument.Badness + LFreqDiff;
      end;

    end

    // If the type did not occur at all in the document, assign maximal
    // Badness for it.
    else ADocument.Badness := ADocument.Badness +
      FAssessorTypes[i].Limit;
  end;

  if ADocument.Badness > FThreshold
  then ADocument.Valid := false;
end;


procedure TTrTextAssessment.SetProfileFile(
  const AProfileFile : String);
var
  LStrings : TStringArray;
  LValues : TStringArray;
  i : Integer;
  LStopword : String;
const
  LSplitChars : TSysCharset = ['|'];
begin

  // Set and examine filename for profile.
  FProfileFile := AProfileFile;
  TrAssert(TrFindFile(FProfileFile), 'Language profile file exists.');

  // Load lines to examine.
  TrLoadLinesFromFile(FProfileFile, LStrings);

  SetLength(FStopList, 0);
  SetLength(FAssessorTypes, 0);

  // Process each string: comment, stopword, typedata.
  for i := 0 to High(LStrings)
  do begin

    // Do not use empty lines or comments
    if  (Length(LStrings[i]) > 0)
    and (LStrings[i][1] <> '#')
    then begin

      // Beginning ! marks stop words.
      if LStrings[i][1] = '!'
      then begin
        LStopword := AnsiRightStr(LStrings[i], Length(LStrings[i])-1);
        if Length(LStopword) > 0
        then begin
          SetLength(FStopList, Length(FStopList)+1);
          FStoplist[High(FStopList)] := LStopword;
        end;
      end else begin

        // Else explode and get the 4 values.
        LValues := TrExplode(LStrings[i], LSplitChars);
        if Length(LValues) = 4
        then begin

          // Copy values from file line to a new assessor type.
          SetLength(FAssessorTypes, Length(FAssessorTypes)+1);
          with FAssessorTypes[High(FAssessorTypes)]
          do begin
            Name := LValues[0];

            // If something fails with conversion, just
            // revert = remove type.
            try
              Meen := StrToFloat(LValues[1]);
              Stdev := StrToFloat(LValues[2]);
              Limit := StrToFloat(LValues[3]);
            except
              SetLength(FAssessorTypes, Length(FAssessorTypes)-1);
            end;
          end;
        end;
      end;
    end;
  end;

  // Check whether we have a meaningful profile.
  TrAssert((Length(FAssessorTypes) > 0),
    'Length of assessor type list > 0 ' + LanguageCode + '.');
end;


class function TTrTextAssessment.Achieves : TTrPrerequisites;
begin
  Result := [];
end;


class function TTrTextAssessment.Presupposes : TTrPrerequisites;
begin
  Result := [trpreStripped,trpreIsUtf8,trpreTokenized];
end;


end.
