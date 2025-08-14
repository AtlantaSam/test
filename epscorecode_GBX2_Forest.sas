/*
 * This score code file references one or more analytic stores that are located in the caslib "Models".
 * This score code file references the following analytic-store tables:
 *   _BM9TKCYVCQ6D1I5LWC1NE15EI_ast
 */
data sasep.out;
   dcl package score _BM9TKCYVCQ6D1I5LWC1NE15EI();
   dcl double "P_targetGB21" having label n'Predicted: targetGB2=1';
   dcl double "P_targetGB20" having label n'Predicted: targetGB2=0';
   dcl nchar(32) "I_targetGB2" having label n'Into: targetGB2';
   dcl nchar(4) "_WARN_" having label n'Warnings';
   dcl double EM_EVENTPROBABILITY;
   dcl nchar(8) EM_CLASSIFICATION;
   dcl double EM_PROBABILITY;
   varlist allvars [_all_];
 
    
   method init();
      _BM9TKCYVCQ6D1I5LWC1NE15EI.setvars(allvars);
      _BM9TKCYVCQ6D1I5LWC1NE15EI.setkey(n'F8A9A59998DE29A23D9CC882DE10A7644D8AFBE7');
   end;
    
   method post_BM9TKCYVCQ6D1I5LWC1NE15EI();
      dcl double _P_;
       
      if "P_TARGETGB20" = . then "P_TARGETGB20" = 0.9281045752;
      if "P_TARGETGB21" = . then "P_TARGETGB21" = 0.0718954248;
      if MISSING("I_TARGETGB2") then do ;
      _P_ = 0.0;
      if "P_TARGETGB21" > _P_ then do ;
      _P_ = "P_TARGETGB21";
      "I_TARGETGB2" = '1';
      end;
      if "P_TARGETGB20" > _P_ then do ;
      _P_ = "P_TARGETGB20";
      "I_TARGETGB2" = '0';
      end;
      end;
      EM_EVENTPROBABILITY = "P_TARGETGB21";
      EM_CLASSIFICATION = "I_TARGETGB2";
      EM_PROBABILITY = MAX("P_TARGETGB21", "P_TARGETGB20");
    
   end;
    
 
   method run();
      set SASEP.IN;
      _BM9TKCYVCQ6D1I5LWC1NE15EI.scoreRecord();
      post_BM9TKCYVCQ6D1I5LWC1NE15EI();
   end;
 
   method term();
   end;
 
enddata;
