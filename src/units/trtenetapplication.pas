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


unit TrTenetApplication;


{$MODE OBJFPC}
{$H+}
{$M+}



interface


uses
  CustApp,
  Classes,
  Contnrs,
  SysUtils,
  StrUtils,
  Fann,
  TrVersionInfo,
  TrUtilities,
  TrFile,
  TrShingleHelpers;


type

  ETrTenetApplication = class(Exception);

  TTrTenetApplication = class(TCustomApplication)
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure Initialize; override;
    procedure ShowException(E:Exception); override;
  protected
    FAnn : Pfann;
    FAnnTrain : Pfann_train_data;
    FInFile : String;
    FOutFile : String;
    FEraseOutFile : Boolean;

    // Defaults.
    FNoInputs : Integer;
    FNoOutputs : Integer;
    FNoEpochs : Integer;
    FReportFreq : Integer;
    FDesMSE : Real;
    FHiddenLayer1 : Integer;
    FHiddenLayer2 : Integer;
    FHiddenLayer3 : Integer;
    FHiddenLayer4 : Integer;
    FHiddenLayer5 : Integer;
    FTrainAlgo : Integer;
    FActiHidden : Integer;
    FActiOut: Integer;
    FInitWeights : Boolean;
    FWidrow : Boolean;

    procedure SayError(const AError : String);
    procedure DoRun; override;
    procedure ShowHelp;
  end;


implementation



const
  OptNum=17;
  OptionsShort : array[0..OptNum] of Char = ('h', 'i', 'o', 'e', 'd',
    'r', 'm', 'I', 'O', '1', '2', '3', '4', '5', 't', 'H', 'a', 'w');
  OptionsLong : array[0..OptNum] of String = ('help', 'input', 'output',
    'erase', 'desire', 'report', 'maximum', 'innum', 'outnum', 'one',
    'two', 'three', 'four', 'five', 'train', 'hidden', 'activ',
    'widrow');




function TrTrainProc(Aann: Pfann; Atrain: Pfann_train_data;
  max_epochs: Cardinal; epochs_between_reports: cardinal;
  desired_error: single; epochs: cardinal): SmallInt; cdecl;
begin
  Writeln(fann_get_MSE(Aann));
  Result := (-1);
end;



constructor TTrTenetApplication.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);

  // Defaults.
  FNoInputs := 0;
  FNoOutputs := 0;
  FNoEpochs := 50000;
  FReportFreq := 1000;
  FDesMSE := Real(0.003);
  FHiddenLayer1 := 18;
  FHiddenLayer2 := 0;
  FHiddenLayer3 := 0;
  FHiddenLayer4 := 0;
  FHiddenLayer5 := 0;
  FTrainAlgo := FANN_TRAIN_RPROP;
  FActiHidden := FANN_SIGMOID_SYMMETRIC;
  FActiOut:= FANN_LINEAR_PIECE_SYMMETRIC;
  FInitWeights := true;
  FNoInputs := 37;
  FNoOutputs := 1;
  FWidrow := true;

  FAnn := nil;
  FAnnTrain := nil;
  FInFile := '';
  FOutFile := '';
  FEraseOutFile := false;
end;


destructor TTrTenetApplication.Destroy;
begin
  // Free everything and terminate.
  if Assigned(FAnnTrain)
  then fann_destroy_train(FAnnTrain);

  if Assigned(FAnn)
  then fann_destroy(FAnn);

  inherited Destroy;
end;


procedure TTrTenetApplication.Initialize;
var
  LOptionError : String;
