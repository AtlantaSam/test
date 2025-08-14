

data ADS00;
   set sato.MBADS1008;
   where unit_name='BG2';
   drop esf_turbine_latitude esf_turbine_longitude esf_turbine_elevation erm_downtime_duration erm_fault:
        erm_turbine_description flg_eventinnotes_any mnt: SamplingWeight SelectionProb
        target tdp_operating_status;
run;

title 'Validation: Unit_Name';
proc freq; table unit_name; run;

title 'EDA';
proc freq; table erm_turbine_model; run;
proc freq; table esf_turbine_blade_coatings; run;
proc freq; table eqp_gen_manufacturer; run;
proc freq; table erm_curtail_flg; run;

/*proc means; var dp_temp_gen_sttr_wndg_var; run;*/
proc means; var PCA:; run;
proc means; var sdp:; run;
proc means data=work.ADS00 (drop=tdp_asset_name); var tdp:; run;

data ADS01;
   set ADS00;
   drop esf_turbine_blade_coatings erm_curtail_flg erm_turbine_model; 
   drop PCA: sdp_site: sdp_corrected: tdp_blade_angle_1_actual tdp_blade_angle_2_actual tdp_blade_angle_3_actual;
   drop tdp_ferrous: tdp_non_ferrous:;
run;

proc contents data=work.ADS01; run;

data sato.MBADS1008v2; set work.ADS01; run;