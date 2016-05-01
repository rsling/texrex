

  // A streaming file writer with automatic or manual file splitting
  // and transparent gzipping.
  TTrFileOut = class(TObject)
  public
    constructor Create(const APrefix: String;
      const ASuffix : String; AAutoSplitSize : Integer = 0;
      AGzip : Boolean = true); overload;
    constructor Create(const ASingleFileName: String;
      AGzip : Boolean = true); overload;
    destructor Destroy; override;

    // The following write functions are buffered.
    procedure WriteChar(const AChar : Char); inline;
    procedure WriteString(const AString : String);

    // This is called automatically if an auto-split value is set, but
    // the caller can also call it manually if splitting should to occur
    // under conditions only her/him can control (like at document end).
    procedure CreateNextFile;
    procedure Flush;
  protected
    FStream : TStream;                 // Either File of Gzip stream.
    FBuffer : array[0..GBufferSize] of Char;
    FBufferPosition : Integer;        // Current position in buffer.
    FBytes : QWord;
    FFileName : String;               // Current full file name.
    FSingleFilename : String;         // In single-file mode, this is
                                       // used as a fixed filename.
    FPrefix : String;                 // File name prefix.
    FSuffix : String;                 // File name suffix.
    FAutoSplitSize : Integer;         // Split file after n bytes.
    FCounter : Integer;               // Current file number.
    FGzip : Boolean;                  // Whether to compress files.
    function GetPosition : Integer;
  public

    // Returns how many bytes were written, considering buffer.
    property Position : Integer read GetPosition;
    property Bytes : QWord read FBytes;
    property FileName : String read FFileName;
    property Counter : Integer read FCounter;

    property Prefix : String read FPrefix write FPrefix;
    property Suffix : String read FSuffix write FSuffix;
    property AutoSplitSize : Integer read FAutoSplitSize
      write FAutoSplitSize;
    property Gzip : Boolean read FGzip write FGzip;
  end;