begin
  inherited Initialize;

  Writeln(#10#13, 'tenet from ', TrName, '-', TrCode, ' (', TrVersion,
    ')', #10#13, TrMaintainer, #10#13);

  LOptionError := CheckOptions(OptionsShort, OptionsLong);
  if LOptionError <> ''
  then begin
    SayError(LOptionError);
    Exit;
  end;

  if HasOption('h', 'help')
  then begin
    ShowHelp;
    Terminate;
    Exit;
  end;

  // Obligatory options.

  if not HasOption('i', 'input')
  then begin
    SayError('No input file specified.');
    Exit;
  end;

  if not HasOption('o', 'output')
  then begin
    SayError('No output file specified.');
    Exit;
  end;

  FInFile := GetOptionValue('i', 'input');
  FOutFile := GetOptionValue('o', 'output');

  // Facultative options.

  if HasOption('e', 'erase')
  then FEraseOutFile := true;

  if HasOption('d', 'desire')
  then begin
    if (not TryStrToFloat(GetOptionValue('d', 'desire'), FDesMSE))
    or (FDesMSE < 0)
    then begin
      SayError('Desired MSE must be a positive real.');
      Exit;
    end;
  end;

  if HasOption('r', 'report')
  then begin
    if (not TryStrToInt(GetOptionValue('r', 'report'), FReportFreq))
    or (FReportFreq < 0)
    then begin
      SayError('Report frequency must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('m', 'maximum')
  then begin
    if (not TryStrToInt(GetOptionValue('m', 'maximum'), FNoEpochs))
    or (FNoEpochs < 0)
    then begin
      SayError('Maximum number of epochs must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('I', 'innum')
  then begin
    if (not TryStrToInt(GetOptionValue('I', 'innum'), FNoInputs))
    or (FNoInputs < 0)
    then begin
      SayError('Number of input neurons must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('O', 'outnum')
  then begin
    if (not TryStrToInt(GetOptionValue('O', 'outnum'), FNoOutputs))
    or (FNoOutputs < 0)
    then begin
      SayError('Number of output neurons must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('1', 'one')
  then begin
    if (not TryStrToInt(GetOptionValue('1', 'one'), FHiddenLayer1))
    or (FHiddenLayer1 < 0)
    then begin
      SayError('Neurons on hidden layer 1 must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('2', 'two')
  then begin
    if (not TryStrToInt(GetOptionValue('2', 'two'), FHiddenLayer2))
    or (FHiddenLayer2 < 0)
    then begin
      SayError('Neurons on hidden layer 2 must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('3', 'three')
  then begin
    if (not TryStrToInt(GetOptionValue('3', 'three'), FHiddenLayer3))
    or (FHiddenLayer3 < 0)
    then begin
      SayError('Neurons on hidden layer 3 must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('4', 'four')
  then begin
    if (not TryStrToInt(GetOptionValue('4', 'four'), FHiddenLayer4))
    or (FHiddenLayer4 < 0)
    then begin
      SayError('Neurons on hidden layer 4 must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('5', 'five')
  then begin
    if (not TryStrToInt(GetOptionValue('5', 'five'), FHiddenLayer5))
    or (FHiddenLayer5 < 0)
    then begin
      SayError('Neurons on hidden layer 5 must be a positive integer.');
      Exit;
    end;
  end;

  if HasOption('t', 'train')
  then begin
    FTrainAlgo := fann_train_index(GetOptionValue('t', 'train'));
    if FTrainAlgo = (-1)
    then begin
      SayError('Chosen training algorithm is unknown to FANN.');
      Exit;
    end;
  end;

  if HasOption('H', 'hidden')
  then begin
    FActiHidden := fann_activationfunc_index(GetOptionValue('H',
      'hidden'));
    if FActiHidden = (-1)
    then begin
      SayError('Chosen hidden activation function is unknown to FANN.');
      Exit;
    end;
  end;

  if HasOption('a', 'activ')
  then begin
    FActiOut := fann_activationfunc_index(GetOptionValue('a',
      'activ'));
    if FActiOut = (-1)
    then begin
      SayError('Chosen output activation function is unknown to FANN.');
      Exit;
    end;
  end;

  if HasOption('w', 'widrow')
  then FWidrow := false;

end;


procedure TTrTenetApplication.ShowException(E:Exception);
begin
  TrDebug(ClassName, Exception(ExceptObject));
end;



procedure TTrTenetApplication.DoRun;
begin
  if not Terminated
  then begin

    // Check whether input exists.
    if not FileExists(FInFile)
    then begin
      SayError('Input file does not exist.');
      Exit;
    end;

    // Check whether an outfile alread exists. If so, delete or exit.
    if FileExists(FOutFile)
    then begin
      if (not FEraseOutFile)
      then begin
        SayError('Output file exists. Use -e option to erase.');
        Exit;
      end
      else DeleteFile(FOutFile);
    end;

    // Load and examine train data.
    FAnnTrain := fann_read_train_from_file(PChar(FInFile));

    if not Assigned(FAnnTrain)
    then begin
      SayError('There was an error loading train data.');
      Exit;
    end;

    // The first layer that has 0 neurons is the first one which will not
    // be created (no matter how subsequent layers are configured).
    if FHiddenLayer1 <> 0
    then
      if FHiddenLayer2 <> 0
      then
        if FHiddenLayer3 <> 0
        then
          if FHiddenLayer4 <> 0
          then
            if FHiddenLayer5 <> 0
            then FAnn := fann_create_standard(7, FNoInputs,
              FHiddenLayer1, FHiddenLayer2, FHiddenLayer3,
              FHiddenLayer4, FHiddenLayer5, FNoOutputs)
            else FAnn := fann_create_standard(6, FNoInputs,
              FHiddenLayer1, FHiddenLayer2, FHiddenLayer3,
              FHiddenLayer4, FNoOutputs)
          else FAnn := fann_create_standard(5, FNoInputs, FHiddenLayer1,
            FHiddenLayer2, FHiddenLayer3, FNoOutputs)
        else FAnn := fann_create_standard(4, FNoInputs, FHiddenLayer1,
          FHiddenLayer2, FNoOutputs)
      else FAnn := fann_create_standard(3, FNoInputs, FHiddenLayer1,
        FNoOutputs)
    else FAnn := fann_create_standard(2, FNoInputs, FNoOutputs);


    fann_set_training_algorithm(FAnn, FTrainAlgo);
    fann_set_activation_function_hidden(FAnn, FActiHidden);
    fann_set_activation_function_output(FAnn, FActiOut);

    if FInitWeights
    then fann_init_weights(FAnn, FAnnTrain);

    fann_train_on_data(FAnn, FAnnTrain, FNoEpochs, FReportFreq,
      FDesMSE);
    fann_save(FAnn, PChar(FOutFile));

    Terminate;
  end;
end;


procedure TTrTenetApplication.ShowHelp;
begin
  Writeln(#10#13'Usage: tenet [OPTIONS]');
  Writeln;
  Writeln('Options which take a value and have no [DEFAULT] are obligatory.');
  Writeln;
  Writeln(' --help    -h   Print this help and exit.');
  Writeln(' --input   -i S Input file with training data in FANN format.');
  Writeln(' --output  -o S Output file name.');
  Writeln(' --erase   -e   Erase output file first, if it exists. [NO]');
  Writeln(' --desire  -d R Use R as desired MSE. [', FloatToStrF(FDesMSE, ffGeneral, 6, 4), ']');
  Writeln(' --report  -r I Use I as reporting epoch interval. [', FReportFreq, ']');
  Writeln(' --maximum -m I Use I as maximum number of epochs. [', FNoEpochs, ']');
  Writeln(' --innum   -I I Use I input values. [', FNoInputs, ']');
  Writeln(' --outnum  -O I Use I output values. [', FNoOutputs, ']');
  Writeln(' --one     -1 I Number of neurons on 1st hidden layer. [', FHiddenLayer1, ']');
  Writeln(' --two     -2 I Number of neurons on 2nd hidden layer. [', FHiddenLayer2, ']');
  Writeln(' --three   -3 I Number of neurons on 3rd hidden layer. [', FHiddenLayer3, ']');
  Writeln(' --four    -4 I Number of neurons on 4th hidden layer. [', FHiddenLayer4, ']');
  Writeln(' --five    -5 I Number of neurons on 5th hidden layer. [', FHiddenLayer5, ']');
  Writeln(' --train   -t S Name of the training algorithm to be used. [', FANN_TRAIN_NAMES[FTrainAlgo], ']');
  Writeln(' --hidden  -H S Name of the hidden activation function to be used. [', FANN_ACTIVATIONFUNC_NAMES[FActiHidden], ']');
  Writeln(' --activ   -a S Name of the output activation function to be used. [', FANN_ACTIVATIONFUNC_NAMES[FActiOut], ']');
  Writeln(' --widrow  -w   Do NOT init weights using Widrow & Nguyen. [NO]');
  Writeln;
end;


procedure TTrTenetApplication.SayError(const AError : String);
begin
  Writeln(#10#13, 'Error: ', AError);
  Writeln('Use tenet -h to get help.', #10#13);
  Terminate;
end;


end.
