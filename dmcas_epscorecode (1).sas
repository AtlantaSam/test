/*
 * This score code file references one or more analytic stores that are located in the caslib "Models".
 * This score code file references the following analytic-store tables:
 *   _39Q0E7Q5KVLRHFY24P2PWHQ9Z_ast
 *   _2AZVVQQSV74QKQLWPTEZWC27U_ast
 */
data sasep.out;
   dcl package score _2AZVVQQSV74QKQLWPTEZWC27U();
   dcl package score _39Q0E7Q5KVLRHFY24P2PWHQ9Z();
   dcl double "cpy_int_med_imp_pGB2" having label n'pGB2: Low missing rate - median imputation';
   dcl double "cpy_int_med_imp_var_1_" having label n'tdp_ResidPower_Max: Low missing rate - median imputation';
   dcl double "cpy_int_med_imp_var_2_" having label n'tdp_temp_gen_air_cooler_Mean: Low missing rate - median imputation';
   dcl double "cpy_int_med_imp_var_3_" having label n'tdp_temp_main_bearing_Mean: Low missing rate - median imputation';
   dcl double "nhoks_nloks_dtree_10_var_4_" having label n'tdp_temp_main_bearing_StdDev: Not high (outlier, kurtosis, skewness) - ten bin decision tree binning';
   dcl double "nhoks_nloks_dtree_5_var_4_" having label n'tdp_temp_main_bearing_StdDev: Not high (outlier, kurtosis, skewness) - five bin decision tree binning';
   dcl double "P_targetGB11" having label n'Predicted: targetGB1=1';
   dcl double "P_targetGB10" having label n'Predicted: targetGB1=0';
   dcl nchar(32) "I_targetGB1" having label n'Into: targetGB1';
   dcl nchar(4) "_WARN_" having label n'Warnings';
   dcl double EM_EVENTPROBABILITY;
   dcl nchar(8) EM_CLASSIFICATION;
   dcl double EM_PROBABILITY;
   varlist allvars [_all_];
 
    
   method init();
      _2AZVVQQSV74QKQLWPTEZWC27U.setvars(allvars);
      _2AZVVQQSV74QKQLWPTEZWC27U.setkey(n'09A70A887005E124A35DEB8C32F24716944C5341');
      _39Q0E7Q5KVLRHFY24P2PWHQ9Z.setvars(allvars);
      _39Q0E7Q5KVLRHFY24P2PWHQ9Z.setkey(n'F498FCA699408C83DADF3A1FCEBB827A03CC1714');
   end;
    
   method post_39Q0E7Q5KVLRHFY24P2PWHQ9Z();
      dcl double _P_;
       
      if "P_TARGETGB10" = . then "P_TARGETGB10" = 0.9281045752;
      if "P_TARGETGB11" = . then "P_TARGETGB11" = 0.0718954248;
      if MISSING("I_TARGETGB1") then do ;
      _P_ = 0.0;
      if "P_TARGETGB11" > _P_ then do ;
      _P_ = "P_TARGETGB11";
      "I_TARGETGB1" = '1';
      end;
      if "P_TARGETGB10" > _P_ then do ;
      _P_ = "P_TARGETGB10";
      "I_TARGETGB1" = '0';
      end;
      end;
      EM_EVENTPROBABILITY = "P_TARGETGB11";
      EM_CLASSIFICATION = "I_TARGETGB1";
      EM_PROBABILITY = MAX("P_TARGETGB11", "P_TARGETGB10");
    
   end;
    
 
   method run();
      set SASEP.IN;
      _2AZVVQQSV74QKQLWPTEZWC27U.scoreRecord();
      _39Q0E7Q5KVLRHFY24P2PWHQ9Z.scoreRecord();
      post_39Q0E7Q5KVLRHFY24P2PWHQ9Z();
   end;
 
   method term();
   end;
 
enddata;
