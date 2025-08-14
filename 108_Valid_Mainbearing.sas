proc format;
   value failfmt
   0 = 'No'
   1 = 'Yes';
run;

%let din=tmpScoreData_MB1;

proc freq data=casuser.&din.; table targetMB1; title 'Target Mainbearing'; run;

proc means data=casuser.&din.; var em_EventProbability; title 'Prob of Failure'; run;

data temp;
   set casuser.&din.;
   if em_EventProbability ge 0.5 then class=1; else class=0;
   if em_EventProbability ge 0.05 then class2=1; else class2=0;
run;
proc sort; by tdp_asset_name; run;

proc freq; table class*targetMB1; title 'Standard 50/50 Cutoff'; run;
proc freq; table class2*targetMB1; title 'Optimal Cutoff'; run;

proc print noobs label;
   where class2=1;
   var tdp_asset_name targetMB1 em_eventProbability;
   label targetMB1='Failed?'
         em_eventProbability='P(fail)';
   format targetMB1 failfmt.;
   title 'Assets that might need attention';
run;