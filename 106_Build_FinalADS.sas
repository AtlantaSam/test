options nolabel;

proc casutil;
   droptable incaslib='casuser' casdata='ADS_MBX0' quiet;
run;

data casuser.ADS_MBX2 (promote=yes); 
   set sato.MainbearingSummaryStats2;
run;


data casuser.ADS_MBX1 (promote=yes);
   merge sato.MainbearingSummaryStats1
         sato.pMB2;
   by tdp_asset_name;
run;

data casuser.ADS_MBX0 (promote=yes);
   merge sato.MainbearingSummaryStats0 (in=a)
         sato.pMB2
         sato.pMB1
         /*sato.SumIssues4320*/
         sato.MntSummaryMB;
   by tdp_asset_name;
   if MntAssetFreq eq . then MntAssetFreq=0;
   if MntInspectFreq eq . then MntInspectFreq=0;
   if MntRepairFreq eq . then MntRepairFreq=0; 
run;
proc freq; table targetMB0; run;