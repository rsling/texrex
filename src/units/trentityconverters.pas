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


unit TrEntityConverters;

{$MODE OBJFPC}
{$H+}
{$M+}



interface

uses
  SysUtils,
  StrUtils,
  Contnrs,
  IcuWrappers,
  TrUtilities;


type

  ETrEntityConverter = class(Exception);

  // A simple class to convert entities into UTF-8.
  TTrUtf8EntityConverter = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;

    // Convert an string, which should be an entity (from & to ;
    // – including those two) to a Utf8-encoded Unicode codepoint.
    function Convert(const AInput : String) : Utf8String;

    // A convenient function to convert all entities in a string.
    function ConvertString(const AIn : Utf8String) : Utf8String;
  protected
    FMatchHexIcu : TIcuRegex;
    FMatchDecIcu : TIcuRegex;
  end;


implementation


var
  MatchHex : String = '&#[xX]([0-9a-fA-F]{1,4});';
  MatchDec : String = '&#([0-9]+);';

type
  TTrConversion = packed record
    Input  : ShortString;
    Output : ShortString;
  end;
  TTrConversions = array[0..253] of TTrConversion;

const
  ConversionsHigh = 253;
  EntityChars : TSysCharset = ['#', 'a'..'z', 'A'..'Z', '0'..'9'];

  Conversions : TTrConversions = (
    (Input: '&Acirc;'; Output: '&#194;'; ),
    (Input: '&acirc;'; Output: '&#226;'; ),
    (Input: '&acute;'; Output: '&#180;'; ),
    (Input: '&Aacute;'; Output: '&#193;'; ),
    (Input: '&aacute;'; Output: '&#225;'; ),
    (Input: '&AElig;'; Output: '&#198;'; ),
    (Input: '&aelig;'; Output: '&#230;'; ),
    (Input: '&Agrave;'; Output: '&#192;'; ),
    (Input: '&agrave;'; Output: '&#224;'; ),
    (Input: '&alefsym;'; Output: '&#8501;'; ),
    (Input: '&Alpha;'; Output: '&#913;'; ),
    (Input: '&alpha;'; Output: '&#945;'; ),
    (Input: '&amp;'; Output: '&#38;'; ),
    (Input: '&and;'; Output: '&#8743;'; ),
    (Input: '&ang;'; Output: '&#8736;'; ),
    (Input: '&apos;'; Output: '&#39;'; ),
    (Input: '&Aring;'; Output: '&#197;'; ),
    (Input: '&aring;'; Output: '&#229;'; ),
    (Input: '&asymp;'; Output: '&#8776;'; ),
    (Input: '&Atilde;'; Output: '&#195;'; ),
    (Input: '&atilde;'; Output: '&#227;'; ),
    (Input: '&Auml;'; Output: '&#196;'; ),
    (Input: '&auml;'; Output: '&#228;'; ),
    (Input: '&bdquo;'; Output: '&#8222;'; ),
    (Input: '&Beta;'; Output: '&#914;'; ),
    (Input: '&beta;'; Output: '&#946;'; ),
    (Input: '&brvbar;'; Output: '&#166;'; ),
    (Input: '&bull;'; Output: '&#8226;'; ),
    (Input: '&cap;'; Output: '&#8745;'; ),
    (Input: '&Ccedil;'; Output: '&#199;'; ),
    (Input: '&ccedil;'; Output: '&#231;'; ),
    (Input: '&cedil;'; Output: '&#184;'; ),
    (Input: '&cent;'; Output: '&#162;'; ),
    (Input: '&Chi;'; Output: '&#935;'; ),
    (Input: '&chi;'; Output: '&#967;'; ),
    (Input: '&circ;'; Output: '&#710;'; ),
    (Input: '&clubs;'; Output: '&#9827;'; ),
    (Input: '&cong;'; Output: '&#8773;'; ),
    (Input: '&copy;'; Output: '&#169;'; ),
    (Input: '&crarr;'; Output: '&#8629;'; ),
    (Input: '&cup;'; Output: '&#8746;'; ),
    (Input: '&curren;'; Output: '&#164;'; ),
    (Input: '&Dagger;'; Output: '&#8225;'; ),
    (Input: '&dagger;'; Output: '&#8224;'; ),
    (Input: '&dArr;'; Output: '&#8659;'; ),
    (Input: '&darr;'; Output: '&#8595;'; ),
    (Input: '&deg;'; Output: '&#176;'; ),
    (Input: '&Delta;'; Output: '&#916;'; ),
    (Input: '&delta;'; Output: '&#948;'; ),
    (Input: '&diams;'; Output: '&v#9830;'; ),
    (Input: '&divide;'; Output: '&#247;'; ),
    (Input: '&Eacute;'; Output: '&#201;'; ),
    (Input: '&eacute;'; Output: '&#233;'; ),
    (Input: '&Ecirc;'; Output: '&#202;'; ),
    (Input: '&ecirc;'; Output: '&#234;'; ),
    (Input: '&Egrave;'; Output: '&#200;'; ),
    (Input: '&egrave;'; Output: '&#232;'; ),
    (Input: '&empty;'; Output: '&#8709;'; ),
    (Input: '&emsp;'; Output: '&#8195;'; ),
    (Input: '&ensp;'; Output: '&#8194;'; ),
    (Input: '&Epsilon;'; Output: '&#917;'; ),
    (Input: '&epsilon;'; Output: '&#949;'; ),
    (Input: '&equiv;'; Output: '&#8801;'; ),
    (Input: '&Eta;'; Output: '&#919;'; ),
    (Input: '&eta;'; Output: '&#951;'; ),
    (Input: '&ETH;'; Output: '&#208;'; ),
    (Input: '&Eth;'; Output: '&#208;'; ),
    (Input: '&eth;'; Output: '&#240;'; ),
    (Input: '&Euml;'; Output: '&#203;'; ),
    (Input: '&euml;'; Output: '&#235;'; ),
    (Input: '&euro;'; Output: '&#8364;'; ),
    (Input: '&exist;'; Output: '&#8707;'; ),
    (Input: '&fnof;'; Output: '&#402;'; ),
    (Input: '&forall;'; Output: '&#8704;'; ),
    (Input: '&frac12;'; Output: '&#189;'; ),
    (Input: '&frac14;'; Output: '&#188;'; ),
    (Input: '&frac34;'; Output: '&#190;'; ),
    (Input: '&frasl;'; Output: '&#8260;'; ),
    (Input: '&Gamma;'; Output: '&#915;'; ),
    (Input: '&gamma;'; Output: '&#947;'; ),
    (Input: '&ge;'; Output: '&#8805;'; ),
    (Input: '&gt;'; Output: '&#62;'; ),
    (Input: '&hArr;'; Output: '&#8660;'; ),
    (Input: '&harr;'; Output: '&#8596;'; ),
    (Input: '&hearts;'; Output: '&#9829;'; ),
    (Input: '&hellip;'; Output: '&#8230;'; ),
    (Input: '&Iacute;'; Output: '&#205;'; ),
    (Input: '&iacute;'; Output: '&#237;'; ),
    (Input: '&Icirc;'; Output: '&#206;'; ),
    (Input: '&icirc;'; Output: '&#238;'; ),
    (Input: '&iexcl;'; Output: '&#161;'; ),
    (Input: '&Igrave;'; Output: '&#204;'; ),
    (Input: '&igrave;'; Output: '&#236;'; ),
    (Input: '&image;'; Output: '&#8465;'; ),
    (Input: '&infin;'; Output: '&#8734;'; ),
    (Input: '&int;'; Output: '&#8747;'; ),
    (Input: '&Iota;'; Output: '&#921;'; ),
    (Input: '&iota;'; Output: '&#953;'; ),
    (Input: '&iquest;'; Output: '&#191;'; ),
    (Input: '&isin;'; Output: '&#8712;'; ),
    (Input: '&Iuml;'; Output: '&#207;'; ),
    (Input: '&iuml;'; Output: '&#239;'; ),
    (Input: '&Kappa;'; Output: '&#922;'; ),
    (Input: '&kappa;'; Output: '&#954;'; ),
    (Input: '&Lambda;'; Output: '&#923;'; ),
    (Input: '&lambda;'; Output: '&#955;'; ),
    (Input: '&lang;'; Output: '&#9001;'; ),
    (Input: '&laquo;'; Output: '&#171;'; ),
    (Input: '&lArr;'; Output: '&#8656;'; ),
    (Input: '&larr;'; Output: '&#8592;'; ),
    (Input: '&lceil;'; Output: '&#8968;'; ),
    (Input: '&ldquo;'; Output: '&#8220;'; ),
    (Input: '&le;'; Output: '&#8804;'; ),
    (Input: '&lfloor;'; Output: '&#8970;'; ),
    (Input: '&lowast;'; Output: '&#8727;'; ),
    (Input: '&loz;'; Output: '&#9674;'; ),
    (Input: '&lrm;'; Output: '&#8206;'; ),
    (Input: '&lsaquo;'; Output: '&#8249;'; ),
    (Input: '&lsquo;'; Output: '&#8216;'; ),
    (Input: '&lt;'; Output: '&#60;'; ),
    (Input: '&macr;'; Output: '&#175;'; ),
    (Input: '&mdash;'; Output: '&#8212;'; ),
    (Input: '&micro;'; Output: '&#181;'; ),
    (Input: '&middot;'; Output: '&#183;'; ),
    (Input: '&minus;'; Output: '&#8722;'; ),
    (Input: '&Mu;'; Output: '&#924;'; ),
    (Input: '&mu;'; Output: '&#956;'; ),
    (Input: '&nabla;'; Output: '&#8711;'; ),
    (Input: '&nbsp;'; Output: '&#160;'; ),
    (Input: '&ndash;'; Output: '&#8211;'; ),
    (Input: '&ne;'; Output: '&#8800;'; ),
    (Input: '&ni;'; Output: '&#8715;'; ),
    (Input: '&not;'; Output: '&#172;'; ),
    (Input: '&notin;'; Output: '&#8713;'; ),
    (Input: '&nsub;'; Output: '&#8836;'; ),
    (Input: '&Ntilde;'; Output: '&#209;'; ),
    (Input: '&ntilde;'; Output: '&#241;'; ),
    (Input: '&Nu;'; Output: '&#925;'; ),
    (Input: '&nu;'; Output: '&#957;'; ),
    (Input: '&Oacute;'; Output: '&#211;'; ),
    (Input: '&oacute;'; Output: '&#243;'; ),
    (Input: '&Ocirc;'; Output: '&#212;'; ),
    (Input: '&ocirc;'; Output: '&#244;'; ),
    (Input: '&OElig;'; Output: '&#338;'; ),
    (Input: '&oelig;'; Output: '&#339;'; ),
    (Input: '&Ograve;'; Output: '&#210;'; ),
    (Input: '&ograve;'; Output: '&#242;'; ),
    (Input: '&oline;'; Output: '&#8254;'; ),
    (Input: '&Omega;'; Output: '&#937;'; ),
    (Input: '&omega;'; Output: '&#969;'; ),
    (Input: '&Omicron;'; Output: '&#927;'; ),
    (Input: '&omicron;'; Output: '&#959;'; ),
    (Input: '&oplus;'; Output: '&#8853;'; ),
    (Input: '&or;'; Output: '&#8744;'; ),
    (Input: '&ordf;'; Output: '&#170;'; ),
    (Input: '&ordm;'; Output: '&#186;'; ),
    (Input: '&Oslash;'; Output: '&#216;'; ),
    (Input: '&oslash;'; Output: '&#248;'; ),
    (Input: '&Otilde;'; Output: '&#213;'; ),
    (Input: '&otilde;'; Output: '&#245;'; ),
    (Input: '&otimes;'; Output: '&#8855;'; ),
    (Input: '&Ouml;'; Output: '&#214;'; ),
    (Input: '&ouml;'; Output: '&#246;'; ),
    (Input: '&para;'; Output: '&#182;'; ),
    (Input: '&part;'; Output: '&#8706;'; ),
    (Input: '&permil;'; Output: '&#8240;'; ),
    (Input: '&perp;'; Output: '&#8869;'; ),
    (Input: '&Phi;'; Output: '&#934;'; ),
    (Input: '&phi;'; Output: '&#966;'; ),
    (Input: '&Pi;'; Output: '&#928;'; ),
    (Input: '&pi;'; Output: '&#960;'; ),
    (Input: '&piv;'; Output: '&#982;'; ),
    (Input: '&plusmn;'; Output: '&#177;'; ),
    (Input: '&pound;'; Output: '&#163;'; ),
    (Input: '&Prime;'; Output: '&#8243;'; ),
    (Input: '&prime;'; Output: '&#8242;'; ),
    (Input: '&prod;'; Output: '&#8719;'; ),
    (Input: '&prop;'; Output: '&#8733;'; ),
    (Input: '&Psi;'; Output: '&#936;'; ),
    (Input: '&psi;'; Output: '&#968;'; ),
    (Input: '&quot;'; Output: '&#34;'; ),
    (Input: '&radic;'; Output: '&#8730;'; ),
    (Input: '&rang;'; Output: '&#9002;'; ),
    (Input: '&raquo;'; Output: '&#187;'; ),
    (Input: '&rArr;'; Output: '&#8658;'; ),
    (Input: '&rarr;'; Output: '&#8594;'; ),
    (Input: '&rceil;'; Output: '&#8969;'; ),
    (Input: '&rdquo;'; Output: '&#8221;'; ),
    (Input: '&real;'; Output: '&#8476;'; ),
    (Input: '&reg;'; Output: '&#174;'; ),
    (Input: '&rfloor;'; Output: '&#8971;'; ),
    (Input: '&Rho;'; Output: '&#929;'; ),
    (Input: '&rho;'; Output: '&#961;'; ),
    (Input: '&rlm;'; Output: '&#8207;'; ),
    (Input: '&rsaquo;'; Output: '&#8250;'; ),
    (Input: '&rsquo;'; Output: '&#8217;'; ),
    (Input: '&sbquo;'; Output: '&#8218;'; ),
    (Input: '&Scaron;'; Output: '&#352;'; ),
    (Input: '&scaron;'; Output: '&#353;'; ),
    (Input: '&sdot;'; Output: '&#8901;'; ),
    (Input: '&sect;'; Output: '&#167;'; ),
    (Input: '&shy;'; Output: '&#173;'; ),
    (Input: '&Sigma;'; Output: '&#931;'; ),
    (Input: '&sigma;'; Output: '&#963;'; ),
    (Input: '&sigmaf;'; Output: '&#962;'; ),
    (Input: '&sim;'; Output: '&#8764;'; ),
    (Input: '&spades;'; Output: '&#9824;'; ),
    (Input: '&sub;'; Output: '&#8834;'; ),
    (Input: '&sube;'; Output: '&#8838;'; ),
    (Input: '&sum;'; Output: '&#8721;'; ),
    (Input: '&sup;'; Output: '&#8835;'; ),
    (Input: '&sup1;'; Output: '&#185;'; ),
    (Input: '&sup2;'; Output: '&#178;'; ),
    (Input: '&sup3;'; Output: '&#179;'; ),
    (Input: '&supe;'; Output: '&#8839;'; ),
    (Input: '&szlig;'; Output: '&#223;'; ),
    (Input: '&Tau;'; Output: '&#932;'; ),
    (Input: '&tau;'; Output: '&#964;'; ),
    (Input: '&there4;'; Output: '&#8756;'; ),
    (Input: '&Theta;'; Output: '&#920;'; ),
    (Input: '&theta;'; Output: '&#952;'; ),
    (Input: '&thetasym;'; Output: '&#977;'; ),
    (Input: '&thinsp;'; Output: '&#8201;'; ),
    (Input: '&THORN;'; Output: '&#222;'; ),
    (Input: '&thorn;'; Output: '&#254;'; ),
    (Input: '&tilde;'; Output: '&#732;'; ),
    (Input: '&times;'; Output: '&#215;'; ),
    (Input: '&trade;'; Output: '&#8482;'; ),
    (Input: '&Uacute;'; Output: '&#218;'; ),
    (Input: '&uacute;'; Output: '&#250;'; ),
    (Input: '&uArr;'; Output: '&#8657;'; ),
    (Input: '&uarr;'; Output: '&#8593;'; ),
    (Input: '&Ucirc;'; Output: '&#219;'; ),
    (Input: '&ucirc;'; Output: '&#251;'; ),
    (Input: '&Ugrave;'; Output: '&#217;'; ),
    (Input: '&ugrave;'; Output: '&#249;'; ),
    (Input: '&uml;'; Output: '&#168;'; ),
    (Input: '&upsih;'; Output: '&#978;'; ),
    (Input: '&Upsilon;'; Output: '&#933;'; ),
    (Input: '&upsilon;'; Output: '&#965;'; ),
    (Input: '&Uuml;'; Output: '&#220;'; ),
    (Input: '&uuml;'; Output: '&#252;'; ),
    (Input: '&weierp;'; Output: '&#8472;'; ),
    (Input: '&Xi;'; Output: '&#926;'; ),
    (Input: '&xi;'; Output: '&#958;'; ),
    (Input: '&Yacute;'; Output: '&#221;'; ),
    (Input: '&yacute;'; Output: '&#253;'; ),
    (Input: '&yen;'; Output: '&#165;'; ),
    (Input: '&Yuml;'; Output: '&#376;'; ),
    (Input: '&yuml;'; Output: '&#255;'; ),
    (Input: '&Zeta;'; Output: '&#918;'; ),
    (Input: '&zeta;'; Output: '&#950;'; ),
    (Input: '&zwj;'; Output: '&#8205;'; ),
    (Input: '&zwnj;'; Output: '&#8204;'; )
  );

