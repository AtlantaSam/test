/*
*test;
%let t=10;
%let dsout=xGBADS10;
*/
/*
*1 day;
%let t=144;
%let dsout=GBADS144;
*/
/*
*7 days;
%let t=1008;
%let dsout=GBADS1008;
*/

*30 days;
%let t=4320;
%let dsout=GBADS4320;


data casuser.TargetGB1;
   set canlytcs.ml_abt0;
   where flg_gb_failure=1;
run;

data casuser.mrgGB1;
   merge casuser.TargetGB1 (in=a)
         canlytcs.ml_abt0 (datalimit=ALL);
   by tdp_asset_name ;
   if a;
   if flg_gb_failure=1 then failtime=TimeStamp;
run;


data mrgGB1w; set casuser.mrggb1 (datalimit=ALL);
run;
proc sort; by tdp_asset_name timestamp; run;

data mrgGB1b;
   retain tdp_asset_name timestamp flg_gb_failure;
   set mrgGB1w;
   by tdp_asset_name timestamp;
   if failtime > . then do p=max(_n_-(3*&t.),1) to min(_n_,nobs);
      set mrgGB1w point=p nobs=nobs;
      output;
      end;
run;
proc freq data=work.mrggb1b; table tdp_asset_name; run;

data mrgGB1c;
   set work.mrgGB1b;
   target=0;
   where tdp_asset_name not in ('178','185');
run;
proc freq data=work.mrggb1c; table tdp_asset_name; run;

data sato.Gearbox1; set work.mrgGB1c;
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
   from work.mrgGB1c;
quit;

data TargetGB0;
   set canlytcs.ml_abt0 (datalimit=ALL);
   where tdp_asset_name not in ('178','185',"&AssetList.");
run;

data sato.Gearbox0; 
   set work.TargetGB0;
run;

proc sort data=sato.GearBox0; by tdp_asset_name timestamp; run;


data Gearbox02;
   set sato.GearBox0;
   by tdp_asset_name timestamp;
   retain Count;
   if first.tdp_asset_name then Count=1;
   else Count=Count+1;
   if count gt (3*&t.);
run;
proc means data=work.GEARBOX02 nonobs n min max; class tdp_asset_name; var count; run;

proc surveyselect data=GearBox02 out=One sampsize=1; strata tdp_asset_name; run;

data GearBox03;
   merge sato.GearBox0
         work.One (in=a);
   by tdp_asset_name timestamp;
   if a then failtime=99;
run;
data test;
   set work.gearbox03;
   where failtime=99;
   *put timestamp datetime18.;
   randnum=ranuni(0);
run;
data test2;
   set test;
   where randnum le 0.1;
   put tdp_asset_name timestamp datetime18.;
run;


data sato.GearBox0f;
   retain tdp_asset_name timestamp flg_gb_failure;
   set GearBox03;
   by tdp_asset_name timestamp;
   if failtime > . then do p=max(_n_-(3*&t.),1) to min(_n_,nobs);
      set GearBox03 point=p nobs=nobs;
      output;
      end;
run;

proc sql;
   select tdp_asset_name,
          count(*) as count
   from sato.GearBox0f
   group by tdp_asset_name;
quit;


data &dsout.;
   set sato.GearBox1 (in=a)
       sato.GearBox0f (in=b);
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

   targetGB2=0;
   targetGB1=0;
   targetGB0=0;

   if targetX=1 then do;
      if AssetCount le (&t.) then targetGB2=1;
      else if (AssetCount gt &t. and AssetCount le (2*&t.)) then targetGB1=1;
      else if AssetCount gt (2*&t.) then targetGB0=1;
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
