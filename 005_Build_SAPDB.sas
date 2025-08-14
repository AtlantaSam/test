data casuser.mnt00;
   set canlytcs.ml_abt0 (datalimit=ALL);
   where unit_name='BG2';
   keep tdp_asset_name Unit_Name timestamp mnt:;
run;

data sato.mnt00; set casuser.mnt00 (datalimit=ALL); run;

proc sort data=sato.mnt00; 
   by tdp_asset_name timestamp; 
run;

proc freq; table tdp_asset_name; run;

proc contents; run;

data mnt01;
   merge sato.GBADS4320 (in=a keep=tdp_asset_name timestamp targetx)
         sato.mnt00 (in=b);
   by tdp_asset_name timestamp;
   if a and b;
   if mnt_category ne '';
run;


proc freq data=mnt01; table mnt_category; run;

proc freq data=work.mnt01; table tdp_asset_name /  out=MntAssetFreq (drop=percent); run;
proc freq data=work.mnt01 (where=(mnt_category='Inspection')); table tdp_asset_name /  out=MntCatFreq (drop=percent); run;
proc freq data=work.mnt01 (where=(mnt_category='Repair')); table tdp_asset_name /  out=MntRepairFreq (drop=percent); run;

data MntSummaryFile00;
   merge MntAssetFreq (rename=(count=MntAssetFreq))
         MntCatFreq (rename=(count=MntInspectFreq))
         MntRepairFreq (rename=(count=MntRepairFreq));
   by tdp_asset_name;
   if MntInspectFreq=. then MntInspectFreq=0;
   if MntRepairFreq=. then MntRepairFreq=0;
run;

data sato.MntSummary; set work.MntSummaryFile00; run;


/*

proc freq data=mnt01; table mnt_category*targetx; run;
proc freq data=mnt01; table tdp_asset_name*mnt_category / list; run;
proc freq data=mnt01; table tdp_asset_name*mnt_text / list; run;





proc means data=mnt01 nonobs n sum;
   class tdp_asset_name;
   var mnt_gbx_inspect_flg;
run;


proc means data=mnt01 nonobs n sum;
   class tdp_asset_name;
   var mnt_gbx_repair_flg;
run;