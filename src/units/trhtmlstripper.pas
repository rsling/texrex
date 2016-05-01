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


unit TrHtmlStripper;

{$MODE OBJFPC}
{$H+}
{$M+}


// Define this to get rich parse information on stdout.
{ $DEFINE DEBUGPARSE}

interface


uses
  SysUtils,
  StrUtils,
  Classes,
  IniFiles,
  IcuWrappers,
  TrDocumentProcessor,
  TrData,
  TrUtilities;


type

  ETrHtmlStripper = class(Exception);

  // This is the state variable telling us whether we are inside
  // a document container. And if so, whether we need to write or
  // to drop the material.
  TTrReadingState = (
    trsOutsideDoc,
    trsMarkup,
    trsText
  );


  // This is the second state variable which keeps track of what part
  // of a tag we are (not) processing.
  TTrTagState = (
    ttsSearching,     // We are outide of a tag, searching next.
    ttsReadingName,   // We are reading the name part of a tag.
    ttsSkipping,      // We are skipping the part after the name.
    ttsDone           // The closing > was found.
  );


  TTrHtmlStripper = class(TTrDocumentProcessor)
  public
    constructor Create(const AIni : TIniFile); override;
    destructor Destroy; override;
    procedure Process(const ADocument : TTrDocument); override;

    class function Achieves : TTrPrerequisites; override;
    class function Presupposes : TTrPrerequisites; override;
  protected

    // Whether <a> tags should be parsed for href-links.
    FExtractAnchors : Boolean;

    // The levels at which extracted links are actually written,
    // relative to the linking document.
    // Same host => "host.tld" is identical
    // same virtual host => "virtual.host.tld" is identical
    // external: "host1.tld" != "host2.tld"
    FKeepSameHostLinks : Boolean;
    FKeepSameVirtualHostLinks : Boolean;
    FKeepExternalLinks : Boolean;

    FMinimalLinkLength : Integer;
    FMaximalLinkLength : Integer;

    // Which document was passed for processing.
    FCurrentDocument : TTrDocument;
    FCurrentDiv : TTrDiv;

    // For extracting the doctype declaration etc.
    FHtml5Icu :  TIcuRegex;
    FHtml4Icu :  TIcuRegex;
    FXhtmlIcu :  TIcuRegex;
    FHrefIcu : TIcuRegex;
    FEncodingIcu : TIcuRegex;

    // This points into RawText of the current document, it is the
    // character we are currently contemplating.
    FCurrentChar : Integer;
    FNewTag : String;           // The last tag which we found.
    FLastTagPosition : Integer; // Position of last tag-opening <
    FReadingState : TTrReadingState;
    FCurrentDocumentCloseContainer : String;
    FSkippedPotentialDivs : Integer;

    {$IFDEF DEBUGPARSE}
      FDebugParse : Boolean;
    {$ENDIF}

    // This searches for the next tag, possibly writing text, etc.
    // It moves the cursor to the position where the next tag ends
    // (at > or document end) and stores the name component of the tag
    // in FNewTag.
    procedure AdvanceToNextTag;
    procedure NewDiv;
    procedure ExtractMeta;

    // This decides what to do with the current character once we know
    // it is not markup.
    procedure WriteChar(AChar : Char); inline;
    procedure Debug(const AMessage : String);inline;

  published
    property ExtractAnchors : Boolean read FExtractAnchors
      write FExtractAnchors default true;
    property KeepSameHostLinks : Boolean read FKeepSameHostLinks
      write FKeepSameHostLinks default true;
    property KeepSameVirtualHostLinks : Boolean
      read FKeepSameVirtualHostLinks write FKeepSameVirtualHostLinks
      default true;
    property KeepExternalLinks : Boolean read FKeepExternalLinks
      write FKeepExternalLinks default true;
    property MinimalLinkLength : Integer read FMinimalLinkLength
      write FMinimalLinkLength default 16;
    property MaximalLinkLength : Integer read FMaximalLinkLength
      write FMaximalLinkLength default 1024;

    {$IFDEF DEBUGPARSE}
      property DebugParse : Boolean read FDebugParse write FDebugParse
        default false;
    {$ENDIF}

  end;


implementation


type
  TTrQuoteStackState = (
    tqsNone,
    tqsSingle,
    tqsDouble
  );


