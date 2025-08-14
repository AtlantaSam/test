/*
data gb21;
   set sato.gbads1008v2 (rename=(timestamp=timestamp1));
   where AssetCount=1;
   format ts2 datetime20.;
   ts2=timestamp1-2592000;    *** number of seconds in a day * 30 ***;
   keep tdp_asset_name timestamp1 ts2;
run;
data gb22;
   set sato.gbads1008v2 (rename=(timestamp=timestamp2));
   where AssetCount=1008;
   keep tdp_asset_name timestamp2;
run;
data gb23;
   merge work.gb21 work.gb22;
   by tdp_asset_name;
run;
proc sort; by tdp_asset_name; run;
data mrg4320_GB2;
   merge work.gb23
         sato.gbads4320;
   by tdp_asset_name;
   if timestamp ge timestamp1 and
      timestamp le timestamp2;
run;
proc freq; table tdp_asset_name; run;
proc means data=mrg4320_GB2 nonobs n sum;
   class unit_name;
   var flg_gb_issue;
run;

proc means data=sato.gbads4320 noobs n min max; class targetx; var assetcount; run;
*/

/*proc freq data=sato.gbads4320; table targetX; run;*/

proc means data=sato.gbads1008 nonobs n sum;
   class unit_name;
   var flg_gb_issue;
run;
proc means data=sato.gbads4320 nonobs n sum;
   class targetX unit_name;
   var flg_gb_issue;
run;

proc means data=sato.gbads4320 nonobs n sum nway;
   where flg_gb_failure=0 and unit_name='BG2';
   class tdp_asset_name;
   var flg_gb_issue;
   output out=SumIssuesTot4320 (drop=n _type_ _freq_)
         sum=SumTot4320;
   id tdp_asset_name targetX;
run;

data EventNotes;
   *set work.mrg4320_gb2 (keep=tdp_asset_name flg_gb_failure flg_gb_issue erm_fault_notes);
   set sato.gbads4320(keep=unit_name tdp_asset_name flg_gb_failure flg_gb_issue erm_fault_notes targetX);
   where unit_name='BG2' and flg_gb_failure=0;
   *where flg_gb_issue ge 1;
   *where flg_gb_failure=0;
   if index(erm_fault_notes,'OIL') gt 0 and 
      index(erm_fault_notes,'PRESSURE') gt 0 then OilPress=1;
   else OilPress=0;
   if index(erm_fault_notes,'OIL') gt 0 and
      index(erm_fault_notes,'TEMP') gt 0 then OilTemp=1;
   else OilTemp=0;
   if index(erm_fault_notes,'OIL') eq 0 and
      index(erm_fault_notes,'TEMP') gt 0 then Temp=1;
   else Temp=0;
   if index(erm_fault_notes,'OIL') gt 0 and
      index(erm_fault_notes,'LEVEL') gt 0 then OilLevel=1;
   else OilLevel=0;
   if index(erm_fault_notes,'OIL') gt 0 and
      index(erm_fault_notes,'DETERG') gt 0 then OilDeterg=1;
   else OilDeterg=0;
   if index(erm_fault_notes,'REPAIR') gt 0 then Repair=1;
   else Repair=0;
   if index(erm_fault_notes,'BORESCOPE') gt 0 then Borescope=1;
   else Borescope=0;
   if index(erm_fault_notes,'RADIATOR') gt 0 then Radiator=1;
   else Radiator=0;
   if index(erm_fault_notes,'CLEAN') gt 0 then Clean=1;
   else Clean=0;
   if index(erm_fault_notes,'CHECK') gt 0 then Check=1;
   else Check=0;
   if index(erm_fault_notes,'DAMAGED') gt 0 then Damage=1;
   else Damage=0;
   if index(erm_fault_notes,'INSPECT') gt 0 then Inspect=1;
   else Inspect=0;
run;
data evt;
   set EventNotes;
   where OilPress=1 or 
         OilTemp=1 or
         Repair=1 or
         OilLevel=1 or
         Borescope=1 or
         Radiator=1 or
         Clean=1 or
         Check=1 or
         Damage=1 or
         Inspect=1 or
         Temp=1;
run;

proc means data=EventNotes nonobs n sum nway noprint;
   class tdp_asset_name;
   var flg_gb_issue OilPress OilTemp Temp OilLevel 
       OilDeterg Repair BoreScope Radiator Clean Check Damage Inspect;
   id unit_name flg_gb_failure targetX;
   output out=SumIssues4320i (drop=_type_ _freq_)
             sum=SumTotIssue4320 SumOilPress4320 SumOilTemp4320 SumTemp4320 SumOilLevel4320 
             SumOilDeterg4320 SumRepair4320 SumBoreScope4320 SumRadiator4320 
             SumClean4320 SumCheck4320 SumDamage4320 SumInspect4320;
run;

proc hpsplit data=work.SumIssues4320i maxdepth=10;
   target targetX;
   input SumOilPress4320 SumOilTemp4320 SumTemp4320 SumOilLevel4320 
         SumOilDeterg4320 SumRepair4320 SumBoreScope4320 SumRadiator4320 
         SumClean4320 SumCheck4320 SumDamage4320 SumInspect4320;
   output out=pIssue;
   id tdp_asset_name targetX;
   prune none;
run;
proc rank data=work.pIssue out=temp2 groups=3;
   var p_targetX1;
   ranks rFail;
run;
proc freq; table rFail*targetX; run;

data sato.SumIssues4320; 
   retain tdp_asset_name targetGB0 pIssue SumTot4320;
   merge work.SumIssues4320i (in=a rename=(targetX=TargetGB0))
         work.SumIssuesTot4320 (rename=(targetX=TargetGB0))
         work.pIssue (keep=tdp_asset_name p_targetX1 targetX rename=(p_targetX1=pIssue targetX=targetGB0));
   by tdp_asset_name;
   if a;
   *targetGB0=targetX;
   keep tdp_asset_name targetGB0 pIssue sumTot4320 sumRepair4320 sumTemp4320 sumInspect4320 sumOilPress4320 sumOilLevel4320
        sumCheck4320 sumOilTemp4320;
run;
proc freq data=sato.SumIssues4320; table targetGB0; run;
