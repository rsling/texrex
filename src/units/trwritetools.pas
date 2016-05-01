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

unit TrWriteTools;


// Purely procedural code to format and write TTrDocuments.


{$MODE OBJFPC}
{$H+}
{$M+}


interface


uses
  SysUtils,
  StrUtils,
  Classes,
  TrData,
  TrFile,
  TrUtilities;


function TrWriteXmlDoc(const ADocument : TTrDocument;
  const AWriteDocAttrs : TStringArray; const AWriteDocMetas : TStringArray;
  const AWriteDocContainers : TStringArray; const AWriteDivAttrs : TStringArray;
  const AWriteDivMetas : TStringArray; const AWriteDups : Boolean;
  const ADupBlank : String;
  const AWriteDivMetrics : Boolean; const AWriteText : Boolean;
  const AWriter : TTrFileOut; const ASplitSize : Integer) : QWord; inline;

procedure TrWriteTokens(const ADocument : TTrDocument;
  const AWriteMaxTokens : Integer; const AWriter : TTrFileOut;
  const ASplitSize : Integer); inline;

procedure TrWriteTarc(const ADocument : TTrDocument; const AWriter : TTrFileOut;
  const ASplitSize : Integer); inline;

// If AWriteIdInsteadOfUrl = true, then instead of the source document URL,
// the texrex ID will be written followed by :n where n is the div number.
function TrWriteLinks(const ADocument : TTrDocument;
  const AWriter : TTrFileOut; const ASplitSize : Integer;
  const AWriteIdInsteadOfUrl : Boolean = false) : Integer; inline;


procedure TrWriteShingles(const ADocument : TTrDocument;
  const AWriter : TTrFileOut; const ASplitSize : Integer); inline;


implementation


function TrWriteXmlDoc(const ADocument : TTrDocument;
  const AWriteDocAttrs : TStringArray; const AWriteDocMetas : TStringArray;
  const AWriteDocContainers : TStringArray; const AWriteDivAttrs : TStringArray;
  const AWriteDivMetas : TStringArray; const AWriteDups : Boolean;
  const ADupBlank : String;
  const AWriteDivMetrics : Boolean; const AWriteText : Boolean;
  const AWriter : TTrFileOut; const ASplitSize : Integer) : QWord; inline;
var
  i, j : Integer;
  LMeta : String;
  LStartTag : String;
  LMetrics : String;
  LBdc : Char;
  LBpc : Char;
  LMetaExtract : String;
