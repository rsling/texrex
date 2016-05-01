{
  FANN - Bindings to the FANN library for FreePascal.
  Maintained by Roland Schäfer.
  http://texrex.sourceforge.net/

  Converted from earlier Delphi bindings.
  Author of Delphi unit: Mauricio Pereira Maia <mauriciocpa@gmail.com>

  See the file COPYING.LGPL, included in this distribution, for
  details about the copyright.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

}

unit FANN;

interface

{$MODE FPC}
{$CALLING CDECL}
{$PACKRECORDS C}
{$H+}

{$IFDEF DARWIN}
  {$LINKLIB fann}
{$ENDIF}


//{$DEFINE FIXEDFANN} //Uncomment for fixed fann
//{$DEFINE DOUBLEFANN} //Uncomment for double fann


{$IFDEF WINDOWS}
  {$IF Defined(FIXEDFANN)}
  const LIBNAME = 'fannfixed.dll';
  {$ELSEIF Defined(DOUBLEFANN)}
  const LIBNAME = 'fanndouble.dll';
  {$ELSE}
  const LIBNAME = 'fannfloat.dll';
  {$IFEND}
{$ENDIF}

{$IFDEF UNIX}
  {$IF Defined(FIXEDFANN)}
  const LIBNAME = 'libfixedfann.so';
  {$ELSEIF Defined(DOUBLEFANN)}
  const LIBNAME = 'libdoublefann.so';
  {$ELSE}
  const LIBNAME = 'libfloatfann.so';
  {$IFEND}
{$ENDIF}


