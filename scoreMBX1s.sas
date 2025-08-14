*****************************************;
** SAS Scoring Code for PROC Logistic;
*****************************************;

length I_targetMB1 $ 12;
label I_targetMB1 = 'Into: targetMB1' ;
label U_targetMB1 = 'Unnormalized Into: targetMB1' ;

label P_targetMB11 = 'Predicted: targetMB1=1' ;
label P_targetMB10 = 'Predicted: targetMB1=0' ;

drop _LMR_BAD;
_LMR_BAD=0;

*** Check interval variables for missing values;
if nmiss(tdp_air_temp_StdDev,tdp_temp_gen_bearing_de_Mean,
        tdp_temp_main_bearing_Mean,tdp_yaw_nacelle_positio_StdDev) then do;
   _LMR_BAD=1;
   goto _SKIP_000;
end;

*** Compute Linear Predictors;
drop _LP0;
_LP0 = 0;

*** Effect: tdp_air_temp_StdDev;
_LP0 = _LP0 + (0.5958794381404) * tdp_air_temp_StdDev;
*** Effect: tdp_temp_gen_bearing;
_LP0 = _LP0 + (-0.40582949820035) * tdp_temp_gen_bearing_de_Mean;
*** Effect: tdp_temp_main_bearin;
_LP0 = _LP0 + (0.59115524090874) * tdp_temp_main_bearing_Mean;
*** Effect: tdp_yaw_nacelle_posi;
_LP0 = _LP0 + (-0.04262051913043) * tdp_yaw_nacelle_positio_StdDev;

*** Predicted values;
drop _MAXP _IY _P0 _P1;
_TEMP = -6.21786480159857  + _LP0;
if (_TEMP < 0) then do;
   _TEMP = exp(_TEMP);
   _P0 = _TEMP / (1 + _TEMP);
end;
else _P0 = 1 / (1 + exp(-_TEMP));
_P1 = 1.0 - _P0;
P_targetMB11 = _P0;
_MAXP = _P0;
_IY = 1;
P_targetMB10 = _P1;
if (_P1 >  _MAXP + 1E-8) then do;
   _MAXP = _P1;
   _IY = 2;
end;
select( _IY );
   when (1) do;
      I_targetMB1 = '1' ;
      U_targetMB1 = 1;
   end;
   when (2) do;
      I_targetMB1 = '0' ;
      U_targetMB1 = 0;
   end;
   otherwise do;
      I_targetMB1 = '';
      U_targetMB1 = .;
   end;
end;
_SKIP_000:
if _LMR_BAD = 1 then do;
I_targetMB1 = '';
U_targetMB1 = .;
P_targetMB11 = .;
P_targetMB10 = .;
end;
drop _TEMP;
