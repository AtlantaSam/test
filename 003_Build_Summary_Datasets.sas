/*
%let VarList=
tdp_yaw_nacelle_position tdp_gen_speed tdp_power_factor tdp_temp_gearbox_oil tdp_temp_gearbox_bearing 
tdp_temp_main_bearing tdp_temp_gen_air_cooler tdp_temp_gen_bearing_de tdp_temp_gen_bearing_nde tdp_hydraulic_pressure tdp_turbine_power 
tdp_tower_acceleration sdp_corrected_air_density sdp_site_avg_air_temp sdp_site_avg_wind_dir  
tdp_wind_speed tdp_corrected_wind_speed tdp_air_temp tdp_state_fault InValidVal_count 
tdp_ResidPower tdp_voltage tdp_voltage_Var tdp_blade_angle tdp_blade_angle_Var PCA_T2 PCA_Q 
tdp_blade:;
*/

%let VarList=
tdp_yaw_nacelle_position tdp_gen_speed tdp_power_factor tdp_temp_gearbox_oil tdp_temp_gearbox_bearing 
tdp_temp_main_bearing tdp_temp_gen_air_cooler tdp_temp_gen_bearing_de tdp_temp_gen_bearing_nde tdp_hydraulic_pressure tdp_turbine_power 
tdp_tower_acceleration   
tdp_wind_speed tdp_air_temp tdp_state_fault InValidVal_count 
tdp_ResidPower tdp_voltage tdp_voltage_Var tdp_blade_angle tdp_blade_angle_Var  
tdp_blade:;


%let din=GBADS1008v2;

%macro sumdata(low,high,out);
proc means data=sato.&din. mean std max min nway noprint;
   where (&low.<AssetCount<=&high.);
   class tdp_asset_name;
   var &VarList. ;
   id targetX targetGB2 targetGB1 targetGB0;
   output out=AssetStats (drop=_type_ _freq_) mean=
                         std=
                         max=
                         / autoname;
run;
proc freq data=AssetStats; table targetGB2 targetGB1 targetGB0; run;
data casuser.GearBoxSummaryStats&out.; set work.AssetStats; run;
%mend;
%sumdata(0,1008,2);
%sumdata(1009,2016,1);
%sumdata(2017,3025,0);


proc mdsummary data=Casuser.GearBoxSummaryStats0;
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


data sato.GearboxSummaryStats0; set casuser.GearboxSummaryStats0; run;
proc sort data=sato.GearboxSummaryStats0; by tdp_asset_name; run;

data sato.GearboxSummaryStats1; set casuser.GearboxSummaryStats1; run;
proc sort data=sato.GearboxSummaryStats1; by tdp_asset_name; run;

data sato.GearboxSummaryStats2; set casuser.GearboxSummaryStats2; run;
proc sort data=sato.GearboxSummaryStats2; by tdp_asset_name; run;

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
proc logistic data=casuser.gearboxsummarystats&t (drop=targetX targetGB&xa Targetgb&xb tdp_asset_name) descending outest=betas outmodel=sato.predGB&t;
   class targetGB&t ;
   model targetGB&t = tdp: / selection=backward slstay=&stay.;
   *output out=pGB&t;
run;
proc logistic inmodel=sato.predGB&t;
   score data=casuser.GearBoxSummaryStats&t out=temp (keep=tdp_asset_name targetGB&t p_1);
run;
data sato.pGB&t; set work.temp (rename=(p_1=pGB&t)); run;
proc means data=sato.pGB&t;
   class targetGB&t;
   var pGB&t.;
run;
proc rank data=sato.pGB&t out=temp2 groups=3;
   var pGB&t.;
   ranks rGB&t.;
run;
proc freq; table rGB&t.*targetGB&t.; run;
%mend;
%mdl(0,1,2,.05);
%mdl(1,0,2,.10);
%mdl(2,0,1,.15);

proc sort data=sato.pGB0; by tdp_asset_name; run;
proc sort data=sato.pGB1; by tdp_asset_name; run;
proc sort data=sato.pGB2; by tdp_asset_name; run;







/*

data sato.GBADS1008_Select_GB0i;
   set AssetStats (keep=tdp_asset_name targetX &listF.);
run;