begin
  if not Assigned(ADocument)
  or not ADocument.Valid
  then Exit;

  // This is how we add the written bytes to the statistics var in the
  // pool: Always add the delta after each document.
  Result := AWriter.Bytes;

  // Create the <doc> opening tag.
  LBdc := TrBadnessToBdc(ADocument.Badness);
  LStartTag := '<doc url="' + TrXmlEncode(ADocument.Url) + '" id="' +
    TrXmlEncode(ADocument.Id) + '" ip="' + TrXmlEncode(ADocument.Ip) +
    '" sourcecharset="' + TrXmlEncode(ADocument.SourceCharset) +
    '" sourcedoctype="' + TrDoctypeToStr(ADocument.Doctype) + '"';

  LStartTag +=
    ' bdc="' + LBdc + '"' +
    ' bdv="' + FloatToStrF(ADocument.Badness, ffGeneral, 6, 4) + '"' +
    ' nbc="' + IntToStr(ADocument.NonBoilerplateCharacters) + '"' +
    ' nbcprop="' + FloatToStrF(ADocument.NonBoilerplateCharacterProportion,
      ffGeneral, 6, 4) + '"' +
    ' nbd="' + IntToStr(ADocument.NonBoilerplateDivs) + '"' +
    ' nbdprop="' + FloatToStrF(ADocument.NonBoilerplateDivProportion, ffGeneral,
      6, 4) + '"' +
    ' avgbpc="' + FloatToStrF(ADocument.AverageBoilerplateCharacter, ffGeneral,
      6, 4) + '"' +
     ' avgbpd="' + FloatToStrF(ADocument.AverageBoilerplateDiv, ffGeneral, 6,
       4) + '"';

  // Write meta data as attribute.
  for j := 0 to High(AWriteDocAttrs)
  do begin
    LMeta := ADocument.GetMetaByKey(AWriteDocAttrs[j]);

    // Attr are always written, while meta (cf. below) are only written
    // when known.
    LMeta := TrXmlEncode(LMeta);
    LStartTag += ' ' + AnsiLowerCase(AWriteDocAttrs[j]) + '="';
    if (LMeta = '')
    then LStartTag += 'unknown'
    else LStartTag += LMeta;
    LStartTag += '"';
  end;

  LStartTag += '>';
  AWriter.WriteString(LStartTag);

  // Write document meta information.
  for j := 0 to High(AWriteDocMetas)
  do begin
    LMeta := ADocument.GetMetaByKey(AWriteDocMetas[j]);
    if LMeta <> ''
    then begin

      // Convert reserved to entity.
      LMeta := TrXmlEncode(LMeta);
      AWriter.WriteString('<meta name="' +
        AnsiLowerCase(AWriteDocMetas[j]) + '" content="' + LMeta +
        '" />');
    end;
  end;

  // Write document meta information in containers.
  for j := 0 to High(AWriteDocContainers)
  do begin
    LMeta := ADocument.GetMetaByKey(AWriteDocContainers[j]);
    if LMeta <> ''
    then begin

      // Convert reserved to entity.
      LMeta := TrXmlEncode(LMeta);
      AWriter.WriteString('<' + AnsiLowerCase(AWriteDocContainers[j]) +
        '>');
      AWriter.WriteString(LMeta);
      AWriter.WriteString('</' + AnsiLowerCase(AWriteDocContainers[j]) +
        '>');
    end;
  end;

  // Write the paraghraphs.
  for i := 0 to ADocument.Number-1
  do begin

    // Only write good paragraphs.
    if not Assigned(ADocument[i])
    or not ADocument[i].Valid
    then Continue;

    if (ADocument[i].IsDuplicateOf <> -1)
    then begin
      if AWriteDups
      then begin
        AWriter.WriteString('<dup idx="' + IntToStr(i) +
        '" of="' + IntToStr(ADocument[i].IsDuplicateOf) +'">');
        AWriter.WriteString(ADupBlank);
        AWriter.WriteString('</dup>');
      end;

    end
    else with AWriter
    do begin
      LStartTag := '<div idx="' + IntToStr(i) + '"';

      // Write boilerplate class.
      LBpc := TrBoilerToBpc(ADocument[i].BoilerplateScore);
      LStartTag += ' bpc="' + LBpc + '"';

      // Write boilerplate value.
      LStartTag += ' bpv="' +
        FloatToStrF(ADocument[i].BoilerplateScore, ffGeneral, 6, 4) + '"';

      // Write div meta information as attributes.
      for j := 0 to High(AWriteDivAttrs)
      do begin
        LMeta := ADocument[i].GetMetaByKey(AWriteDivAttrs[j]);

        // Attr are always written, while meta (cf. below) are only
        // written when defined.
        LMeta := TrXmlEncode(LMeta);
        LStartTag += ' ' + AnsiLowerCase(AWriteDivAttrs[j]) + '="';
        if (LMeta = '')
        then LStartTag += 'unknown'
        else LStartTag += LMeta;
        LStartTag += '"';
      end;

      LStartTag += '>';
      WriteString(LStartTag);

      // Write paragraph meta information.
      for j := 0 to High(AWriteDivMetas)
      do begin
        LMeta := ADocument[i].GetMetaByKey(AWriteDivMetas[j]);
        if LMeta <> ''
        then begin

          // Strictify XML.
          LMeta := TrXmlEncode(LMeta);
          AWriter.WriteString('<meta name="' +
            AnsiLowerCase(AWriteDivMetas[j]) + '" content="' +
            LMeta + '" />');
        end;
      end;

      // Write paragraph metrics.
      if AWriteDivMetrics
      then begin
        LMetrics := '<metrics value="';
        for j := 0 to High(ADocument[i].Metrics)
        do begin
          LMetrics += FloatToStrF(ADocument[i].Metrics[j],
            ffGeneral, 7, 6);
          if j < High(ADocument[i].Metrics)
          then LMetrics += ' ';
        end;
        LMetrics += '" />';
        AWriter.WriteString(LMetrics);
      end;

      if AWriteText
      then WriteString(TrXmlEncode(Trim(DelSpace1(ADocument[i].Text))));
      WriteString('</div>');
    end;
  end;

  AWriter.WriteString('</doc>');

  // Add the difference in out stream position as bytes written.
  Result := AWriter.Bytes-Result;

  // Start new XML corpus file is limit reached.
  if  (ASplitSize > 0)
  and (AWriter.Position > ASplitSize)
  then AWriter.CreateNextFile;
end;


procedure TrWriteTokens(const ADocument : TTrDocument;
  const AWriteMaxTokens : Integer; const AWriter : TTrFileOut;
  const ASplitSize : Integer); inline;
var
  i : Integer;
  LData : TStringList = nil;
begin
  ADocument.TypeTokenData.SortTypesByFrequency;
  LData := ADocument.TypeTokenData.TypeCsv;
  try

    // Write document ID and type/token counts
    AWriter.WriteString('# ' + ADocument.Id + #9 +
      IntToStr(ADocument.TypeTokenData.TypeCount)+ #9 +
      IntToStr(ADocument.TypeTokenData.TokenCount));

    // Write the top n types with their counts.
    for i := 0 to LData.Count-1
    do begin
      AWriter.WriteString(LData[i]);

      // If we have reached the maximum number of tokens to write for
      // each document, just exit the loop.
      if  (AWriteMaxTokens > 0)
      and (i >= AWriteMaxTokens-1)
      then Break;
    end;

  finally
    FreeAndNil(LData);
  end;

  // Start new token data file if limit reached.
  if (ASplitSize > 0)
  and (AWriter.Position > ASplitSize)
  then AWriter.CreateNextFile;
