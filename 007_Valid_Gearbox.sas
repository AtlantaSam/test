proc format;
   value failfmt
   0 = 'No'
   1 = 'Yes';
run;

/* Two (2) Week Model */
%let dsin=casuser.tmpScoreData_GBX2_BG2;
%let dsin=casuser.tmpScoreData_GBx2_LM;



proc freq data=&dsin.; table targetGB2; title 'Target Gearbox'; run;

proc means data=&dsin; var em_EventProbability; title 'Prob of Failure'; run;

data temp;
   set &dsin.;
   if em_EventProbability ge 0.5 then class=1; else class=0;
   if em_EventProbability ge 0.2 then class2=1; else class2=0;
run;
proc sort; by tdp_asset_name; run;

proc freq; table class*targetGB2; title 'Standard 50/50 Cutoff'; run;
proc freq; table class2*targetGB2; title 'Optimal Cutoff'; run;

proc print noobs label;
   where class2=1;
   var tdp_asset_name targetGB2 em_eventProbability;
   label targetGB2='Failed?'
         em_eventProbability='P(fail)';
   format targetGB2 failfmt.;
   title 'Assets that might need attention';
run;

/* One (1) Week Model */
%let dsin=casuser.tmpScoreData_GBX1_BG2;

proc freq data=&dsin.; table targetGB1; title 'Target Gearbox'; run;

proc means data=&dsin; var em_EventProbability; title 'Prob of Failure'; run;

data temp;
   set &dsin.;
   if em_EventProbability ge 0.5 then class=1; else class=0;
   if em_EventProbability ge 0.2 then class2=1; else class2=0;
run;
proc sort; by tdp_asset_name; run;

proc freq; table class*targetGB1; title 'Standard 50/50 Cutoff'; run;
proc freq; table class2*targetGB1; title 'Optimal Cutoff'; run;

proc print noobs label;
   where class2=1;
   var tdp_asset_name targetGB1 em_eventProbability;
   label targetGB1='Failed?'
         em_eventProbability='P(fail)';
   format targetGB1 failfmt.;
   title 'Assets that might need attention';
run;

/* (during) Week Model */
%let dsin=casuser.tmpScoreData_GBX0_BG2;

proc freq data=&dsin.; table targetGB0; run;

proc means data=&dsin; var em_EventProbability; run;

data temp;
   set &dsin.;
   if em_EventProbability ge 0.5 then class=1; else class=0;
   if em_EventProbability ge 0.1 then class2=1; else class2=0;
run;
proc sort; by tdp_asset_name; run;

proc freq; table class*targetGB0; run;
proc freq; table class2*targetGB0; run;

proc print noobs label;
   where class2=1;
   var tdp_asset_name targetGB0 em_eventProbability;
   label targetGB0='Failed?'
         em_eventProbability='P(fail)';
   format targetGB0 failfmt.;
   title 'Assets that might need attention';
run;
   
   