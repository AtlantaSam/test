 
%let din=LM_ads_gbx2;

proc casutil;
   load casdata="_BM9TKCYVCQ6D1I5LWC1NE15EI_ast.sashdat" incaslib="models"
   casout="_BM9TKCYVCQ6D1I5LWC1NE15EI_ast" outcaslib="models";
run;

proc astore;
   describe rstore=models._BM9TKCYVCQ6D1I5LWC1NE15EI_ast
   epcode="epcode.sas";
run;

proc astore;
   score data=casuser.&din.
   rstore=models._BM9TKCYVCQ6D1I5LWC1NE15EI_ast
   epcode="epcode.sas"
   out=casuser.Score_GBX2_out;
quit;

proc print noobs label;
   where p_targetGB21 ge 0.2;
   var tdp_asset_name p_targetGB21;
   label p_targetGB21='P(fail)';
   title 'Assets that might need attention';
run;