end;


procedure TrWriteTarc(const ADocument : TTrDocument; const AWriter : TTrFileOut;
  const ASplitSize : Integer); inline;
var
  LHeaderStart : Integer;
  LOffset : Integer;
begin
  AWriter.WriteString('TARC/1.0'#10);

  // Get header part.
  LHeaderStart := Pos(#60, ADocument.RawText);

  // If no < can be found, something is wrong, and we record that.
  if (LHeaderStart < 1)
  then begin
    ADocument.AddMeta('tarcfile', 'dumped');
    ADocument.AddMeta('tarcheaderoffset', '-1');
    ADocument.AddMeta('tarcheaderlength', '-1');
    ADocument.AddMeta('tarcbodyoffset', '-1');
    ADocument.AddMeta('tarcbodylength', '-1');
    Exit;
  end;

  // This won't change and can be set at start.
  ADocument.AddMeta('tarcfile', AWriter.FileName);

  // Record for HEADER where we are in output stream (= offset).
  LOffset := AWriter.Position;

  // Just dump raw stuff: Header first.
  AWriter.WriteString(Trim(DelSpace1(AnsiLeftStr(ADocument.RawText,
    LHeaderStart-1))));

  // Add HEADER indexing information to XML output.
  ADocument.AddMeta('tarcheaderoffset', IntToStr(LOffset));
  ADocument.AddMeta('tarcheaderlength',
    IntToStr(AWriter.Position-LOffset));

  AWriter.WriteString('');

  // Record for BODY where we are in output stream (= offset).
  LOffset := AWriter.Position;

  // Now HTML dump.
  AWriter.WriteString(AnsiRightStr(ADocument.RawText,
    1 + ADocument.RawSize - LHeaderStart));
  AWriter.WriteString(#10);

  // Add BODY indexing information to XML output.
  ADocument.AddMeta('tarcbodyoffset', IntToStr(LOffset));
  ADocument.AddMeta('tarcbodylength',
    IntToStr(AWriter.Position-LOffset));

  // Start new TARC file if limit reached.
  if (ASplitSize > 0)
  and (AWriter.Position > ASplitSize)
  then AWriter.CreateNextFile;
end;



function TrWriteLinks(const ADocument : TTrDocument;
  const AWriter : TTrFileOut; const ASplitSize : Integer;
  const AWriteIdInsteadOfUrl : Boolean = false) : Integer; inline;
var
  i, j : Integer;
  LMeta : String;
begin
  Result := 0;
  for i := 0 to ADocument.Number-1
  do begin
    for j := 0 to High(ADocument[i].Links)
    do begin
      LMeta := ADocument[i].Links[j];

      // Fix "http://http://" links.
      if  (Length(LMeta) >= 18)
      and (AnsiLeftStr(LMeta, 14) = 'http://http://')
      then LMeta := AnsiRightStr(LMeta, Length(LMeta)-7);

      try
        if  (Length(LMeta) > 4)
        and (not TrXmlFilter(LMeta))
        then begin
          if AWriteIdInsteadOfUrl
          then AWriter.WriteString(ADocument.Id + ':' + IntToStr(i) + #9 +
            LMeta + #9 + FloatToStrF(ADocument.Badness, ffGeneral, 6, 4) + #9 +
            FloatToStrF(ADocument[i].BoilerplateScore, ffGeneral, 6, 4))
          else AWriter.WriteString(ADocument.Url + #9 + LMeta + #9 +
            FloatToStrF(ADocument.Badness, ffGeneral, 6, 4) + #9 +
            FloatToStrF(ADocument[i].BoilerplateScore, ffGeneral, 6, 4));
          Inc(Result)
        end;
      except
        TrDebug('TrWriteLinks() Malformed URI: ' + LMeta,
          Exception(ExceptObject), tdbInfo);
      end;
    end;
  end;

  // Start new link file if limit reached.
  if (ASplitSize > 0)
  and (AWriter.Position > ASplitSize)
  then AWriter.CreateNextFile;
end;


procedure TrWriteShingles(const ADocument : TTrDocument;
  const AWriter : TTrFileOut; const ASplitSize : Integer); inline;
var
  i : Integer;
  LDocSize : String;
begin
  if not Assigned(ADocument)
  or (ADocument.FingerprintSize < 1)
  then Exit;

  LDocSize := TrPad(10, IntToStr(ADocument.Size));

  // Write shingles.
  for i := 0 to ADocument.FingerprintSize-1
  do AWriter.WriteString(
    TrPad(20, IntToStr(ADocument.Fingerprint[i]))
    + ' ' + ADocument.Id +  ' ' + LDocSize);

  // Start new shingle file if limit reached.
  if (ASplitSize > 0)
  and (AWriter.Position > ASplitSize)
  then AWriter.CreateNextFile;
end;


end.
