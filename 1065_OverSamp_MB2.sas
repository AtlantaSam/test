proc casutil;
   droptable casdata="ads_mbx2s" incaslib="casuser" quiet;
run;

proc partition data=casuser.ads_mbx2 samppctevt=100 eventprop=0.1
   event="1" seed=10 nthreads=1;
   by targetMB2;
   ods output overfreq=outFreq;
   output out=casuser.out97 copyvars=(tdp_asset_name targetMB1)
          freqname=_freq2;
run;

proc print;
run;

data casuser.ads_mbx2s (promote=yes);
   merge casuser.out97 (in=a drop=_freq2)
         casuser.ads_mbx2;
   by tdp_asset_name;
   if a;
run;

proc varreduce data=casuser.ads_mbx2s technique=discriminantanalysis;  
	class targetMB2;
	reduce supervised targetMB2=  tdp_air_temp: tdp_blade: tdp_gen: tdp_hyd: tdp_temp: tdp_wind: tdp_yaw: /
            maxeffects=4;
	ods output selectionsummary=summary;	     
run;
proc sql;
   select distinct Variable
   into :VarSet separated by ' '
   from work.summary;
quit;

filename scMB2s filesrvc folderpath="/PMAC Project/Analytics/ScoreCode" filename="scoreMB2s.sas" debug=http;

%let xlabel=False Positive Fraction;
%let ylabel=True Positive Fraction;
proc logistic data=casuser.ads_mbx2s (drop=targetX targetMB1 targetMB0) 
              plots(only)=roc outmodel=modelMBX1s;
   class targetMB2;
   model targetMB2 (event='1') = &VarSet.;
   id tdp_asset_name;
   code file=scMB2s;
run;
%symdel xlabel ylabel;


data temp;
   set casuser.ads_mbx1s;
   %include scMBX1s;
run;


filename scMBX1s2 filesrvc folderpath="/PMAC Project/Analytics/ScoreCode" filename="scoreMBX1s2.sas" debug=http;

%let xlabel=False Positive Fraction;
%let ylabel=True Positive Fraction;
proc logselect data=casuser.ads_mbx1s
              ;
   class targetMB1;
   model targetMB1 (event='1') = &VarSet.;
   code file=scMBX1s2;
run;
%symdel xlabel ylabel;


data temp;
   set casuser.ads_mbx1s;
   %include scMBX1s2;
run;


filename scMBX1s3 "/sasdata/projects/AIML/use_case5/code/scoreMBX1s3.sas";

%let xlabel=False Positive Fraction;
%let ylabel=True Positive Fraction;
proc logselect data=casuser.ads_mbx1s
              ;
   class targetMB1;
   model targetMB1 (event='1') = &VarSet.;
   code file=scMBX1s3;
run;
%symdel xlabel ylabel;

data temp;
   set casuser.ads_mbx1s;
   %include scMBX1s3;
run;

libname testx "/sasdata/projects/AIML/use_case5/code";