function TTrUtf8EntityConverter.ConvertString(
  const AIn : Utf8String) : Utf8String;
var
  LCurrentHypStart: Integer = -1; // Where we found the current &. -1 means not found.
  LCurrentHypLength: Integer = 0; // Where we found ; relative to LCurrentHypStart.
  LPos : Integer = 1;             // Pointer into Result String.

  procedure HypoReset; inline;
  begin
    LCurrentHypStart := -1;
    LCurrentHypLength := 0;
  end;

  // Never call HypoReset from within this funtion.
  procedure DoEntityConvert;
  var
    LEntity : String;
  begin

    // This is a bit tricky. We need to split, convert, concatenate —
    // and then set the position to length(pre-entity) +
    // length(converted entity).
    LEntity := AnsiMidStr(Result, LCurrentHypStart, LCurrentHypLength+1);
    LEntity := Convert(LEntity);

    // If nothing reasonable came back, just skip the replacement.
    if (LEntity = '')
    or (LEntity = ' ')
    then Exit;

    // Now concatenate.
    Result := AnsiLeftStr(Result, LCurrentHypStart-1)
      + LEntity + AnsiRightStr(Result,
        Length(Result) - (LCurrentHypStart + LCurrentHypLength));

    // Set Position.
    LPos := (LCurrentHypStart-1) + Length(LEntity);
  end;

