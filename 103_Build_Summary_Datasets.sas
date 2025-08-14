/*
%let VarList=
tdp_yaw_nacelle_position tdp_gen_speed tdp_power_factor tdp_temp_Mainbearing_oil tdp_temp_Mainbearing_bearing 
tdp_temp_main_bearing tdp_temp_gen_air_cooler tdp_temp_gen_bearing_de tdp_temp_gen_bearing_nde tdp_hydraulic_pressure tdp_turbine_power 
tdp_tower_acceleration sdp_corrected_air_density sdp_site_avg_air_temp sdp_site_avg_wind_dir  
tdp_wind_speed tdp_corrected_wind_speed tdp_air_temp tdp_state_fault InValidVal_count 
tdp_ResidPower tdp_voltage tdp_voltage_Var tdp_blade_angle tdp_blade_angle_Var PCA_T2 PCA_Q 
tdp_blade:;
*/

%let VarList=
tdp_yaw_nacelle_position tdp_gen_speed tdp_power_factor  
tdp_temp_main_bearing tdp_temp_gen_air_cooler tdp_temp_gen_bearing_de tdp_temp_gen_bearing_nde tdp_hydraulic_pressure tdp_turbine_power 
tdp_tower_acceleration   
tdp_wind_speed tdp_air_temp tdp_state_fault InValidVal_count   
tdp_blade:;


%let din=MBADS1008v2;

%macro sumdata(low,high,out);
proc means data=sato.&din. mean std max min nway noprint;
   where (&low.<AssetCount<=&high.);
   class tdp_asset_name;
   var &VarList. ;
   id targetX targetMB2 targetMB1 targetMB0;
   output out=AssetStats (drop=_type_ _freq_) mean=
                         std=
                         max=
                         / autoname;
run;
proc freq data=AssetStats; table targetMB2 targetMB1 targetMB0; run;
data casuser.MainbearingSummaryStats&out.; set work.AssetStats; run;
%mend;
%sumdata(0,1008,2);
%sumdata(1009,2016,1);
%sumdata(2017,3025,0);


proc mdsummary data=Casuser.MainbearingSummaryStats0;
   var _numeric_;
   output out=casuser.cleanupz;
run;
data MissingData (keep=_Column_ N PctMiss);
   retain _Column_ N PctMiss;
   format pctMiss 6.1;
   set casuser.cleanupz;
   n=_Nobs_ + _NMiss_;
   pctMiss=(_NMiss_/n)*100;
run;
proc sort data=work.MissingData; by PctMiss; run;
proc print data=MissingData label;
   var _Column_ N PctMiss;
   label _Column_='Variable'
         N='Num'
         PctMiss='Pct Missing';
   title 'Summary of Missing Data';
run;


data sato.MainbearingSummaryStats0; set casuser.MainbearingSummaryStats0; run;
proc sort data=sato.MainbearingSummaryStats0; by tdp_asset_name; run;

data sato.MainbearingSummaryStats1; set casuser.MainbearingSummaryStats1; run;
proc sort data=sato.MainbearingSummaryStats1; by tdp_asset_name; run;

data sato.MainbearingSummaryStats2; set casuser.MainbearingSummaryStats2; run;
proc sort data=sato.MainbearingSummaryStats2; by tdp_asset_name; run;

/*
proc stdize data=work.ASSETSTATS out=AssetStatsIM
   reponly method=mean;
var 
run;





proc logistic data=work.AssetStatsIM descending outest=betas;
   class targetX;
   model targetX = &din_Mean. / selection=backward slstay=0.2;
run;
proc transpose data=betas out=varlist1; run;
proc sql;
   select distinct _name_
   into :list1 separated by ' '
   from varlist1
   where targetX ne . and 
  _name_ not in ('Intercept','_LNLIKE_');
quit;

proc logistic data=work.AssetStatsIM descending outest=betas;
   class targetX;
   model targetX = &din_STD. / selection=backward slstay=0.2;
run;
proc transpose data=betas out=varlist2; run;
proc sql;
   select distinct _name_
   into :list2 separated by ' '
   from varlist2
   where targetX ne . and 
  _name_ not in ('Intercept','_LNLIKE_');
quit;

*/

%macro mdl(t,xa,xb,stay);
proc logistic data=casuser.Mainbearingsummarystats&t (drop=targetX targetMB&xa TargetMB&xb tdp_asset_name) descending outest=betas outmodel=sato.predMB&t;
   class targetMB&t ;
   model targetMB&t = tdp: / selection=backward slstay=&stay.;
   *output out=pMB&t;
run;
proc logistic inmodel=sato.predMB&t;
   score data=casuser.MainbearingSummaryStats&t out=temp (keep=tdp_asset_name targetMB&t p_1);
run;
data pMB&t; set work.temp (rename=(p_1=pMB&t)); run;
proc means data=pMB&t nway;
   class targetMB&t;
   var pMB&t.;
   output out=impute mean=meanP;
run;
data _null_;
   set work.impute;
   if targetMB&t=0 then do;
      call symput("meanP0",meanP);
   end;
   else do;
      call symput("meanP1",meanP);
   end;
run;
data sato.pMB&t;
   set work.pMB&t;
   if targetMB&t = 0 and pMB&t=. then do;
      pMB&t=&meanP0;
   end;
   if targetMB&t = 1 and pMB&t=. then do;
      pMB&t=&meanP1;
   end;
run;
proc rank data=sato.pMB&t out=temp2 groups=3;
   var pMB&t.;
   ranks rMB&t.;
run;
proc freq; table rMB&t.*targetMB&t.; run;
%mend;
%mdl(0,1,2,.10);
%mdl(1,0,2,.20);
%mdl(2,0,1,.20);

proc sort data=sato.pMB0; by tdp_asset_name; run;
proc sort data=sato.pMB1; by tdp_asset_name; run;
proc sort data=sato.pMB2; by tdp_asset_name; run;







/*

data sato.GBADS1008_Select_GB0i;
   set AssetStats (keep=tdp_asset_name targetX &listF.);
run;



