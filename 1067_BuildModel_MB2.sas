
%let c=(4,3);
data casuser.VarSelect_MB2m;
   set casuser.VarSelect_MB2b;
   where cluster in &c.;
run;
proc sql;
   select distinct Variable
   into :VarSet separated by ' '
   from casuser.VarSelect_MB2m;
quit;             



filename scMB2 filesrvc folderpath="/PMAC Project/Analytics/ScoreCode" filename="scoreMB2.sas" debug=http;

ods graphics on;

proc logistic data=casuser.ads_mbx2
              plots(only)=roc outmodel=modelMBX1;
   class targetMB2;
   model targetMB2 (event='1') = &VarSet. / 
         selection=backward sls=0.3 outroc=rocStats;
   id tdp_asset_name;
   code file=scMB2;
run;

ods graphics off;

data optCut;
   set rocStats;
   specif = 1 - _1mspec_;
   j = _sensit_ + specif -1;
   d = sqrt((1-_sensit_)**2 + (1-specif)**2);
run;
proc sql noprint;
   create table cutoff as
   select _prob_, j
   from optCut
   having j=max(j);
run;
proc sql noprint;
   create table cutoff2 as
   select _prob_, d
   from optCut;*
   having d=min(d);
run;
proc sql noprint;
   create table cutoff2f as
   select _prob_, d
   from optCut
   having d=min(d);
run;
data _null_;
   set work.cutoff2f;
   call symput('cut',_prob_);
run;
proc sgplot data=cutoff2;
   scatter x=_prob_ y=d;
   xaxis values=(0 to 0.6 by .01);
   title "Optimal Cutoff: &cut";
run;