begin
  Result := AIn;

  // We go through the whole string.
  while LPos <= Length(Result)
  do begin

    // If we are not in a hypothetical entity right now, see if we have
    // to start one.
    if LCurrentHypStart < 0
    then begin
      if (Result[LPos] = '&')
      then begin
        LCurrentHypStart := LPos;
        LCurrentHypLength := 1;
      end;
    end

    // But if we are reading a hypothesis:
    else begin

      // READING And we're done, do conversion.
      if Result[LPos] = ';'
      then begin

        // We only convert if there is a minimal length.
        if LCurrentHypLength > 2
        then DoEntityConvert;

        // No matter what, after a ";", we restart hypothesizing.
        HypoReset;
      end

      // READING  But we see an illegal character, stop!
      else if not (Result[LPos] in EntityChars)
      then HypoReset

      // READING And we're becoming too long, stop!
      else if LCurrentHypLength > 7
      then HypoReset

      // Normal read in hypothesis, so increment its length.
      else Inc(LCurrentHypLength);

    end;

    Inc(LPos);
  end;
end;


function TTrUtf8EntityConverter.Convert(const AInput : String) :
  Utf8String;
var
  LEntity : String;
  LCodepoint : Integer;
  i : Integer;
begin

  // First, get rid of hex.
  if FMatchHexIcu.Match(AInput, true, false)
  then LCodepoint :=
    StrToIntDef('$'+ FMatchHexIcu.Replace(AInput, '$1', true, false),
    32)

  // Not hex.
  else begin

    // Convert textual to dec.
    for i := 0 to ConversionsHigh
    do begin
      if Conversions[i].Input = AInput
      then begin
        LEntity := Conversions[i].Output;
        Break;
      end;
    end;

    // IF failed, must be dec.
    if LEntity = ''
    then LEntity := AInput;

    // Now, eveything is dec. Get codepoint.
    LCodepoint := StrToIntDef(
      FMatchDecIcu.Replace(LEntity, '$1', true, false), 32);
  end;

  // Finally, we catch the most perverse kind of mis-encoding: Win1252
  // codepoints which were encoded as numeric entities (most likely in
  // documents declared as ISO-8859-1).
  if  (LCodepoint >= $80)
  and (LCodepoint <= $9f)
  then begin
    case LCodepoint
    of
      $80 : LCodepoint := $20ac; // €
      $82 : LCodepoint := $201a; // ‚
      $83 : LCodepoint := $0192; // ƒ
      $84 : LCodepoint := $201e; // „
      $85 : LCodepoint := $2026; // …
      $86 : LCodepoint := $2020; // †
      $87 : LCodepoint := $2021; // ‡
      $88 : LCodepoint := $02c6; // ˆ
      $89 : LCodepoint := $2030; // ‰
      $8a : LCodepoint := $0160; // Š
      $8b : LCodepoint := $2039; // ‹
      $8c : LCodepoint := $0152; // Œ
      $8e : LCodepoint := $017d; // Ž
      $91 : LCodepoint := $2018; // ‘
      $92 : LCodepoint := $2019; // ’
      $93 : LCodepoint := $201c; // “
      $94 : LCodepoint := $201d; // ”
      $95 : LCodepoint := $2022; // •
      $96 : LCodepoint := $2013; // –
      $97 : LCodepoint := $2014; // —
      $98 : LCodepoint := $02dc; // ˜
      $99 : LCodepoint := $2122; // ™
      $9a : LCodepoint := $0161; // š
      $9b : LCodepoint := $203a; // ›
      $9c : LCodepoint := $0153; // œ
      $9e : LCodepoint := $017e; // ž
      $9f : LCodepoint := $0178; // Ÿ
    end;
  end;

  // Convert codepoint to UTF-8.
  Result := TrUtf8CodepointEncode(LCodepoint);
