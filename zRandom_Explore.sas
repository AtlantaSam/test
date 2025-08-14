proc print data=sato.xGBADS10 noobs;
   where tdp_asset_name in ('121');
   var tdp_asset_name timestamp flg_gb_failure targetx AssetCount targetGB2 targetGB1 targetGB0;
run;

proc means data=sato.GBADS1008 (where=(tdp_asset_name='121'));
   where targetGB2=1;
   var AssetCount;
run;

data _121;
   set sato.gbads1008v2;
   where tdp_asset_name='121' and targetGB2=1;
   keep tdp_asset_name targetGB2 AssetCount;
run;
proc means data=_121;
   var AssetCount;
run;

data _121;
   set sato.gbads1008v2;
   where tdp_asset_name='121' and targetGB1=1;
   keep tdp_asset_name targetGB2 AssetCount;
run;
proc means data=_121;
   var AssetCount;
run;

data _121;
   set sato.gbads1008v2;
   where tdp_asset_name='121' and targetGB0=1;
   keep tdp_asset_name targetGB2 AssetCount;
run;
proc means data=_121;
   var AssetCount;
run;

proc freq data=sato.gbADS1008v2;
   table TargetGB2 TargetGB1 TargetGB0;
run;