type
  {$IF Defined(FIXEDFANN)}
  fann_type = integer;
  {$ELSEIF Defined(DOUBLEFANN)}
  fann_type = double;
  {$ELSE}
  fann_type = single;
  {$IFEND}

  PFann_Type = ^fann_type;
  PPFann_Type = ^pfann_type;
  Fann_Type_Array = array [0..65535] of fann_type;
  PFann_Type_Array = ^Fann_type_array;
  PPFann_Type_Array = array [0..65535] of ^Fann_Type_Array;

  (* MICROSOFT VC++ STDIO'S FILE DEFINITION*)
  _iobuf = packed record
    _ptr: Pchar;
    _cnt: integer;
    _base: Pchar;
    _flag: integer;
    _file: integer;
    _charbuf: integer;
    _bufsiz: integer;
    _tmpfname: Pchar;
  end;
  PFile = ^TFile;
  TFile = _iobuf;

  PPFann_Neuron = ^PFann_Neuron;
  PFann_Neuron = ^TFann_Neuron;
  TFann_Neuron = packed record
    first_con: Cardinal;
    last_con: Cardinal;
    sum: fann_type;
    value: fann_type;
    activation_steepness: fann_type;
    activation_function: Cardinal; //enum
  end;

  PFann_Layer = ^TFann_Layer;
  TFann_Layer = packed record
          first_neuron: PFann_Neuron;
          last_neuron: PFann_Neuron;
  end;

  PFann = ^TFann;
  TFann = packed record
    errno_f: cardinal;
    error_log: PFile;
    errstr: Pchar;
    learning_rate: single;
    learning_momentum: single;
    connection_rate: single;
    network_type: Cardinal; //ENUM
    first_layer: PFann_Layer;
    last_layer: PFann_Layer;
    total_neurons: cardinal;
    num_input: cardinal;
    num_output: cardinal;
    weights: Pfann_type;
    connections: PPFann_Neuron;
    train_errors: Pfann_type;
    training_algorithm: cardinal; //ENUM
    {$IFDEF FIXEDFANN}
     decimal_point: cardinal;
     multiplier: cardinal;
     sigmoid_results: array [0..5] of fann_type;
     sigmoid_values: array [0..5] of fann_type;
     symmetric_results: array [0..5] of fann_type;
     symmetric_values: array [0..5] of fann_type;
    {$ENDIF}
    total_connections: cardinal;
    output: pfann_type;
    num_MSE: cardinal;
    MSE_value: single;
    num_bit_fail: cardinal;
    bit_fail_limit: fann_type;
    train_error_function: cardinal;//enum
    train_stop_function: cardinal; //enum
    callback: Pointer; //TFANN_CALLBACK
    user_data: Pointer;
    cascade_output_change_fraction: single;
    cascade_output_stagnation_epochs: Cardinal;
    cascade_candidate_change_fraction: single;
    cascade_candidate_stagnation_epochs: Cardinal;
    cascade_best_candidate: Cardinal;
    cascade_candidate_limit: fann_type;
    cascade_weight_multiplier: fann_type;
    cascade_max_out_epochs: Cardinal;
    cascade_max_cand_epochs: Cardinal;
    cascade_activation_functions: PCardinal;
    cascade_activation_functions_count: Cardinal;
    cascade_activation_steepnesses: PFann_Type;
    cascade_activation_steepnesses_count: Cardinal;
    cascade_num_candidate_groups: Cardinal;
    cascade_candidate_scores: PFann_Type;
    total_neurons_allocated: Cardinal;
    total_connections_allocated: Cardinal;
    quickprop_decay: single;
    quickprop_mu: single;
    rprop_increase_factor: single;
    rprop_decrease_factor: single;
    rprop_delta_min: single;
    rprop_delta_max: single;
    rprop_delta_zero: single;
    train_slopes: pfann_type;
    prev_steps: pfann_type;
    prev_train_slopes: pfann_type;
    prev_weights_deltas: pfann_type;
    {$IFNDEF FIXEDFANN}
    scale_mean_in: psingle;
    scale_deviation_in: psingle;
    scale_new_min_in: psingle;
    scale_factor_in: psingle;
    scale_mean_out: psingle;
    scale_deviation_out: psingle;
    scale_new_min_out: psingle;
    scale_factor_out: psingle;
    {$ENDIF}
  end;

  PFann_Train_Data = ^TFann_Train_Data;
  TFann_Train_Data = packed record
    errno_f: cardinal;
    erro_log: PFile;
    errstr: Pchar;
    num_data: cardinal;
    num_input: cardinal;
    num_output: cardinal;
    input: PPFann_Type_Array;
    output: PPFann_Type_Array;
  end;

  PFann_Connection = ^TFann_Connection;
  TFann_Connection = packed record
          from_neuron: Cardinal;
          to_neuron: Cardinal;
          weight: fann_type;
  end;

  PFann_Error = ^TFann_Error;
  TFann_Error = packed record
          errno_f: Cardinal; //Enum
          error_log: PFile;
          errstr: PChar;
  end;



//_Fann_Train =
const
  FANN_TRAIN_INCREMENTAL = 0;
  FANN_TRAIN_BATCH = 1;
  FANN_TRAIN_RPROP = 2;
  FANN_TRAIN_QUICKPROP = 3;

//_Fann_Error_Func =
  FANN_ERRORFUNC_LINEAR = 0;
  FANN_ERRORFUNC_TANH = 1;

//_Fann_Activation_Func =
  FANN_LINEAR = 0;
  FANN_THRESHOLD = 1;
  FANN_THRESHOLD_SYMMETRIC = 2;
  FANN_SIGMOID = 3;
  FANN_SIGMOID_STEPWISE = 4;
  FANN_SIGMOID_SYMMETRIC = 5;
  FANN_SIGMOID_SYMMETRIC_STEPWISE = 6;
  FANN_GAUSSIAN = 7;
  FANN_GAUSSIAN_SYMMETRIC = 8;
  FANN_GAUSSIAN_STEPWISE = 9;
  FANN_ELLIOT = 10;
  FANN_ELLIOT_SYMMETRIC = 11;
  FANN_LINEAR_PIECE = 12;
  FANN_LINEAR_PIECE_SYMMETRIC = 13;
  FANN_SIN_SYMMETRIC = 14;
  FANN_COS_SYMMETRIC = 15;
  FANN_SIN = 16;
  FANN_COS = 17;

//_Fann_ErroNo =
  FANN_E_NO_ERROR = 0;
  FANN_E_CANT_OPEN_CONFIG_R = 1;
  FANN_E_CANT_OPEN_CONFIG_W = 2;
  FANN_E_WRONG_CONFIG_VERSION = 3;
  FANN_E_CANT_READ_CONFIG = 4;
  FANN_E_CANT_READ_NEURON = 5;
  FANN_E_CANT_READ_CONNECTIONS = 6;
  FANN_E_WRONG_NUM_CONNECTIONS = 7;
  FANN_E_CANT_OPEN_TD_W = 8;
  FANN_E_CANT_OPEN_TD_R = 9;
  FANN_E_CANT_READ_TD = 10;
  FANN_E_CANT_ALLOCATE_MEM = 11;
  FANN_E_CANT_TRAIN_ACTIVATION = 12;
  FANN_E_CANT_USE_ACTIVATION = 13;
  FANN_E_TRAIN_DATA_MISMATCH = 14;
  FANN_E_CANT_USE_TRAIN_ALG = 15;
  FANN_E_TRAIN_DATA_SUBSET = 16;
  FANN_E_INDEX_OUT_OF_BOUND = 17;
  FANN_E_SCALE_NOT_PRESENT = 18;

//_Fann_Stop_Func =
  FANN_STOPFUNC_MSE = 0;
  FANN_STOPFUNC_BIT = 1;

//_Fann_Net_Type =
  FANN_NETTYPE_LAYER = 0;
  FANN_NETTYPE_SHORTCUT = 1;


type
  TFann_CallBack = function(Ann: PFann;
                            train: PFann_Train_Data;
                            max_epochs: Cardinal;
                            epochs_between_reports: cardinal;
                            desired_error: single;
                            epochs: cardinal): integer;

  TUser_Function = procedure(num: Cardinal;
                            num_input: Cardinal;
                            num_output: cardinal;
                            input: PFann_Type;
                            output: PFann_Type);

var
  FANN_ERRORFUNC_NAMES: array [0..1] of string = (
    'FANN_ERRORFUNC_LINEAR',
    'FANN_ERRORFUNC_TANH'
  );
  FANN_TRAIN_NAMES: array [0..3] of string =
  (
    'FANN_TRAIN_INCREMENTAL',
    'FANN_TRAIN_BATCH',
    'FANN_TRAIN_RPROP',
    'FANN_TRAIN_QUICKPROP'
  );
  FANN_ACTIVATIONFUNC_NAMES: array [0..17] of string =
  (
      'FANN_LINEAR',
      'FANN_THRESHOLD',
      'FANN_THRESHOLD_SYMMETRIC',
      'FANN_SIGMOID',
      'FANN_SIGMOID_STEPWISE',
      'FANN_SIGMOID_SYMMETRIC',
      'FANN_SIGMOID_SYMMETRIC_STEPWISE',
      'FANN_GAUSSIAN',
      'FANN_GAUSSIAN_SYMMETRIC',
      'FANN_GAUSSIAN_STEPWISE',
      'FANN_ELLIOT',
      'FANN_ELLIOT_SYMMETRIC',
      'FANN_LINEAR_PIECE',
      'FANN_LINEAR_PIECE_SYMMETRIC',
      'FANN_SIN_SYMMETRIC',
      'FANN_COS_SYMMETRIC',
      'FANN_SIN',
      'FANN_COS'
  );
  FANN_STOPFUNC_NAMES: array [0..1] of string =
  (
      'FANN_STOPFUNC_MSE',
      'FANN_STOPFUNC_BIT'
  );
  FANN_NETTYPE_NAMES: array [0..1] of string =
  (
      'FANN_NETTYPE_LAYER',
      'FANN_NETTYPE_SHORTCUT'
  );


function fann_errorfunc_index(AString : String) : Integer;
function fann_train_index(AString : String) : Integer;
function fann_activationfunc_index(AString : String) : Integer;
function fann_stopfunc_index(AString : String) : Integer;
function fann_nettypes_index(AString : String) : Integer;


//DECLARATIONS FROM FANN.H

function fann_create_standard(num_layers: Cardinal): PFann; external LIBNAME; varargs;
function fann_create_sparse(connection_rate: single; num_layers: Cardinal): PFann; external LIBNAME; varargs;
function fann_create_shortcut(connection_rate: single): PFann; external LIBNAME; varargs;
function fann_create_standard_array(num_layers: Cardinal; const layers: PCardinal): PFann; external LIBNAME;
function fann_create_sparse_array(connection_rate: single; num_layers: Cardinal; const layers: PCardinal): PFann; external LIBNAME;
function fann_create_shortcut_array(num_layers: cardinal;const layers: Pcardinal): PFann; external LIBNAME;
procedure fann_destroy(Ann: PFann); external LIBNAME;
function fann_run(ann: PFann; input: PFann_Type): Pfann_type_array; external LIBNAME;
procedure fann_randomize_weights(Ann: PFann; Min_weight: fann_type; Max_weight: fann_type); external LIBNAME;
procedure fann_init_weights(Ann: PFann; train_data: PFann_Train_Data); external LIBNAME;
procedure fann_print_connections(ann: PFann); external LIBNAME;
procedure fann_print_parameters(ann: PFann); external LIBNAME;
function fann_get_num_input(Ann: PFann): cardinal; external LIBNAME;
function fann_get_num_output(Ann: PFann): cardinal; external LIBNAME;
function fann_get_total_neurons(Ann: PFann): cardinal; external LIBNAME;
function fann_get_total_connections(Ann: PFann): cardinal; external LIBNAME;
function fann_get_network_type(Ann: PFann): cardinal; external LIBNAME;
function fann_get_connection_rate(Ann: PFann): single; external LIBNAME;
function fann_get_num_layers(Ann: PFann): cardinal; external LIBNAME;
procedure fann_get_layer_array(Ann: PFann; layers: PCardinal); external LIBNAME;
procedure fann_get_bias_array(Ann: PFann; bias: PCardinal); external LIBNAME;
procedure fann_get_connection_array(Ann: PFann; connections: PFann_Connection); external LIBNAME;
procedure fann_set_weight_array(Ann: PFann; connections: PFann_Connection; num_connection: Cardinal); external LIBNAME;
procedure fann_set_weight(Ann: PFann; from_neuron: Cardinal; to_neuron: Cardinal; weight: fann_type); external LIBNAME;
procedure fann_set_user_data(Ann: PFann; user_data: Pointer); external LIBNAME;
function fann_get_user_data(Ann: PFann): Pointer; external LIBNAME;


{$IFDEF FIXEDFANN}
  function fann_get_decimal_point(Ann: Pfann): cardinal; external LIBNAME;
  function fann_get_multiplier(Ann: PFann): cardinal; external LIBNAME;
{$ENDIF}

//END OF DECLARATIONS FROM FANN.H


//DECLARATIONS FROM FANN_IO.H

function fann_create_from_file(const configuration_file: PChar): PFann; external LIBNAME;
procedure fann_save(Ann: PFann; Const Configuration_File: PChar); external LIBNAME;
function fann_save_to_fixed(Ann: PFann; Const Configuration_File: PChar): integer; external LIBNAME;

//END OF DECLARATIONS FROM FANN_IO.H


//DECLARATIONS FROM FANN_TRAIN.H

{$IFNDEF FIXEDFANN}
  procedure fann_train(Ann: PFann; Input: PFann_Type; Desired_Output: PFann_Type); external LIBNAME;
{$ENDIF}

function fann_test(Ann: PFann; Input: PFann_Type;  Desired_Output: Pfann_Type): Pfann_type_array; external LIBNAME;
function fann_get_MSE(Ann: PFann): single; external LIBNAME;
function fann_get_bit_fail(Ann: PFann): Cardinal; external LIBNAME;
procedure fann_reset_MSE(Ann: Pfann); external LIBNAME;

{$IFNDEF FIXEDFANN}
  procedure fann_train_on_data(Ann: PFann; Data: PFann_Train_Data;max_epochs: cardinal;epochs_between_reports: cardinal; desired_error: single); external LIBNAME;
  procedure fann_train_on_file(Ann: PFann; Filename: Pchar;max_epochs: cardinal;epochs_between_reports: cardinal; desired_error: single); external LIBNAME;
  function fann_train_epoch(Ann: PFann; data: PFann_Train_Data): single; external LIBNAME;
  function fann_test_data(Ann: PFann; data: PFann_Train_Data): single; external LIBNAME;
{$ENDIF}

function fann_read_train_from_file(const filename: PChar): PFann_Train_Data; external LIBNAME;
function fann_create_train_from_callback(num_data: Cardinal; num_input: Cardinal; num_output: Cardinal; user_function: TUser_Function): PFann_Train_Data; external LIBNAME;
procedure fann_destroy_train(train_data: PFann_Train_Data); external LIBNAME;
procedure fann_shuffle_train_data(Train_Data: PFann_Train_Data); external LIBNAME;
procedure fann_scale_train(Ann: PFann; data: PFann_Train_Data); external LIBNAME;
procedure fann_descale_train(Ann: PFann; data: PFann_Train_Data); external LIBNAME;
function fann_set_input_scaling_params(Ann: PFann; const data: PFann_Train_Data; new_input_min: single; new_input_max: single): integer; external LIBNAME;
function fann_set_output_scaling_params(Ann: PFann; const data: PFann_Train_Data; new_output_min: single; new_output_max: single): integer; external LIBNAME;
function fann_set_scaling_params(Ann: PFann; const data: PFann_Train_Data; new_input_min: single; new_input_max: single; new_output_min: single; new_output_max: single): integer; external LIBNAME;
function fann_clear_scaling_params(Ann: PFann): integer; external LIBNAME;
procedure fann_scale_input(Ann: PFann; input_vector: PFann_type); external LIBNAME;
procedure fann_scale_output(Ann: PFann; output_vector: PFann_type); external LIBNAME;
procedure fann_descale_input(Ann: PFann; input_vector: PFann_type); external LIBNAME;
procedure fann_descale_output(Ann: PFann; output_vector: PFann_type); external LIBNAME;
procedure fann_scale_input_train_data(Train_Data: PFann_Train_Data; new_min: fann_type; new_max: fann_type); external LIBNAME;
procedure fann_scale_output_train_data(Train_Data: PFann_Train_Data; new_min: fann_type; new_max: fann_type); external LIBNAME;
procedure fann_scale_train_data(Train_Data: PFann_Train_Data; new_min: fann_type; new_max: fann_type); external LIBNAME;
function fann_merge_train_data(Data1: PFann_Train_Data; Data2: PFann_Train_Data): PFann_Train_Data; external LIBNAME;
function fann_duplicate_train_data(Data: PFann_Train_Data): PFann_Train_Data; external LIBNAME;
function fann_subset_train_data(data: PFann_Train_Data; pos: Cardinal; length: Cardinal): PFann_Train_Data; external LIBNAME;
function fann_length_train_data(data: PFann_Train_Data): Cardinal; external LIBNAME;
function fann_num_input_train_data(data: PFann_Train_Data): Cardinal; external LIBNAME;
function fann_num_output_train_data(data: PFann_Train_Data): Cardinal; external LIBNAME;
function fann_save_train(Data: PFann_train_Data; const Filename: PChar): integer; external LIBNAME;
function fann_save_train_to_fixed(Data: PFann_train_Data; const FileName: Pchar; decimal_point: cardinal): integer; external LIBNAME;
function fann_get_training_algorithm(Ann: Pfann): cardinal; external LIBNAME;
procedure fann_set_training_algorithm(Ann: PFann; Training_Algorithm: cardinal); external LIBNAME;
function fann_get_learning_rate(Ann: PFann): single; external LIBNAME;
procedure fann_set_learning_rate(Ann: PFann; Learning_Rate: Single); external LIBNAME;
function fann_get_learning_momentum(Ann: PFann): single; external LIBNAME;
procedure fann_set_learning_momentum(Ann: PFann; learning_momentum: Single); external LIBNAME;
function fann_get_activation_function(Ann: PFann; layer: integer; neuron: integer): Cardinal; external LIBNAME; //ENUM
procedure fann_set_activation_function(Ann: PFann; activation_function: Cardinal; layer: integer; neuron: integer); external LIBNAME; //ENUM
procedure fann_set_activation_function_layer(Ann: PFann; activation_function: Cardinal; layer: integer); external LIBNAME; //ENUM
procedure fann_set_activation_function_hidden(Ann: Pfann; Activation_function: cardinal); external LIBNAME;
procedure fann_set_activation_function_output(Ann: Pfann; Activation_Function: cardinal); external LIBNAME;
function fann_get_activation_steepness(Ann: PFann; layer: integer; neuron: integer): fann_type; external LIBNAME;
procedure fann_set_activation_steepness(Ann: PFann; steepness: fann_type; layer: integer; neuron: integer); external LIBNAME;
procedure fann_set_activation_steepness_layer(Ann: PFann; steepness: fann_type; layer: integer); external LIBNAME;
procedure fann_set_activation_steepness_hidden(Ann: PFann; steepness: Fann_Type); external LIBNAME;
procedure fann_set_activation_steepness_output(Ann: PFann; steepness: Fann_Type); external LIBNAME;
function fann_get_train_error_function(Ann: PFann): cardinal; external LIBNAME;
procedure fann_set_train_error_function(Ann: PFann; Train_Error_Function: cardinal); external LIBNAME;
function fann_get_train_stop_function(Ann: PFann): Cardinal; external LIBNAME;
procedure fann_set_train_stop_function(Ann: PFann; train_stop_function: cardinal); external LIBNAME;
function fann_get_bit_fail_limit(Ann: PFann): fann_type; external LIBNAME;
procedure fann_set_bit_fail_limit(Ann: PFann; bit_fail_limit: fann_type); external LIBNAME;
procedure fann_set_callback(Ann: PFann; callback: TFann_Callback); external LIBNAME;
function fann_get_quickprop_decay(Ann: PFann): single; external LIBNAME;
procedure fann_set_quickprop_decay(Ann: Pfann; quickprop_decay: Single); external LIBNAME;
function fann_get_quickprop_mu(Ann: PFann): single; external LIBNAME;
procedure fann_set_quickprop_mu(Ann: PFann; Mu: Single); external LIBNAME;
function fann_get_rprop_increase_factor(Ann: PFann): single; external LIBNAME;
procedure fann_set_rprop_increase_factor(Ann: PFann;rprop_increase_factor: single); external LIBNAME;
function fann_get_rprop_decrease_factor(Ann: PFann): single; external LIBNAME;
procedure fann_set_rprop_decrease_factor(Ann: PFann;rprop_decrease_factor: single); external LIBNAME;
function fann_get_rprop_delta_min(Ann: PFann): single; external LIBNAME;
procedure fann_set_rprop_delta_min(Ann: PFann; rprop_delta_min: Single); external LIBNAME;
function fann_get_rprop_delta_max(Ann: PFann): single; external LIBNAME;
procedure fann_set_rprop_delta_max(Ann: PFann; rprop_delta_max: Single); external LIBNAME;
function fann_get_rprop_delta_zero(Ann: PFann): single; external LIBNAME;
procedure fann_set_rprop_delta_zero(Ann: PFann; rprop_delta_zero: Single); external LIBNAME;

//END OF DECLARATIONS OF FANN_TRAIN.H


//DECLARATIONS OF FANN_ERROR.H

procedure fann_set_error_log(errdat: PFann_Error; Log_File: PFile); external LIBNAME;
function fann_get_errno(errdat: PFann_Error): cardinal; external LIBNAME;
procedure fann_reset_errno(errdat: PFann_Error); external LIBNAME;
procedure fann_reset_errstr(errdat: PFann_Error); external LIBNAME;
function fann_get_errstr(errdat: PFann_Error): PChar; external LIBNAME;
procedure fann_print_error(Errdat: PFann_Error); external LIBNAME;

//END OF DECLARATIONS OF FANN_ERROR


//DECLARATIONS OF FANN_CASCADE.H

procedure fann_cascadetrain_on_data(Ann: PFann; data: PFann_Train_Data; max_neurons: Cardinal; neurons_between_reports: Cardinal; desired_error: single); external LIBNAME;
procedure fann_cascadetrain_on_file(Ann: PFann; const filename: PChar; max_neurons: Cardinal; neurons_between_reports: Cardinal; desired_error: single); external LIBNAME;
function fann_get_cascade_output_change_fraction(Ann: PFann): single; external LIBNAME;
procedure fann_set_cascade_output_change_fraction(Ann: PFann; cascade_output_change_fraction: single); external LIBNAME;
function fann_get_cascade_output_stagnation_epochs(Ann: PFann): cardinal; external LIBNAME;
procedure fann_set_cascade_output_stagnation_epochs(Ann: PFann; cascade_output_stagnation_epochs: cardinal); external LIBNAME;
function fann_get_cascade_candidate_change_fraction(Ann: PFann): single; external LIBNAME;
procedure fann_set_cascade_candidate_change_fraction(Ann: PFann; cascade_candidate_change_fraction: single); external LIBNAME;
function fann_get_cascade_candidate_stagnation_epochs(Ann: PFann): cardinal; external LIBNAME;
procedure fann_set_cascade_candidate_stagnation_epochs(Ann: PFann; cascade_candidate_stagnation_epochs: cardinal); external LIBNAME;
function fann_get_cascade_weight_multiplier(Ann: PFann): fann_type; external LIBNAME;
procedure fann_set_cascade_weight_multiplier(Ann: PFann; cascade_weight_multiplier: fann_type); external LIBNAME;
function fann_get_cascade_candidate_limit(Ann: PFann): fann_type; external LIBNAME;
procedure fann_set_cascade_candidate_limit(Ann: PFann; cascade_candidate_limit: fann_type); external LIBNAME;
function fann_get_cascade_max_out_epochs(Ann: PFann): cardinal; external LIBNAME;
procedure fann_set_cascade_max_out_epochs(Ann: PFann; cascade_max_out_epochs: cardinal); external LIBNAME;
function fann_get_cascade_max_cand_epochs(Ann: PFann): cardinal; external LIBNAME;
procedure fann_set_cascade_max_cand_epochs(Ann: PFann; cascade_max_cand_epochs: cardinal); external LIBNAME;
function fann_get_cascade_num_candidates(Ann: PFann): cardinal; external LIBNAME;
function fann_get_cascade_activation_functions_count(Ann: PFann): cardinal; external LIBNAME;
function fann_get_cascade_activation_functions(Ann: PFann): PCardinal; external LIBNAME;
procedure fann_set_cascade_activation_functions(Ann: PFann; cascade_activation_functions: PCardinal; cascade_activation_functions_count: Cardinal); external LIBNAME;
function fann_get_cascade_activation_steepnesses_count(Ann: PFann): cardinal; external LIBNAME;
function fann_get_cascade_activation_steepnesses(Ann: PFann): pfann_type; external LIBNAME;
procedure fann_set_cascade_activation_steepnesses(Ann: PFann; cascade_activation_steepnesses: PFann_Type; cascade_activation_steepnesses_count: Cardinal); external LIBNAME;
function fann_get_cascade_num_candidate_groups(Ann: PFann): cardinal; external LIBNAME;
procedure fann_set_cascade_num_candidate_groups(Ann: PFann; cascade_num_candidate_groups: cardinal); external LIBNAME;

//END OF DECLARATIONS OF FANN_CASCADE.H



implementation

function fann_train_index(AString : String) : Integer;
begin
  if AString = 'FANN_TRAIN_INCREMENTAL'
  then fann_train_index := 0
  else if AString = 'FANN_TRAIN_BATCH'
  then fann_train_index := 1
  else if AString = 'FANN_TRAIN_RPROP'
  then fann_train_index := 2
  else if AString = 'FANN_TRAIN_QUICKPROP'
  then fann_train_index := 3
  else fann_train_index := (-1);
end;



function fann_errorfunc_index(AString : String) : Integer;
begin
  if AString = 'FANN_ERRORFUNC_LINEAR'
  then fann_errorfunc_index := 0
  else if AString = 'FANN_ERRORFUNC_TANH'
  then fann_errorfunc_index := 1
  else fann_errorfunc_index := (-1);
end;



function fann_activationfunc_index(AString : String) : Integer;
begin
  if AString = 'FANN_LINEAR'
  then fann_activationfunc_index :=0
  else if AString = 'FANN_THRESHOLD'
  then fann_activationfunc_index :=1
  else if AString = 'FANN_THRESHOLD_SYMMETRIC'
  then fann_activationfunc_index :=2
  else if AString = 'FANN_SIGMOID'
  then fann_activationfunc_index :=3
  else if AString = 'FANN_SIGMOID_STEPWISE'
  then fann_activationfunc_index :=4
  else if AString = 'FANN_SIGMOID_SYMMETRIC'
  then fann_activationfunc_index :=5
  else if AString = 'FANN_SIGMOID_SYMMETRIC_STEPWISE'
  then fann_activationfunc_index :=6
  else if AString = 'FANN_GAUSSIAN'
  then fann_activationfunc_index :=7
  else if AString = 'FANN_GAUSSIAN_SYMMETRIC'
  then fann_activationfunc_index :=8
  else if AString = 'FANN_GAUSSIAN_STEPWISE'
  then fann_activationfunc_index :=9
  else if AString = 'FANN_ELLIOT'
  then fann_activationfunc_index :=10
  else if AString = 'FANN_ELLIOT_SYMMETRIC'
  then fann_activationfunc_index :=11
  else if AString = 'FANN_LINEAR_PIECE'
  then fann_activationfunc_index :=12
  else if AString = 'FANN_LINEAR_PIECE_SYMMETRIC'
  then fann_activationfunc_index :=13
  else if AString = 'FANN_SIN_SYMMETRIC'
  then fann_activationfunc_index :=14
  else if AString = 'FANN_COS_SYMMETRIC'
  then fann_activationfunc_index :=15
  else if AString = 'FANN_SIN'
  then fann_activationfunc_index :=16
  else if AString = 'FANN_COS'
  then fann_activationfunc_index :=17
  else fann_activationfunc_index := (-1);
end;


function fann_stopfunc_index(AString : String) : Integer;
begin
  if AString = 'FANN_STOPFUNC_MSE'
  then fann_stopfunc_index := 0
  else if AString = 'FANN_STOPFUNC_BIT'
  then fann_stopfunc_index := 1
  else fann_stopfunc_index := (-1);
end;


function fann_nettypes_index(AString : String) : Integer;
begin
  if AString = 'FANN_NETTYPE_LAYER'
  then fann_nettypes_index := 0
  else if AString = 'FANN_NETTYPE_SHORTCUT'
  then fann_nettypes_index := 1
  else fann_nettypes_index := (-1);
end;


end.
