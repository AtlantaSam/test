proc casutil;
   droptable incaslib='casuser' casdata='ADS_GBX0' quiet;
run;

data casuser.ADS_GBX2 (promote=yes); 
   set sato.Gearboxsummarystats2;
run;


data casuser.ADS_GBX1 (promote=yes);
   merge sato.GearboxSummaryStats1
         sato.pGB2;
   by tdp_asset_name;
run;

data casuser.ADS_GBX0 (promote=yes);
   merge sato.GearboxSummaryStats0 (in=a)
         sato.pGB2
         sato.pGB1
         sato.SumIssues4320
         sato.MntSummary 
         sato.sumMntDetail;
   by tdp_asset_name;
   if MntAssetFreq eq . then MntAssetFreq=0;
   if MntInspectFreq eq . then MntInspectFreq=0;
   if MntRepairFreq eq . then MntRepairFreq=0; 
   if sumFaultMnt eq . then sumFaultMnt=0;
   if sumBoreScopeMnt eq . then sumBoreScopeMnt=0;
   if sumRepairMnt eq . then sumRepairMnt=0;
   if sumOilPressMnt eq . then sumOilPressMnt=0;
   if sumOilLevelMnt eq . then sumOilLevelMnt=0;
   if sumOilTempMnt eq .  then sumOilTempMnt=0;
   if sumTempMnt eq . then sumTempMnt=0;
run;
proc freq; table targetGB0; run;