const
  TagStartChars : set of Char = ['a' .. 'z', 'A' .. 'Z', '/', '!', '?'];

  WhiteSpace : set of Char = [#9, #10, #13, #32];
  DocumentContainers : array[0..0] of String = ( 'body' );
  DropContainers : array[0..7] of String = ( 'script', 'style', 'head',
    'form', 'applet', 'code', 'audio', 'video' );
  BreakTags : array[0..25] of String = ( 'div', '/div', 'p', '/p',
    'li', '/li', 'h1', '/h1', 'h2', '/h2', 'h3', '/h3', 'h4', '/h4',
    'h5', '/h5', 'h6', '/h6', 'blockquote', '/blockquote', 'td', '/td',
    'article', '/article', 'section', '/section' );
  HrefRegex = '.*href=["]([^" ]+)["].*|.*href=['']([^'' ]+)[''].*';
  Html5Regex      : Utf8String = '^.*<!doctype +html *>.*$';
  Html4Regex      : Utf8String = '^.*<!doctype.*html 4.*>.*$';
  XhtmlRegex      : Utf8String = '^.*<!doctype.*xhtml 1.*>.*$';
  EncodingMeta    : Utf8String = '^.*<meta[^<]+charset=([^ ">/]+)[ ">/].*$';
  EncodingReplace : Utf8String = '$1';


constructor TTrHtmlStripper.Create(const AIni : TIniFile);
begin
  FHrefIcu := TIcuRegex.Create(HrefRegex);
  FCurrentDiv := nil;

  FEncodingIcu := TIcuRegex.Create(EncodingMeta,
    UREGEX_CASE_INSENSITIVE);
  FHtml5Icu :=  TIcuRegex.Create(Html5Regex,
    UREGEX_CASE_INSENSITIVE);
  FHtml4Icu :=  TIcuRegex.Create(Html4Regex,
    UREGEX_CASE_INSENSITIVE);
  FXhtmlIcu :=  TIcuRegex.Create(XhtmlRegex,
    UREGEX_CASE_INSENSITIVE);

  inherited Create(AIni);
end;


destructor TTrHtmlStripper.Destroy;
begin
  FreeAndNil(FHtml5Icu);
  FreeAndNil(FHtml4Icu);
  FreeAndNil(FXhtmlIcu);
  FreeAndNil(FEncodingIcu);
  FreeAndNil(FHrefIcu);
  inherited Destroy;
end;


procedure TTrHtmlStripper.AdvanceToNextTag;
var
  LTagState : TTrTagState = ttsSearching;

  // When reading <a>, we keep track of start and end to extract
  // links.
  LAnchorStart : Integer;
  LAnchorLength : Integer;
  LAnchorBuffer : String;
  LLink : String;
  LQuotStack : TTrQuoteStackState;
  LLinkRelation : TTrLinkRelation;
begin

  LQuotStack := tqsNone;

  Debug('BEGIN AdvanceToNextTag');

  // We fill this anew.
  FNewTag := '';

  // Read as long as we have characters in the document or we have
  // found the (end of the) next tag.
  while (FCurrentChar <= Length(FCurrentDocument.RawText))
  and (LTagState <> ttsDone)
  do begin

    case LTagState of

      ttsSearching : begin
        if FCurrentDocument.RawText[FCurrentChar] = '<'
        then begin
          LTagState := ttsReadingName;
          FLastTagPosition := FCurrentChar;
          Debug('LTagState = ttsReadingName');
        end
        else begin
          if FReadingState = trsText
          then WriteChar(FCurrentDocument.RawText[FCurrentChar]);
        end;

      end;

      ttsReadingName : begin

        // If this is a comment, immediately foward everything.
        // After the <!-- everything is allowed to follow, even
        // tag name chars.
        if FNewTag = '!--'
        then begin
          Debug('HTML comment found.');
          Inc(FCurrentChar, 2);
          while (FCurrentChar <= Length(FCurrentDocument.RawText))
          and (AnsiMidStr(FCurrentDocument.RawText, FCurrentChar-2, 3)
            <> '-->')
          do begin
            Inc(FCurrentChar);
          end;

          LTagState := ttsDone;
          Debug('FastForwarded a HTML comment.');
        end

        else if AnsiLowerCase(FNewTag) = '![cdata['
        then begin
          Debug('CDATA section found.');
          Inc(FCurrentChar, 2);
          while (FCurrentChar <= Length(FCurrentDocument.RawText))
          and (AnsiMidStr(FCurrentDocument.RawText, FCurrentChar-2, 3)
            <> ']]>')
          do begin
            Inc(FCurrentChar);
          end;

          LTagState := ttsDone;
          Debug('FastForwarded a CDATA section.');
        end

        // Finish reading name when there is a blank of a / and this is
        // not the first character after the tag opening. The last
        // condition is for <br/> and tags like that.
        else if (FCurrentDocument.RawText[FCurrentChar] = ' ')
        then begin
          LTagState := ttsSkipping;
          Debug('LTagState = ttsSkipping');
        end

        else if (FCurrentDocument.RawText[FCurrentChar] = '>')
        then begin
          LTagState := ttsDone;
          Debug('LTagState = ttsDone');
        end

        // Experimental. Save non-tags started with literal <.
        // We revert to searching the next tag.
        else if (FCurrentChar = FLastTagPosition+1)
        and not
          (FCurrentDocument.RawText[FCurrentChar] in TagStartChars)
        then begin
          LTagState := ttsSearching;
          if FReadingState = trsText
          then begin
            WriteChar(FCurrentDocument.RawText[FCurrentChar-1]);
            WriteChar(FCurrentDocument.RawText[FCurrentChar]);
          end;
          Debug('!!! Reverting tag start decision!');
          Debug('LTagState = ttsReadingName');
        end

        else FNewTag += FCurrentDocument.RawText[FCurrentChar];

        // If INSIDE ttsReadingName case we end being in ttsSkipping,
        // this was the end of the tag name. Then, record anchor start
        // position to later extract URL.
        if  (LTagState = ttsSkipping)
        then begin
          if (FNewTag = 'a')
          then LAnchorStart := FCurrentChar;
        end;

      end;

      ttsSkipping : begin

        case LQuotStack of

        tqsNone :
        begin

          if (FCurrentDocument.RawText[FCurrentChar] = '''')
          then begin
            LQuotStack := tqsSingle;
            Debug('LTagState = tqsSingle.');
          end

          else if (FCurrentDocument.RawText[FCurrentChar] = '"')
          then begin
            LQuotStack := tqsDouble;
            Debug('LTagState = tqsSingle.');
          end

          else if (FCurrentDocument.RawText[FCurrentChar] = '>')
          then begin

            LTagState := ttsDone;
            Debug('LTagState = ttsDone');

            // If INSIDE the ttsSkipping case, we end up in ttsDone, this
            // is the end of the overall tag, and we can extract a link
            // if this was <a>.
            if  FExtractAnchors
            and (FNewTag = 'a')
            then begin
              LAnchorLength := FCurrentChar-LAnchorStart;
              LAnchorBuffer := AnsiMidStr(FCurrentDocument.RawText,
                LAnchorStart, LAnchorLength);
              try
                LLink := FHrefIcu.Replace(LAnchorBuffer, '$1', true,
                  true);

                // Sometimes, we end up with garbage after the link.
                LLink := TrExplode(LLink, [#9, #10, #13, #32], false)[0]
              except
                LLink := '';
              end;

              // The first condition makes sure (I hope) that
              // non-replacements aren't saved.
              if  (Length(LLink) < LAnchorLength)
              and (Length(LLink) <= FMaximalLinkLength)
              and (Length(LLink) >= FMinimalLinkLength)

              // Never remove this IF! We cannot be sure we're actually
              // inside a div, and the AddLink will produce access
              // violations sometimes.
              and (Assigned(FCurrentDiv))
              then begin
                LLinkRelation := TrLinkRelation(FCurrentDocument.Url,
                  LLink);
                if ((LLinkRelation = trlSameFullHost)
                  and (FKeepSameVirtualHostLinks))
                or ((LLinkRelation = trlSameNonVirtualHost)
                  and (FKeepSameHostLinks))
                or ((LLinkRelation = trlDifferentHosts)
                  and (FKeepExternalLinks))
                then begin
                  FCurrentDiv.AddLink(LLink + #9 +
                    TrLinkRelationToString(LLinkRelation));
                  Debug('AddLink: ' + LLink);
                end;
              end;

            end;
          end;
        end;

        tqsSingle :
        begin
          if (FCurrentDocument.RawText[FCurrentChar] = '''')
          then begin
            LQuotStack := tqsNone;
            Debug('LTagState = tqsNone from tqsSingle.');
          end else begin
            Debug('LTagState = tqsNone from tqsSingle.');
          end;
        end;

        tqsDouble :
        begin
          if (FCurrentDocument.RawText[FCurrentChar] = '"')
          then begin
            LQuotStack := tqsNone;
            Debug('LTagState = tqsNone from tqsDouble.');
          end else begin
            Debug('LTagState NOT CHANGED tqsNone from tqsDouble.');
          end;
        end;

        end;
      end;

    end;    // esac

    // Move cursor to next char.
    Inc(FCurrentChar);

  end; // elihw

  FNewTag := AnsiLowerCase(FNewTag);

  // Modify per-paragraph tag statistics.
  if  Assigned(FCurrentDiv)
  and ( Length(FNewTag) > 0 )
  then begin
    if ( FNewTag[1] = '/' )
    then FCurrentDiv.CloseTags := FCurrentDiv.CloseTags+1
    else FCurrentDiv.OpenTags := FCurrentDiv.OpenTags+1;
    if ( FNewTag[1] = 'a' )
    then FCurrentDiv.Anchors := FCurrentDiv.Anchors+1;
  end;

  // Make sure a <br> is always at least replaced by space.
  if (FNewTag = 'br')
  or (FNewTag = 'br/')
  then WriteChar(#32);

  Debug('END AdvanceToNextTag: ' + FNewTag);
end;



procedure TTrHtmlStripper.WriteChar(AChar : Char); inline;
begin
  // This is a protection against bugs, because this function
  // should not be called with FCurrentDiv unassigned.
  if not Assigned(FCurrentDiv)
  then begin
    Exit;
    Debug('!!! Div unassigned in WriteChar.');
  end;

  // If current char is not whitespace, write always.
  if not (AChar in WhiteSpace)
  then FCurrentDiv.Text := FCurrentDiv.Text + AChar

  // If it's space or tab, we need to see.
  else
  begin

    // Never write space as first char in paragraph.
    if (Length(FCurrentDiv.Text) > 0)
    and not (FCurrentDiv.Text[Length(FCurrentDiv.Text)]
      in WhiteSpace)
    then FCurrentDiv.Text := FCurrentDiv.Text + #32;
  end;
end;


procedure TTrHtmlStripper.NewDiv;
var
  LRawTag : String;
begin

  // Create a new paragraph object (if this the first call).
  if not Assigned(FCurrentDiv)
  then begin
    FCurrentDiv := FCurrentDocument.AddDiv;
    FSkippedPotentialDivs := 0;
  end;

  // Only create save old paragraph if something was written.
  // On first call, this is trivially false.
  if (Length(FCurrentDiv.Text) > 0)
  then begin
    Debug('<par> ' + FCurrentDiv.Text);

    // Write metrics for old paragraph.
    FCurrentDiv.LastRaw := FCurrentChar-1;
    FCurrentDiv.SkippedDivs := FSkippedPotentialDivs;

    // Create new.
    FCurrentDiv := FCurrentDocument.AddDiv;
    FSkippedPotentialDivs := 0;

    // In case it continues directly, we need to make sure that
    // raw positions don't "overlap".
  end
  else Inc(FSkippedPotentialDivs);

  // This needs to be set in any case.
  FCurrentDiv.FirstRaw := FCurrentChar;

  // Whether the opening tag was actually a container closer.
  if (Length(FNewTag) > 0)
  and (FNewTag[1] = '/')
  then begin
    LRawTag := RightStr(FNewTag, Length(FNewTag)-1);
    FCurrentDiv.ContainerClosingStart := true;
  end else begin
    LRawTag := FNewTag;
    FCurrentDiv.ContainerClosingStart := false;
  end;

  // The class of starting tag.
  with FCurrentDiv
  do begin
    case LRawTag of
      'article'    : Container := tctArticle;
      'section'    : Container := tctSection;
      'div'        : Container := tctDiv;
      'p'          : Container := tctP;
      'h1'         : Container := tctH;
      'h2'         : Container := tctH;
      'h3'         : Container := tctH;
      'h4'         : Container := tctH;
      'h5'         : Container := tctH;
      'h6'         : Container := tctH;
      'blockquote' : Container := tctBlock;
      'td'         : Container := tctTd;
      'li'         : Container := tctLi;
    end;
  end;
end;

procedure TTrHtmlStripper.ExtractMeta;
begin
  // This is called when the <body> was found. So, we can use anything
  // up to here to match against the meta extractors. Only the info
  // vital for processing is extracted, because other meta info is
  // difficult to get before conversion.

  with FCurrentDocument
  do begin

    RawHeader := AnsiLeftStr(RawText, FCurrentChar);

    if FEncodingIcu.Match(RawHeader, true, true)
    then SourceCharset := FEncodingIcu.Replace(RawHeader,
      EncodingReplace, false, true);

    // Check for !DOCTYPE and store as DOCTYPE meta: HTML5, HTML4, XHTML.
    if FXhtmlIcu.Match(RawHeader, true, true)
    then Doctype := tdtXhtml
    else if FHtml4Icu.Match(RawHeader, true, true)
    then Doctype := tdtHtml4
    else if FHtml5Icu.Match(RawHeader, true, true)
    then Doctype := tdtHtml5;

  end;
end;



procedure TTrHtmlStripper.Process(
  const ADocument : TTrDocument);
var
  LCurrentDropCloseContainer : String = '';
begin
  inherited;

  // Set document for stripper-internal communication, and set
  // in-document cursor to beginning.
  FCurrentDocument := ADocument;

  Debug('### Starting document: ' + FCurrentDocument.Url);

  // If re-run, clean all paragraphs.
  FCurrentDocument.CleanDivs;

  // Important! Explicitly release possible pointers to paragraphs in
  // old document.
  FCurrentDiv := nil;
  FCurrentChar := 1;                     // Strings are 1-based.
  FReadingState := trsOutsideDoc;
  FCurrentDocumentCloseContainer := '';

//  {$IFDEF DEBUGPARSE}
//    Writeln(stderr, FCurrentDocument.RawText);
//  {$ENDIF}

  // First, move to document start.
  while (FCurrentChar <= Length(FCurrentDocument.RawText)) // = not EOF
  and (FReadingState = trsOutsideDoc)
  do begin
    AdvanceToNextTag;

    Debug('FNewTag=' + FNewTag);

    if AnsiMatchText(FNewTag, DocumentContainers)
    then begin
      Debug('FNewTag is doc container; FReadingState = trsText');

      // Change the parser state and put container name on "stack".
      FReadingState := trsText;
      FCurrentDocumentCloseContainer := '/' + LowerCase(FNewTag);

      Debug('FCurrentDocumentCloseContainer=' +
        FCurrentDocumentCloseContainer);

      // HTML header information is expected up to here.
      ExtractMeta;

      NewDiv;
    end;
  end;

  // Now we might be inside a doc. If not, something went wrong above,
  // and the following loop will just not execute.
  while (FCurrentChar <= Length(FCurrentDocument.RawText)) // = not EOF
  and (FReadingState <> trsOutsideDoc)
  do begin
    AdvanceToNextTag;

    // The document might end here.
    if FNewTag = FCurrentDocumentCloseContainer
    then begin
      FReadingState := trsOutsideDoc;
      Debug('FReadingState = trsOutsideDoc; with close ' + FNewTag);
    end

    // There might be an error, and a document starts here... Panic!
    else if AnsiMatchText(FNewTag, DocumentContainers)
    then begin
      FReadingState := trsOutsideDoc;
      Debug('FReadingState = trsOutsideDoc; with open ' + FNewTag);
    end

    // We might also enter a drop area (scripts etc.).
    else if (LCurrentDropCloseContainer = '')
    and AnsiMatchText(FNewTag, DropContainers)
    then begin
      FReadingState := trsMarkup;
      LCurrentDropCloseContainer := '/' + FNewTag;
      Debug('FReadingState = trsMarkup (drop area); with ' + FNewTag);
      Debug('LCurrentDropCloseContainer = ' +
        LCurrentDropCloseContainer);
    end

    // We might also exit a drop area.
    else if LCurrentDropCloseContainer = FNewTag
    then begin
      FReadingState := trsText;
      LCurrentDropCloseContainer := '';
      Debug('FReadingState = trsText (drop area end); with ' +
        FNewTag);
      Debug('LCurrentDropCloseContainer = ' +
        LCurrentDropCloseContainer);
    end

    // We might also encounter a paragraph break.
    else if (FReadingState = trsText)
    and AnsiMatchText(FNewTag, BreakTags)
    then begin
      NewDiv;
      Debug('New paragraph; with: ' + FNewTag);
    end;

  end; // elihw

  // Close any "open" paragraph.
  NewDiv;

end;


procedure TTrHtmlStripper.Debug(const AMessage : String);
  inline;
begin
  {$IFDEF DEBUGPARSE}
    if FDebugParse
    then Writeln(stderr, '@', FCurrentChar, ' ', AMessage);
  {$ENDIF}
end;


class function TTrHtmlStripper.Achieves : TTrPrerequisites;
begin
  Result := [trpreStripped];
end;


class function TTrHtmlStripper.Presupposes : TTrPrerequisites;
begin
  Result := [];
end;


end.
