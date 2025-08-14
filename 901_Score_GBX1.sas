%let din=ads_gbx1;

proc casutil;
   load casdata="_39Q0E7Q5KVLRHFY24P2PWHQ9Z_ast.sashdat" incaslib="models"
   casout="_39Q0E7Q5KVLRHFY24P2PWHQ9Z_ast" outcaslib="models";

   load casdata="_2AZVVQQSV74QKQLWPTEZWC27U_ast.sashdat" incaslib="models"
   casout="_2AZVVQQSV74QKQLWPTEZWC27U_ast" outcaslib="models";
run;

filename epc2b filesrvc folderpath='/PMAC Project/Analytics/ScoreCode' filename="eptest2b.sas" debug=http;

proc astore;
   describe rstore=models._39Q0E7Q5KVLRHFY24P2PWHQ9Z_ast;
   describe rstore=models._2AZVVQQSV74QKQLWPTEZWC27U_ast
   epcode=epc2b;
run;

proc astore;
   score data=casuser.&din.
   rstore=models._39Q0E7Q5KVLRHFY24P2PWHQ9Z_ast
   rstore=models._2AZVVQQSV74QKQLWPTEZWC27U_ast
   epcode=epc2
   out=casuser.Score_GBX1_out;
quit;

proc print data=casuser.Score_GBx1_out noobs label;
   where cpy_int_med_imp_pGB2 ge 0.2;
   var tdp_asset_name cpy_int_med_imp_pGB2;
   label cpy_int_med_imp_pGB2='P(fail)';
   title 'Assets that might need attention';
run;

