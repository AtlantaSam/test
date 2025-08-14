/*---------------------------------------------------------
  The options statement below should be placed
  before the data step when submitting this code.
---------------------------------------------------------*/
options VALIDMEMNAME=EXTEND VALIDVARNAME=ANY;


/*---------------------------------------------------------
  Before this code can run you need to fill in all the
  macro variables below.
---------------------------------------------------------*/
/*---------------------------------------------------------
  Start Macro Variables
---------------------------------------------------------*/
%let SOURCE_HOST=<Hostname>; /* The host name of the CAS server */
%let SOURCE_PORT=<Port>; /* The port of the CAS server */
%let SOURCE_LIB=<Library>; /* The CAS library where the source data resides */
%let SOURCE_DATA=<Tablename>; /* The CAS table name of the source data */
%let DEST_LIB=<Library>; /* The CAS library where the destination data should go */
%let DEST_DATA=<Tablename>; /* The CAS table name where the destination data should go */

/* Open a CAS session and make the CAS libraries available */
options cashost="&SOURCE_HOST" casport=&SOURCE_PORT;
cas mysess;
caslib _all_ assign;

/* Load ASTOREs into CAS memory */
proc casutil;
  Load casdata="Gradient_boosting___targetMB0_1.sashdat" incaslib="Models" casout="Gradient_boosting___targetMB0_1" outcaslib="casuser" replace;
Quit;

/* Apply the model */
proc cas;
  fcmpact.runProgram /
  inputData={caslib="&SOURCE_LIB" name="&SOURCE_DATA"}
  outputData={caslib="&DEST_LIB" name="&DEST_DATA" replace=1}
  routineCode = "

   /*------------------------------------------
   Generated SAS Scoring Code
     Date             : 02Jul2021:19:21:55
     Locale           : en_US
     Model Type       : Gradient Boosting
     Interval variable: tdp_blade_angle_1_set_Mean
     Interval variable: tdp_blade_angle_1_set_Max
     Interval variable: tdp_blade_angle_2_set_Max
     Interval variable: tdp_blade_angle_3_set_Max
     Interval variable: tdp_gen_speed_Mean
     Interval variable: tdp_temp_gen_air_cooler_Mean
     Interval variable: tdp_temp_gen_bearing_nde_Max
     Interval variable: tdp_temp_main_bearing_Mean
     Interval variable: tdp_tower_acceleration_Mean
     Interval variable: tdp_tower_acceleration_StdDev
     Interval variable: tdp_tower_acceleration_Max
     Interval variable: tdp_wind_speed_StdDev
     Interval variable: tdp_wind_speed_Max
     Interval variable: tdp_yaw_nacelle_position_Mean
     Interval variable: pMB1
     Interval variable: pMB2
     Class variable   : targetMB0
     Response variable: targetMB0
     ------------------------------------------*/
declare object Gradient_boosting___targetMB0_1(astore);
call Gradient_boosting___targetMB0_1.score('CASUSER','Gradient_boosting___targetMB0_1');
   /*------------------------------------------*/
   /*_VA_DROP*/ drop 'I_targetMB0'n 'P_targetMB00'n 'P_targetMB01'n;
length 'I_targetMB0_3341'n $32;
      'I_targetMB0_3341'n='I_targetMB0'n;
'P_targetMB00_3341'n='P_targetMB00'n;
'P_targetMB01_3341'n='P_targetMB01'n;
   /*------------------------------------------*/
";

run;
Quit;

/* Persist the output table */
proc casutil;
  Save casdata="&DEST_DATA" incaslib="&DEST_LIB" casout="&DEST_DATA%str(.)sashdat" outcaslib="&DEST_LIB" replace;
Quit;