end;


destructor TTrUtf8EntityConverter.Destroy;
begin
  FreeAndNil(FMatchDecIcu);
  FreeAndNil(FMatchHexIcu);
  inherited Destroy;
end;


constructor TTrUtf8EntityConverter.Create;
begin
  FMatchHexIcu := TIcuRegex.Create(MatchHex);
  FMatchDecIcu := TIcuRegex.Create(MatchDec);
end;


end.



//  Writeln(#13#10, FEntityConverter.ConvertString('01 A Test&amp;Try example &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('02 A Test&amp;Try&nbsp;example &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('03 A Test&amp;Try exam&ple &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('04 A Test&amp;Try exam;ple &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('05 A Test&amp;Try example &quot;speziale&quot;! Works?&'));
//  Writeln(#13#10, FEntityConverter.ConvertString('06 A Test&amp;Try exa&;mple &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('07 A Test&amp;Try exa&ae;mple &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('08 A Test&amp;Try example &quot;&quot;speziale&quot;&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('09 A Test&amp;Try example &quot;speziale&quot;! Works?&szlig;'));
//  Writeln(#13#10, FEntityConverter.ConvertString('10 &auml;A Test&amp;Try example &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('11 A Test&amp;Try example&murks; &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('12 A Test&amp;Try example&ae lig; &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('13 A Test&amp;Try example&aélig; &quot;speziale&quot;! Works?'));
//  Writeln(#13#10, FEntityConverter.ConvertString('13 A Test&amp;Try example&aelig; &quot;speziale&quot;! Works?'));
