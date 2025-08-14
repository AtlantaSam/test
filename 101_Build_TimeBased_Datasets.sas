/*
*test;
%let t=10;
%let dsout=xMBADS10;
*/
/*
*1 day;
%let t=144;
%let dsout=MBADS144;
*/


*7 days;
%let t=1008;
%let dsout=MBADS1008;



/*
*30 days;
%let t=4320;
%let dsout=MBADS4320;
*/

data casuser.TargetMB1;
   set canlytcs.ml_abt_29May2021 (keep=tdp_Asset_name timestamp flg_mb_failure);
   where flg_mb_failure=1;
run;
proc sort; by tdp_asset_name timestamp; run;

data casuser.mrgMB1;
   merge casuser.TargetMB1 (in=a)
         canlytcs.ml_abt_29May2021 (datalimit=ALL);
   by tdp_asset_name ;
   if a;
   if tdp_asset_name = 206 and timestamp gt '10Nov2019:00:20:00'dt then delete;
   if tdp_asset_name = 180 and timestamp gt '25Jul2019:12:00:00'dt then delete;
   if flg_mb_failure=1 then failtime=TimeStamp;
run;
proc freq data=casuser.mrgMB1; table tdp_asset_name; run;


data mrgMB1w; set casuser.mrgmb1 (datalimit=ALL);
run;
proc sort; by tdp_asset_name timestamp; run;

data mrgMB1b;
   retain tdp_asset_name timestamp flg_mb_failure;
   set mrgMB1w;
   by tdp_asset_name timestamp;
   if failtime > . then do p=max(_n_-(3*&t.),1) to min(_n_,nobs);
      set mrgMB1w point=p nobs=nobs;
      output;
      end;
run;
proc freq data=work.mrgmb1b; table tdp_asset_name; run;

data mrgMB1c;
   set work.mrgMB1b;
   target=0;
   *where tdp_asset_name not in ('178','185');
run;
proc freq data=work.mrgMB1c; table tdp_asset_name; run;

data sato.MainBear1; set work.mrgMB1c;
run;

* Looks at data PAST failure *;
/*
data mrgGB1b;
   retain tdp_asset_name timestamp flg_gb_failure;
   set mrgGB1w;
   by tdp_asset_name timestamp;
   if failtime > . then do p=max(_n_,1) to min(_n_+5,nobs);
      set mrgGB1w point=p nobs=nobs;
      output;
      end;
run;
*/

* what could be more stable than the same device 'before and after' a repair is made? *;


proc sql;
   select distinct tdp_asset_name
   into :AssetList separated by '","'
   from work.mrgMB1c;
quit;

data TargetMB0;
   set canlytcs.ml_abt_29May2021 (datalimit=ALL);
   where tdp_asset_name not in ("&AssetList.");
run;

data sato.MainBear0; 
   set work.TargetMB0;
run;

proc sort data=sato.MainBear0; by tdp_asset_name timestamp; run;


data MainBear02;
   set sato.MainBear0;
   by tdp_asset_name timestamp;
   retain Count;
   if first.tdp_asset_name then Count=1;
   else Count=Count+1;
   if count gt (3*&t.);
run;
proc means data=work.MainBear02 nonobs n min max; class tdp_asset_name; var count; run;

proc surveyselect data=MainBear02 out=One sampsize=1; strata tdp_asset_name; run;

data MainBear03;
   merge sato.MainBear0
         work.One (in=a);
   by tdp_asset_name timestamp;
   if a then failtime=99;
run;
data test;
   set work.MainBear03;
   where failtime=99;
   *put timestamp datetime18.;
   randnum=ranuni(0);
run;
data test2;
   set test;
   where randnum le 0.1;
   put tdp_asset_name timestamp datetime18.;
run;


data sato.MainBear0f;
   retain tdp_asset_name timestamp flg_mb_failure;
   set MainBear03;
   by tdp_asset_name timestamp;
   if failtime > . then do p=max(_n_-(3*&t.),1) to min(_n_,nobs);
      set MainBear03 point=p nobs=nobs;
      output;
      end;
run;

proc sql;
   select tdp_asset_name,
          count(*) as count
   from sato.MainBear0f
   group by tdp_asset_name;
quit;


data &dsout.;
   set sato.MainBear1 (in=a)
       sato.MainBear0f (in=b);
   if a then targetX=1;
      else targetX=0;
run;
proc freq; table targetX; run;

proc sort data=work.&dsout.; by tdp_asset_name timestamp; run;

data sato.&dsout.;
   set &dsout.;
   by tdp_asset_name timestamp;
   retain AssetCount;
   if first.tdp_asset_name then AssetCount=1;
      else AssetCount=AssetCount+1;

   targetMB2=0;
   targetMB1=0;
   targetMB0=0;

   if targetX=1 then do;
      if AssetCount le (&t.) then targetMB2=1;
      else if (AssetCount gt &t. and AssetCount le (2*&t.)) then targetMB1=1;
      else if AssetCount gt (2*&t.) then targetMB0=1;
   end;
run;
/*
proc print data=sato.&dsout.;
   var tdp_asset_name timestamp targetx AssetCount targetGB2 targetGB1 targetGB0;
run;


/*
data sato.&dsout.;
   set sato.GearBox1 (in=a)
       sato.GearBox0f (in=b);
   if a then targetX=1;
      else targetX=0;
run;
proc freq; table targetX; run;
