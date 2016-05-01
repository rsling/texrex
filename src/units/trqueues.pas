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

unit TrQueues;

{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  Classes,
  Contnrs,
  SyncObjs,
  SysUtils,
  IniFiles,
  TrData;


type

  ETrQueues = class(Exception);

  // The reasonably thread-safe queue to push and pop documents from
  // different threads.
  TTrDocumentQueue = class(TObject)
  public
    constructor Create(const AMaxLength : QWord;
      const AName : String = 'Unnamed');
    destructor Destroy; override;

    // Pushes a document on the queue in a thread-safe manner. Returns
    // false if the queue is full, true if the document was added.
    // If the documents were pushed, both Push functions nil the
    // document reference(s) to avoid dangling references.
    function PushDocument(var ADocument : TTrDocument) : Boolean;
    function PushDocuments(ADocuments : TTrDocumentArray;
      ACount : Integer) : Boolean;

    // This pops a document from the queue in a thread-safe manner.
    // If nil is returned, the queue is empty or some other error
    // ocurred.
    function PopDocument(out ADocument : TTrDocument) : Boolean;
    function PopDocuments(ACount : Integer) : TTrDocumentArray;

  protected
    FName : String;
    FQueue : TObjectQueue;
    FMaxLength : QWord;

    // This critical section is used in PushDocument and PopDocument
    // to make the queue thread-safe. Using Push and Pop of TObjectQueue
    // must be avoided in a threaded situation.
    FLock : TCriticalSection;
    function GetLength : QWord;
  public
    property Name : String read FName;
    property Length : QWord read GetLength;
    property MaxLength : QWord read FMaxLength write FMaxLength;
  end;


implementation


{ *** TTrDocumentQueue *** }


constructor TTrDocumentQueue.Create(const AMaxLength : QWord;
    const AName : String = 'Unnamed');
begin
  FName := AName;
  FMaxLength := AMaxLength;
  FQueue := TObjectQueue.Create;
  FLock := TCriticalSection.Create;
end;


destructor TTrDocumentQueue.Destroy;
var
  LDocument : TTrDocument = nil;
begin

  FLock.TryEnter;

  // Destroy the the objects, if any are left in the queue (normally
  // none).
  if FQueue.Count > 0
  then begin
    LDocument := FQueue.Pop as TTrDocument;
    while Assigned(LDocument)
    do begin
      FreeAndNil(LDocument);
      LDocument := FQueue.Pop as TTrDocument;
    end;
  end;

  // Free low-level queue.
  FreeAndNil(FQueue);

  FLock.Leave;

  // Free the critical section.
  FreeAndNil(FLock);
end;


function TTrDocumentQueue.PushDocument(var ADocument : TTrDocument) :
  Boolean;
begin

  // Only if the document was successfully pushed do we set this true.
  Result := false;

  // If someone passes a nil object, do nothing.
  if (not Assigned(ADocument))
  or (FQueue.Count + 1 > FMaxLength)
  then Exit;

  // Acquire the mutex if possible, else exit immediately with
  // Result still = false.
  if FLock.TryEnter
  then begin
    try

      // Nil the document when it was pushed to avoid dangling
      // references.
      if (FQueue.Push(ADocument as TObject) = (ADocument as TObject))
      then ADocument := nil;

      // If an exception occurs in Push, then this will never be
      // called.
      Result := true;
    finally

      // Release the mutex, even if there were errors.
      FLock.Leave;
    end;
  end;
end;


function TTrDocumentQueue.PushDocuments(ADocuments : TTrDocumentArray;
  ACount : Integer) : Boolean;
var
  LCount : Integer;
  i : Integer;
begin

  // Only if the documents were successfully pushed do we set this true.
  Result := false;

  if (High(ADocuments)+1 < ACount)
  then LCount := (High(ADocuments)+1)
  else LCount := ACount;

  // If queue is full, just exit with "false" result.
  if (FQueue.Count + LCount > FMaxLength)
  then Exit;

  // Acquire the mutex if possible, else exit immediately with
  // Result still = false.
  if FLock.TryEnter
  then begin
    try
      for i := 0 to LCount-1
      do begin
        if Assigned(ADocuments[i])
        then begin

          // If the object was pushed, nil the passed pointer to
          // signalize pusher that it is gone. No dangling references.
          if (FQueue.Push(ADocuments[i] as TObject) =
            (ADocuments[i] as TObject))
          then ADocuments[i] := nil;
        end;
      end;

      // If an exception occurs in Push, then this will never be
      // called.
      Result := true;
    finally

      // Release the mutex, even if there were errors.
      FLock.Leave;
    end;
  end;
end;



function TTrDocumentQueue.PopDocument(out ADocument : TTrDocument) :
  Boolean;
begin
  ADocument := nil;
  Result := False;

  // If we are empty, we skip the lock acquisition.
  if FQueue.Count < 1
  then Exit;

  if FLock.TryEnter
  then begin
    try

      // Use low-level pop and explicitly cast result.
      ADocument := FQueue.Pop as TTrDocument;

      if Assigned(ADocument)
      then Result := true;
    finally
      FLock.Leave;
    end;
  end;
end;


function TTrDocumentQueue.PopDocuments(ACount : Integer) :
  TTrDocumentArray;
var
  LCount : Integer;
  i : Integer;
begin

  // If we are empty, we skip the lock acquisition and return 0-array.
  if FQueue.Count < 1
  then begin
    SetLength(Result, 0);
    Exit;
  end;

  if FQueue.Count < ACount
  then LCount := FQueue.Count
  else LCount := ACount;
  SetLength(Result, LCount);

  if FLock.TryEnter
  then begin
    try

      // Use low-level pop and explicitly cast result.
      for i := 0 to LCount-1
      do Result[i] := FQueue.Pop as TTrDocument;

    finally
      FLock.Leave;
    end;
  end;
end;



function TTrDocumentQueue.GetLength : QWord;
begin
  Result := QWord(FQueue.Count);
end;


end.
