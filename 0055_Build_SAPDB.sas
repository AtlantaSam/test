
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

data casuser.mnt_gbx30;
   merge sato.GBADS4320 (in=a keep=tdp_asset_name timestamp targetx targetGB0)
         sato.mnt00 (in=b);
   by tdp_asset_name timestamp;
   if a and b;
   if mnt_category ne '';
run;

data EventNotes;
   set casuser.mnt_gbx30 (keep=unit_name tdp_asset_name mnt_text targetX targetGB0);
   where unit_name='BG2' and targetGB0=0;
   up_mnt_text=upcase(mnt_text);
   if index(up_mnt_text,'OI') gt 0 and 
      index(up_mnt_text,'PRES') gt 0 then OilPress=1;
   else OilPress=0;
   if index(up_mnt_text,'OI') gt 0 and
      index(up_mnt_text,'TEMP') gt 0 then OilTemp=1;
   else OilTemp=0;
   if index(up_mnt_text,'OI') eq 0 and
      index(up_mnt_text,'TEMP') gt 0 then Temp=1;
   else Temp=0;
   if index(up_mnt_text,'OI') gt 0 and
      index(up_mnt_text,'LEV') gt 0 then OilLevel=1;
   else OilLevel=0;
   if index(up_mnt_text,'OIL') gt 0 and
      index(up_mnt_text,'DETERG') gt 0 then OilDeterg=1;
   else OilDeterg=0;
   if index(up_mnt_text,'REPAIR') gt 0 then Repair=1;
   else Repair=0;
   if index(up_mnt_text,'BORESCOPE') gt 0 then Borescope=1;
   else Borescope=0;
   if index(up_mnt_text,'RADIATOR') gt 0 then Radiator=1;
   else Radiator=0;
   if index(up_mnt_text,'CLEAN') gt 0 then Clean=1;
   else Clean=0;
   if index(up_mnt_text,'CHECK') gt 0 then Check=1;
   else Check=0;
   if index(up_mnt_text,'DAMAGED') gt 0 then Damage=1;
   else Damage=0;

   if index(up_mnt_text,'FAULT') gt 0 then Fault=1;
   else Fault=0;
   if index(up_mnt_text,'VIB') gt 0 then Vib=1;
   else Vib=0;
  
run;
proc freq;
   table OilPress OilTemp Temp OilLevel OilDeterg Repair Borescope Radiator Clean Check Damage Fault Vib;
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
         Temp=1 or
         Fault=1;
run;

proc means data=EventNotes nonobs n sum nway noprint;
   class tdp_asset_name;
   var OilPress OilTemp Temp OilLevel 
       Repair BoreScope Radiator Fault;
   id unit_name targetGB0 targetX;
   output out=SumMnti (drop=_type_ _freq_)
             sum=SumOilPressMnt SumOilTempMnt SumTempMnt SumOilLevelMnt 
             SumRepairMnt SumBoreScopeMnt SumRadiatorMnt SumFaultMnt
             ;
run;

proc hpsplit data=work.SumMnti maxdepth=10;
   target targetX;
   input SumOilPressMnt SumOilTempMnt SumTempMnt SumOilLevelMnt 
         SumBoreScopeMnt SumRadiatorMnt SumFaultMnt
         ;
   output out=pMnt;
   id tdp_asset_name targetX targetGB0;
   prune none;
run;
proc rank data=work.pMNT out=temp2 groups=3;
   var p_targetX1;
   ranks rFail;
run;
proc freq; table rFail*targetX; run;

data sato.SumMntDetail; 
   retain tdp_asset_name targetGB0 pMnt;
   merge work.SumMnti (in=a)
         work.pMnt (keep=tdp_asset_name p_targetX1 targetX rename=(p_targetX1=pMnt targetX=targetGB0));
   by tdp_asset_name;
   if a;
   *targetGB0=targetX;
   keep tdp_asset_name targetGB0 pMnt sumFaultMnt sumBoreScopeMnt sumRepairMnt sumOil: sumTempMnt;
run;
proc freq data=sato.SumMntDetail; table targetGB0; run;
