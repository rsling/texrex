

  // A streaming file reader with directory mode, transparent GZIP
  // decompression and more.
  TTrFileIn = class(TObject)
  public

    // Start using a single file name or directory name (directories
    // will be mercilessly processed in their entirety.
    constructor Create(const AFileName: String;
      AAutoAdvanceFile : Boolean = true;
      const AExternalGzip : String = ''); virtual;

    // This version takes a list of files instead of a single file or
    // directory name.
    constructor Create(const AFileList: TStringList;
      AAutoAdvanceFile : Boolean = true;
      const AExternalGzip : String = ''); virtual;

    destructor Destroy; override;

    // The following read functions are buffered.
    function ReadChar(out AChar : Char) : Boolean;
    function PeekChar(out AChar : Char) : Boolean;
    function ReadLine(out ALine : String) : Boolean;
    function PeekLine(out ALine : String) : Boolean;

    // This is called automatically if FAutoAdvanceFile.
    // It tries to load the next file if there is any.
    // If false, none of the remaining files could be opened
    // or there wasnt any file left.
    // Not using AutoAdvance is required if after an input file
    // there are actions to take.
    function AdvanceFile : Boolean;

  protected
    FDirectoryMode : Boolean;
    FFileList : TStringList;       // List of input files.
    FCurrentFile : Integer;        // Index into FFileList.
    FEos : Boolean;                // true := buffer and stream exhausted.

    FStream : TStream;             // FileStream or CompressionStream – or TInputPipeStream if piped from Gunzip.

    FProcess : TProcess;
    FExternalGzip : String;

    FPosition : QWord;             // Own position tracker for current input.
    FBuffer : array[0..GBufferSize] of Char;
    FBufferPosition : Integer;    // Current position in buffer.
    FBufferLimit : Integer;       // How far Buffer is filled.
    FBytes : QWord;
    FFileName : String;
    FAutoAdvanceFile : Boolean;   // Whether next file should be opened automatically.

    FPeekedLine : String;
    FLinePeeked : Boolean;

    procedure Fill;
    function GetBytes : QWord;
    function GetFileCount : Integer;
    function GetCurrentFileName : String;
    function GetLastFile : Boolean;
    function GetPeekedLine : String;
  public

    // Returns how many bytes were consumed, considering buffer.
    property Position : QWord read FPosition;
    property Bytes : QWord read GetBytes;
    property Eos : Boolean read FEos;
    property DirectoryMode : Boolean read FDirectoryMode;
    property FileCount : Integer read GetFileCount;
    property CurrentFile : Integer read FCurrentFile;
    property LastFile : Boolean read GetLastFile;
    property FileName : String read FFileName;
    property AutoAdvanceFile : Boolean read FAutoAdvanceFile
      write FAutoAdvanceFile;
    property CurrentFileName : String read GetCurrentFileName;

    // This returns an already peeked line or peeks a new one or
    // returns #0.
    property PeekedLine : String read GetPeekedLine;
  end;
