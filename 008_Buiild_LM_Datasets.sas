


data ADS00;
   set sato.GBADS1008;
   where unit_name='LM';
   drop esf_turbine_latitude esf_turbine_longitude esf_turbine_elevation erm_downtime_duration erm_fault:
        erm_turbine_description flg_eventinnotes_any mnt: SamplingWeight SelectionProb
        target tdp_operating_status;
run;

data ADS01;
   set ADS00;
   drop esf_turbine_blade_coatings erm_curtail_flg erm_turbine_model; 
   drop PCA: sdp_site: sdp_corrected: tdp_blade_angle_1_actual tdp_blade_angle_2_actual tdp_blade_angle_3_actual;
run;

data sato.GBADS1008v2LM; set work.ADS01; run;


*** Build Summary Datasets ***;

%let VarList=
tdp_yaw_nacelle_position tdp_gen_speed tdp_power_factor tdp_temp_gearbox_oil tdp_temp_gearbox_bearing 
tdp_temp_main_bearing tdp_temp_gen_air_cooler tdp_temp_gen_bearing_de tdp_temp_gen_bearing_nde tdp_hydraulic_pressure tdp_turbine_power 
tdp_tower_acceleration   
tdp_wind_speed tdp_air_temp tdp_state_fault InValidVal_count 
tdp_ResidPower tdp_voltage tdp_voltage_Var tdp_blade_angle tdp_blade_angle_Var  
tdp_blade:;


%let din=GBADS1008v2LM;

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
data casuser.GearBoxSummaryStatsLM&out.; set work.AssetStats; run;
%mend;
%sumdata(0,1008,2);
*%sumdata(1009,2016,1);
*%sumdata(2017,3025,0);




data sato.GearboxSummaryStatsLM2; set casuser.GearboxSummaryStatsLM2; run;
proc sort data=sato.GearboxSummaryStatsLM2; by tdp_asset_name; run;




*** Build Final LM Dataset ***;

proc casutil;
   droptable incaslib='casuser' casdata='LM_ADS_GBX2' quiet;
run;
data casuser.LM_ADS_GBX2 (promote=yes); 
   set sato.GearboxsummarystatsLM2;
run;
proc freqtab data=casuser.LM_ADS_GBX2; table TargetGB2; run;




