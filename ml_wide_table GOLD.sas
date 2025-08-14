/*
+---------------------------------------------------------------------------
| PROJECT     | AES PMAC
|---------------------------------------------------------------------------
| NAME        | ml_wide_table.sas
|---------------------------------------------------------------------------
| DESCRIPTION | Creates ML_* tables from TARGET_* tables, applies business
|             | transformations and creates baseline flags
|---------------------------------------------------------------------------
| INPUT       | TARGET_SAP_PLANT
|             | TARGET_ETAPRO_SAP_LOCATION
|             | TARGET_ERAM_ASSET_DOWNTIMES_VDM 
|             | TARGET_ETA_VDM_SAP_FUNCLOC (here down)
|             | TARGET_SAP_EQUIPMENT
|             | TARGET_SAP_MAINTORDER
|             | TARGET_VAISALA_FORECAST_DATA
|             | TARGET_ETAPRO_INT_US_1202_TURB
|             | TARGET_ETAPRO_INT_US_1204_TURB
|             | TARGET_ETAPRO_INT_US_1202_WIDE
|             | TARGET_ETAPRO_INT_US_1204_WIDE
|---------------------------------------------------------------------------
| OUTPUT      | ML_ABT
|             | ML_ABT_UNCORRECTED
|             | ML_VAISALA_FORECAST
|---------------------------------------------------------------------------
| SAS VERSION | Viya 3.5
|---------------------------------------------------------------------------
| DEVELOPMENT/MAINTENANCE HISTORY
| DATE       BY      NOTE
|---------------------------------------------------------------------------
| 23APR2021  JOWALK  Initial version
| 21MAY2021  JOWALK  First release for ML build
| 24MAY2021  JOWALK  Add sdp_corrected_air_density and
|                    vai_site_power_capacity to ML_ABT*; drop spv_latitude
|                    and spv_longitude from ML_ABT*; fix valid values data
|                    lines
| 28 May2021 DACROW  Added CAS info so this can be run in batch.
|
|---------------------------------------------------------------------------
| Copyright (c) 2021 by SAS Institute Inc., Cary, NC 27513 USA
| ---All Rights Reserved.
+---------------------------------------------------------------------------
*/
filename includes '/sasdata/includes';
%inc includes(Libnames);
%inc includes(casinfo);
run;

/***************************************************************/
/* Set libraries, options, parameters, and prepare environment */
/***************************************************************/

options msglevel = i;

libname source "/sasdata/tables";
libname sato "/sasdata/sato";

%let l_loadToCas = Y;
%let l_srcLib = source;
%let l_tgtLib = sato;
%let l_tmpLib = work;
%let l_casLib = canlytcs;
%let l_windFarms = %str(1202, 1204);
%let l_windFarmsNames = %str('BG2','LM');
%let l_windFarmsFullNames = %str('Buffalo Gap II','Laurel Mountain');
%let l_loadFromDttm = %str(01JAN2019:00:00:00);
%Let l_fcKey =  erm_unit_name erm_asset_name erm_downtime_round;

%macro deleteTargetTables();

	%if (%sysfunc(exist(&l_tgtLib..ML_ABT_UNCORRECTED))) %then
	%do;
		proc sql noprint;
			DROP TABLE &l_tgtLib..ML_ABT_UNCORRECTED;
		quit;
	%end;

	%if (%sysfunc(exist(&l_tgtLib..ML_ABT))) %then
	%do;
		proc sql noprint;
			DROP TABLE &l_tgtLib..ML_ABT;
		quit;
	%end;
%mend deleteTargetTables;

%deleteTargetTables


/*****************************************/
/* Geographic information for wind farms */
/*****************************************/
proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_farm_geo_spv AS 
	SELECT   esl.Unit			AS spv_unit
			,spv.SAPLocationID	AS saplocationid	
			,spv.ZipCode		AS spv_site_postal_code
			,spv.Latitude		AS spv_site_latitude
			,spv.Longitude		AS spv_site_longitude
	FROM &l_srcLib..TARGET_SAP_PLANT AS spv
	INNER JOIN &l_srcLib..TARGET_ETAPRO_SAP_LOCATION AS esl
	ON spv.SAPLocationID = esl.SAPLocationID
	WHERE esl.Unit IN (&l_windFarms);
quit;

proc sort data=&l_tmpLib.._ml_abt_farm_geo_spv;
	by spv_unit;
run;

proc sql noprint;
	CREATE INDEX spv_unit ON &l_tmpLib.._ml_abt_farm_geo_spv (spv_unit);
quit;


/***********************************************************/
/* Eram asset data and geographic information for turbines */
/***********************************************************/

proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_eram_asset AS
	SELECT DISTINCT  erm.UnitName			AS erm_unit_name
					,erm.AssetName			AS erm_asset_name
					,esf.SAPFuncLoc			AS sapfuncloc
					,esf.Latitude			AS esf_turbine_latitude
					,esf.Longitude			AS esf_turbine_longitude
					,esf.Elevation			AS esf_turbine_elevation
					,erm.Manufacturer		AS erm_turbine_manufacturer
					,erm.Model				AS erm_turbine_model
					,erm.AssetDescription	AS erm_turbine_description
					,erm.Rating				AS erm_turbine_rating
					,erm.BladeDiameter		AS erm_turbine_blade_diameter
					,esf.Coatings			AS esf_turbine_blade_coatings
					,erm.InstallationMonth	AS erm_turbine_install_month
					,esf.OilType			AS esf_gearbox_oil_type
					,esf.Manufacturer		AS esf_mbearing_manufacturer

	FROM &l_srcLib..TARGET_ERAM_ASSET_DOWNTIMES_VDM AS erm
	LEFT JOIN &l_srcLib..TARGET_ETA_VDM_SAP_FUNCLOC AS esf
	ON esf.UnitName = erm.UnitName
		AND esf.AssetName = erm.AssetName
	WHERE
		
	%if (&l_loadFromDttm NE ) %then
	%do;
		erm.From_Time GE "&l_loadFromDttm"dt
			AND
	%end;
 	
		erm.UnitName IN (&l_windFarmsNames)
	
	/* ORDER BY erm.UnitName, erm.AssetName */
	;

quit;

proc sort data=&l_tmpLib.._ml_abt_eram_asset out=&l_tmpLib.._ml_abt_eram_asset_nd nodupkey;
	by erm_unit_name erm_asset_name;
run;

proc sql noprint;
	CREATE INDEX unit_asset ON &l_tmpLib.._ml_abt_eram_asset_nd (erm_unit_name, erm_asset_name);
	CREATE INDEX sapfuncloc ON &l_tmpLib.._ml_abt_eram_asset_nd (sapfuncloc);
quit;


/**********************/
/* Eram Downtime Data */
/**********************/

proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_eram_erm AS
	SELECT   UnitName 							AS erm_unit_name
			,AssetName 							AS erm_asset_name
			,From_Time 							AS erm_downtime_start
			,To_Time 							AS erm_downtime_end
			,Downtime_category					AS erm_downtime_category
			,Down								AS erm_down
			,ErrNo								AS erm_error_number
			,FlagName							AS erm_fault_code
			,fMarker							AS erm_fault_marker
			,Marker								AS erm_fault_marker_desc
			,Notes 								AS erm_fault_notes 
			,round(To_Time, dhms(0,0,10,0))		AS erm_downtime_end_round format=datetime20. 
			,round(From_Time, dhms(0,0,10,0))	AS erm_downtime_round format=datetime20.

	FROM &l_srcLib..TARGET_ERAM_ASSET_DOWNTIMES_VDM
	WHERE
		
	%if (&l_loadFromDttm NE ) %then
	%do;
		From_Time GE "&l_loadFromDttm"dt
			AND
	%end;
 	
		UnitName IN (&l_windFarmsNames)
	
	/* ORDER BY UnitName, AssetName, From_Time */
	;
quit;

proc sort data=&l_tmpLib.._ml_abt_eram_erm(drop=erm_down erm_error_number erm_fault_marker erm_fault_marker_desc erm_downtime_end_round erm_downtime_round) 
		out=&l_tmpLib.._noduprec0 noduprecs;
	by erm_unit_name erm_asset_name erm_fault_code erm_downtime_start ;
run;

data &l_tmpLib.._noduprec; 
	format _fcgrp temp_TimeDelta_Minutes 8.0;
	retain erm_unit_name erm_asset_name erm_fault_code erm_downtime_start;
	set &l_tmpLib.._noduprec0; * FC changed to combine FCs occuring in a short period of time Tony;
	by erm_unit_name erm_asset_name erm_fault_code erm_downtime_start ;
	erm_fault_notes = upcase(strip(compbl((erm_fault_notes))));
	erm_fault_notes = upcase(strip(erm_fault_notes));
	erm_fault_notes = tranwrd(erm_fault_notes, 'BOROSCOPE', 'BORESCOPE');
	erm_fault_notes = tranwrd(erm_fault_notes, 'TEMP.', 'TEMPERATURE');
	erm_fault_notes = tranwrd(erm_fault_notes, 'PESSURE', 'PRESSURE');
	erm_fault_notes = tranwrd(erm_fault_notes, 'OVERTEMPERATURE', 'OVER TEMPERATURE'); 
	IF erm_fault_notes = 'GEARBOX OIL LEVEL TOO LOW TO OPERATE' then erm_fault_notes = 'GEARBOX OIL LEVEL TOO LOW';

	temp_TimeDelta_Minutes = dif(erm_downtime_start)/60; 
	if first.erm_fault_code then _fcgrp+1;
	else if temp_TimeDelta_Minutes < 1.5*24*60 then _fcgrp+0;
	else _fcgrp+1;

	Flg_EventInNotes_Any = (erm_downtime_end - erm_downtime_start) > 600 and 
				(find(erm_fault_notes, 'repair', 'i') or find(erm_fault_notes, 'replace', 'i') 
				or find(erm_fault_notes, 'failure', 'i') or find(erm_fault_notes, 'r&r', 'i')
 				or find(erm_fault_notes,'exchange','i')>0);

	format Flg_EventInNotes_Any Flg_GB_Failure Flg_MB_Failure Flg_MB_Issue Flg_GB_Issue 3.0  ;
	Flg_GB_Issue = find(erm_fault_notes,'gear box','i')>0 or find(erm_fault_notes,'gearbox','i')>0;
	Flg_MB_Issue = find(erm_fault_notes,'main bearing','i')>0;
	Flg_GB_Failure = (Flg_GB_Issue=1 and Flg_EventInNotes_Any=1) 
		or (erm_fault_code in ('GB-RR', 'GB-R', 'GB-UR') and (erm_downtime_end - erm_downtime_start) >600);
	Flg_MB_Failure = (Flg_MB_Issue=1 and Flg_EventInNotes_Any=1) 
		or (erm_fault_code in ('MB-RR') and (erm_downtime_end - erm_downtime_start) >600);
run;
proc sort data=&l_tmpLib.._noduprec;
	by _fcgrp  erm_downtime_start;
run;
Data &l_tmpLib.._noduprec; set &l_tmpLib.._noduprec;
	by _fcgrp  erm_downtime_start;
	if first._fcgrp then temp_TimeDelta_Minutes=.;
	format erm_downtime_round datetime20.; 
	erm_downtime_round=round(erm_downtime_start, dhms(0,0,10,0));
run;

Proc summary data=&l_tmpLib.._noduprec nway;
	class erm_unit_name erm_asset_name erm_fault_code _fcgrp;
	var erm_downtime_round erm_downtime_start erm_downtime_end Flg_EventInNotes_Any Flg_GB_Failure Flg_MB_Failure Flg_MB_Issue Flg_GB_Issue ;
	output out=&l_tmpLib.._noduprecs(drop=_type_ _freq_) min(erm_downtime_round erm_downtime_start)= 
		max(erm_downtime_end Flg_EventInNotes_Any Flg_GB_Failure Flg_MB_Failure Flg_MB_Issue Flg_GB_Issue )=;
run;

proc sort data=&l_tmpLib.._noduprecs;
	by &l_fcKey. erm_fault_code;
run;
data &l_tmpLib.._noduprec1; set &l_tmpLib.._noduprecs;
	erm_downtime_duration = (erm_downtime_end - erm_downtime_start);  
run;	

proc delete data=&l_tmpLib.._noduprec0 &l_tmpLib.._noduprecs ;
run;

/* Make comma delimited version of faultcode with a note and duration */
proc sort data = &l_tmpLib.._noduprec1(keep = &l_fcKey. erm_fault_code) out = &l_tmpLib.._forCommaDel0 nodupkey ;
	by &l_fcKey. erm_fault_code;
run;

proc transpose data=&l_tmpLib.._forCommaDel0 out=&l_tmpLib.._forCommaDel (drop = _name_ _label_);
	by &l_fcKey.;
	var erm_fault_code;
run;
data &l_tmpLib.._CommaDel;
	set &l_tmpLib.._forCommaDel;
	array cols {*} $ col:;
	erm_fault_code_list = catx(', ', of cols (*));
	drop col:;
run;

proc delete data=&l_tmpLib.._forCommaDel0 &l_tmpLib.._forCommaDel;
run;

/* Get preferred note */
data &l_tmpLib.._preferredNote0; 
	set &l_tmpLib.._noduprec(keep = _fcgrp erm_downtime_category erm_unit_name erm_asset_name erm_downtime_round erm_fault_notes Flg_EventInNotes_Any);
	preferrednote= find(erm_fault_notes, 'gearbox', 'i') or find(erm_fault_notes, 'gear box', 'i') 
		or find(erm_fault_notes, 'main bearing', 'i') or find(erm_fault_notes, 'mainbearing', 'i') 
		+ .5 * Flg_EventInNotes_Any;
	drop Flg_EventInNotes_Any;
run;
proc sort data=&l_tmpLib.._preferredNote0;
	by  _fcgrp descending preferredNote;
run;
data &l_tmpLib.._preferredNote1; set  &l_tmpLib.._preferredNote0;
	by  _fcgrp descending preferredNote;
	if first._fcgrp;
	drop _fcgrp;
run;
proc sort data=&l_tmpLib.._preferredNote1;
	by  &l_fcKey. descending preferredNote;
run;

data &l_tmpLib.._preferredNote; set  &l_tmpLib.._preferredNote1;
	by  &l_fcKey. descending preferredNote;
	if first.erm_downtime_round;
	drop preferrednote;
run;

proc delete data=&l_tmpLib.._preferredNote0 _preferredNote1;
run;

/* get duration */
proc summary data=&l_tmpLib.._noduprec1 nway;
	class &l_fcKey.;
	var erm_downtime_duration erm_downtime_end Flg_:;
	output out=_duration (drop=_type_ _freq_) max=;
run;

/* Merge */
data &l_tmpLib.._FaultCodeReady;
	merge &l_tmpLib.._CommaDel (in=d) _preferredNote (in=e) _duration;
	by &l_fcKey.;
	if (d);
run;

proc sort data=&l_tmpLib.._FaultCodeReady;
	by &l_fcKey;
run;

proc sql noprint;
	CREATE INDEX unit_asset_downtime ON &l_tmpLib.._FaultCodeReady (erm_unit_name, erm_asset_name, erm_downtime_round);
quit;

proc delete data=&l_tmpLib.._CommaDel &l_tmpLib.._preferredNote &l_tmpLib.._duration ;
run;

/**********************************/
/* Generate Eram curtailment flag */
/**********************************/

/* Filter where downtime category is curtailment */
proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_eram_crt AS
	SELECT 	 erm_unit_name
			,erm_asset_name
			,erm_downtime_round
			,erm_downtime_end_round
			,erm_downtime_category
	FROM &l_tmpLib.._ml_abt_eram_erm
	WHERE upcase(erm_downtime_category) CONTAINS "CURTAIL"
	/* ORDER BY erm_unit_name, erm_asset_name, erm_downtime_round */
	;
quit;

/* Remove duplicate records */	 
proc sort data=&l_tmpLib.._ml_abt_eram_crt out=&l_tmpLib.._ml_abt_eram_crt_nd noduprecs;
	by erm_unit_name erm_asset_name erm_downtime_round erm_downtime_end_round erm_downtime_category;
run;

/* Create flag and expand data for each 10 minute interval in curtailment */
data &l_tmpLib.._ml_abt_eram_crt_flg;
	set &l_tmpLib.._ml_abt_eram_crt_nd;

	format erm_interval_downtime datetime20.;

	do erm_interval_downtime = erm_downtime_round to erm_downtime_end_round by 600;
		erm_curtail_flg = 1;
		output;
	end;

	drop erm_downtime_round erm_downtime_end_round erm_downtime_category;
run;

/* Remove duplicate records for any curtailment overlap */
proc sort data=&l_tmpLib.._ml_abt_eram_crt_flg out=&l_tmpLib.._ml_abt_eram_crt_flg_nd noduprecs;
	by erm_unit_name erm_asset_name erm_interval_downtime erm_curtail_flg;
run;

proc sql noprint;
	CREATE INDEX unit_asset_interval ON &l_tmpLib.._ml_abt_eram_crt_flg_nd (erm_unit_name, erm_asset_name, erm_interval_downtime);
quit;


/**********************/
/* SAP Equipment Data */
/**********************/

/* Subset for wind farms of interest */
proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_farm_equipment_vdm AS
	SELECT	 spv.spv_unit
			,eqp.IWERK  	AS saplocationid	/* Planning Plant */
			,sfl.SAPFuncLoc	AS sapfuncloc
			,sfl.AssetName	AS asset_name
			,eqp.TPLNR  	AS sapturbineid
			,eqp.HERST 		AS manufacturer
			,eqp.SERGE 		AS serial_number
			,eqp.EQKTU  	AS equipment_type	/* Equipment description in capital letters */
			,eqp.DATAB 		AS valid_from_date
			,eqp.DATBI		AS valid_to_date
	FROM &l_srcLib..TARGET_SAP_EQUIPMENT AS eqp
	INNER JOIN &l_tmpLib.._ml_abt_farm_geo_spv AS spv
		ON eqp.IWERK = spv.saplocationid
	LEFT JOIN &l_srcLib..TARGET_ETA_VDM_SAP_FUNCLOC AS sfl
		ON substr(eqp.TPLNR,1,8) = sfl.SAPFuncLoc
	WHERE eqp.EQKTU CONTAINS "GEARBOX"
		OR eqp.EQKTU CONTAINS "GENERATOR"
		;

quit;

proc sort data=&l_tmpLib.._ml_abt_farm_equipment_vdm;
	by spv_unit asset_name valid_from_date valid_to_date equipment_type;
run;

proc sql noprint;
	CREATE INDEX unit_asset_from_to_equipment ON &l_tmpLib.._ml_abt_farm_equipment_vdm (spv_unit, asset_name, valid_from_date, valid_to_date, equipment_type);
quit;

/************************/
/* SAP Maintenance Data */
/************************/

/* Subset for wind farms of interest */
proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_farm_maintorder AS
	SELECT   mnt.IWERK	    		AS saplocationid			/* Plant */
			,era.erm_unit_name		AS unit_name
			,substr(mnt.TPLNR,1,8)	AS sapturbineid				/* Turbine Name */
			,era.erm_asset_name		AS asset_name
			,mnt.TPLNR				AS sapfuncloc				/* Functional Location */
			,mnt.ILATX				AS mnt_category				/* Description of maintenance activity type */
			,mnt.KTEXT				AS mnt_text					/* Text */
			,mnt.LTXA1				AS mnt_description			/* Short text */
			,mnt.GSTRP  			AS mnt_basic_start_date		/* Basic Start Date */
			,mnt.GLTRP  			AS mnt_basic_finish_date	/* Basic Finish Date */
			,mnt.GSTRI  			AS mnt_actual_start_date	/* Actual Start Date */
			,mnt.GLTRI  			AS mnt_actual_finish_date	/* Actual Finish Date */
	FROM &l_srcLib..TARGET_SAP_MAINTORDER AS mnt
	INNER JOIN &l_tmpLib.._ML_ABT_ERAM_ASSET AS era
		ON substr(mnt.TPLNR,1,8) = era.sapfuncloc
	WHERE mnt.GSTRP GE datepart("&l_loadFromDttm"dt)
	ORDER BY saplocationid, sapturbineid, sapfuncloc, mnt_basic_start_date
	;
quit;

data &l_tmpLib.._sap_main_00; 
	format _priority 8.0;
	set &l_tmpLib.._ml_abt_farm_maintorder;
	format sapPartLoc $30.;
	sapPartLoc = strip(tranwrd(sapfuncloc, strip(sapturbineid), "")); drop sapfuncloc;
	if substr(sapPartLoc,1,1)='-' then sapPartLoc=substr(sapPartLoc,2);
	Array dts {*} mnt_basic_start_date mnt_basic_finish_date mnt_actual_start_date mnt_actual_finish_date;
	do ii = 1 to dim(dts); drop ii; 
		If year(dts(ii)) < 1990 then dts(ii) = .;
	end;
	format mnt_start_date date9.;
	mnt_start_date = coalesce(mnt_actual_start_date, mnt_basic_start_date);
	drop saplocationid mnt_basic_finish_date mnt_actual_finish_date mnt_actual_start_date mnt_basic_start_date; 

	format mnt_text_extra $128.;
	if strip(compress(mnt_description, '-_.0123456789'))='' then mnt_text_extra='';
	else If strip(mnt_text) = strip(mnt_description) then mnt_text_extra='';
	else mnt_text_extra =mnt_description ;
	if strip(compress(mnt_text, '-_.0123456789'))='' then mnt_text=''; 

	if missing(mnt_text) = 1 and missing(mnt_text_extra) = 0 then do; 
		mnt_text=mnt_text_extra;
		mnt_text_extra='';
	end; 
	else if missing(mnt_text) = 1 and missing(mnt_text_extra) = 1 then delete;

	format mnt_gbx_repair_flg mnt_gbx_replace_flg mnt_gbx_inspect_flg mnt_gbx_prevent_flg 
		 mnt_gen_repair_flg mnt_gen_replace_flg mnt_gen_inspect_flg mnt_gen_prevent_flg 
		 mnt_brg_repair_flg mnt_brg_replace_flg mnt_brg_inspect_flg mnt_brg_prevent_flg 
		 mnt_oil_repair_flg mnt_oil_replace_flg mnt_oil_inspect_flg mnt_oil_prevent_flg 3.0;
	mnt_gbx_repair_flg = 0;
	mnt_gbx_replace_flg = 0;
	mnt_gbx_inspect_flg = 0;
	mnt_gbx_prevent_flg = 0;

	mnt_gen_repair_flg = 0;
	mnt_gen_replace_flg = 0;
	mnt_gen_inspect_flg = 0;
	mnt_gen_prevent_flg = 0;

	mnt_brg_repair_flg = 0;
	mnt_brg_replace_flg = 0;
	mnt_brg_inspect_flg = 0;
	mnt_brg_prevent_flg = 0;

	mnt_oil_repair_flg = 0;
	mnt_oil_replace_flg = 0;
	mnt_oil_inspect_flg = 0;
	mnt_oil_prevent_flg = 0;


	if (find(mnt_description,'gbx','i') > 0 or find(mnt_description,'gear','i') > 0 or find(mnt_description,'gbox','i') > 0) then
	do;
		if (find(mnt_category, 'REPAIR', 'i') > 0) or find(mnt_description,'repair','i') > 0 then
			mnt_gbx_repair_flg = 1;
		else if (find(mnt_category, 'REPLACE', 'i') > 0 or find(mnt_description,'replace','i') > 0 ) then
			mnt_gbx_replace_flg = 1;
		else if (find(mnt_category, 'INSPECTION', 'i') > 0) then
			mnt_gbx_inspect_flg = 1;
		else if (find(mnt_category, 'PREVENTIVE MAINTENANCE', 'i') > 0) then
			mnt_gbx_prevent_flg = 1;
	end;
	
	if (find(mnt_description,'gen','i') > 0 or find(mnt_description,'erator','i') > 0) then
	do;
		if (find(mnt_category, 'REPAIR', 'i') > 0) or find(mnt_description,'repair','i') > 0 then
			mnt_gen_repair_flg = 1;
		else if (find(mnt_category, 'REPLACE', 'i') > 0 or find(mnt_description,'replace','i') > 0 ) then
			mnt_gen_replace_flg = 1;
		else if (find(mnt_category, 'INSPECTION', 'i') > 0) then
			mnt_gen_inspect_flg = 1;
		else if (find(mnt_category, 'PREVENTIVE MAINTENANCE', 'i') > 0) then
			mnt_gen_prevent_flg = 1;
	end;
	
	if (find(mnt_description,'bearing','i') > 0 and find(mnt_description,'main','i') > 0) then
	do;
		if (find(mnt_category, 'REPAIR', 'i') > 0) or find(mnt_description,'repair','i') > 0 then
			mnt_brg_repair_flg = 1;
		else if (find(mnt_category, 'REPLACE', 'i') > 0 or find(mnt_description,'replace','i') > 0 ) then
			mnt_brg_replace_flg = 1;
		else if (find(mnt_category, 'INSPECTION', 'i') > 0) then
			mnt_brg_inspect_flg = 1;
		else if (find(mnt_category, 'PREVENTIVE MAINTENANCE', 'i') > 0) then
			mnt_brg_prevent_flg = 1;
	end;

	if (find(mnt_description,'oil','i') > 0 or find(mnt_description,'grease','i') > 0 or find(mnt_description,'pres','i') > 0 or find(mnt_description,'hydraulic','i') > 0) then
	do;
		if (findw(mnt_category, 'REPAIR', 'i') > 0) then
			mnt_oil_repair_flg = 1;
		else if (findw(mnt_category, 'REPLACE', 'i') > 0) then
			mnt_oil_replace_flg = 1;
		else if (findw(mnt_category, 'INSPECTION', 'i') > 0) then
			mnt_oil_inspect_flg = 1;
		else if (findw(mnt_category, 'PREVENTIVE MAINTENANCE', 'i') > 0) then
			mnt_oil_prevent_flg = 1;
	end;
	_priority = (mnt_gbx_repair_flg + mnt_gbx_replace_flg + mnt_brg_repair_flg + mnt_brg_replace_flg) * 20
				+ sum(mnt_gbx_repair_flg, mnt_gbx_replace_flg, mnt_gbx_inspect_flg, mnt_gbx_prevent_flg 
					, mnt_gen_repair_flg, mnt_gen_replace_flg, mnt_gen_inspect_flg, mnt_gen_prevent_flg 
					, mnt_brg_repair_flg, mnt_brg_replace_flg, mnt_brg_inspect_flg, mnt_brg_prevent_flg 
					, mnt_oil_repair_flg, mnt_oil_replace_flg, mnt_oil_inspect_flg, mnt_oil_prevent_flg) *2
				+ (find(mnt_category, 'REPLACE', 'i') >0) * 1.2
				+ (find(mnt_category, 'REPAIR', 'i') > 0) * 1 
				+ (findw(mnt_category, 'PREVENTIVE MAINTENANCE', 'i') > 0) *.5 ; 

	drop mnt_description;
run;

proc summary data=&l_tmpLib.._sap_main_00 nway;
	var  mnt_gbx_repair_flg mnt_gbx_replace_flg mnt_gbx_inspect_flg mnt_gbx_prevent_flg 
		 mnt_gen_repair_flg mnt_gen_replace_flg mnt_gen_inspect_flg mnt_gen_prevent_flg 
		 mnt_brg_repair_flg mnt_brg_replace_flg mnt_brg_inspect_flg mnt_brg_prevent_flg 
		 mnt_oil_repair_flg mnt_oil_replace_flg mnt_oil_inspect_flg mnt_oil_prevent_flg ; 
	output out=&l_tmpLib.._todrop0(drop=_type_ _freq_) sum=;
run;

proc transpose data=&l_tmpLib.._todrop0 out=&l_tmpLib.._todrop(rename=(Col1=N_Occur));
run;

proc sql noprint;
select _name_ into :dropit separated by ' ' from &l_tmpLib.._todrop where N_Occur=0;
quit;

proc sort data=&l_tmpLib.._sap_main_00 ;
	by unit_name asset_name mnt_start_date descending _priority;
run;

data &l_tmpLib.._mntReady; 
	format  mnt_timestamp datetime20.;
	set &l_tmpLib.._sap_main_00;
	by unit_name asset_name mnt_start_date descending _priority;
	drop &dropit.;
	if first.mnt_start_date then _min=0;
	else _min+30;
	mnt_timestamp=dhms(mnt_start_date,0,_min,0); 
	drop _min mnt_start_date _priority;
run;

proc sort data=&l_tmpLib.._mntReady;
	by unit_name asset_name mnt_timestamp;
run;

proc sql noprint;
	CREATE INDEX unit_asset_timestamp ON &l_tmpLib.._mntReady (unit_name, asset_name, mnt_timestamp);
quit;

proc delete data= &l_tmpLib.._todrop &l_tmpLib.._todrop0 &l_tmpLib.._sap_main_00 &l_tmpLib.._ml_abt_farm_maintorder;
run;


/**********************************/
/* Vaisala historical actual data */
/**********************************/

proc sql noprint;
	CREATE TABLE &l_tmpLib.._ml_abt_vaisala_hist AS
	SELECT 	 CASE project
				WHEN "Buffalo Gap II" THEN "BG2"
				WHEN "Laurel Mountain" THEN "LM"
			 END AS unit_name
			,forecast_time
			,CASE 'variables'n
			 	WHEN "mean_turbine_wind_speed" THEN "wind_speed"
				ELSE 'variables'n
			 END AS variable
			,catx(' - ', translate(compbl(propcase(CALCULATED variable)),' ', '_'), unit) AS label
			,'values'n AS value
	FROM &l_srcLib..TARGET_VAISALA_FORECAST_DATA
	WHERE source EQ ''
		AND project IN (&l_windFarmsFullNames)

	%if (&l_loadFromDttm NE ) %then
	%do;
		AND forecast_time GE "&l_loadFromDttm"dt
	%end;
	
	ORDER BY unit_name, forecast_time
	;
quit;

proc transpose data=&l_tmpLib.._ml_abt_vaisala_hist out=&l_tmpLib.._ml_abt_vaisala_hist_trnsp (drop=_NAME_ _LABEL_);
	by unit_name forecast_time;
	id variable;
	idlabel label;
	var value;
run;

proc sort data=&l_tmpLib.._ml_abt_vaisala_hist_trnsp out=&l_tmpLib.._ml_abt_vaisala_hist_trnsp_nd nodupkey;
	by unit_name forecast_time;
run;

proc sql noprint;
	CREATE INDEX unit_name_forecast_time ON &l_tmpLib.._ml_abt_vaisala_hist_trnsp_nd (unit_name, forecast_time);
quit;


/*************************************************************************************/
/* Iterate for each wind farm, transform turbine and site data points, join into ABT */ 
/*************************************************************************************/

%macro iterate_wind_farms (p_windFarms= );
	
	%let l_countFarms = %eval(%sysfunc(countc(&p_windFarms,",")) + 1);
	%put l_countFarms = &l_countFarms;

	%do i=1 %to &l_countFarms;
		%let l_windFarm = %scan(&p_windFarms, &i, ',');
		%put l_windFarm = &l_windFarm;

		
		/***********************/
		/* Turbine data points */
		/***********************/

		/* Transform */
		proc sql noprint;
			CREATE TABLE &l_tmpLib.._ml_abt_farm_&l_windFarm._tdp AS
			SELECT   Unit 					AS tdp_unit
					,UnitName				AS tdp_unit_name
					,AssetName				AS tdp_asset_name
					,Timestamp				AS tdp_timestamp
					,datepart(Timestamp)	AS tdp_date

					,Blade1Set				AS tdp_blade_angle_1_set
					,Blade2Set				AS tdp_blade_angle_2_set
					,Blade3Set    			AS tdp_blade_angle_3_set
					,Blade1Actual 			AS tdp_blade_angle_1_actual
					,Blade2Actual			AS tdp_blade_angle_2_actual
					,Blade3Actual			AS tdp_blade_angle_3_actual
					,NacellePosition		AS tdp_yaw_nacelle_position
					,GeneratorSpeed			AS tdp_gen_speed
					,GeneratorSpeed_PLC_	AS tdp_gen_speed_plc
					,RotorSpeed_PLC_		AS tdp_rotor_speed_plc
					,PowerFactor 			AS tdp_power_factor

					,TemperatureGearboxOil				AS tdp_temp_gearbox_oil
					,TemperatureGearboxBearing_HSS_		AS tdp_temp_gearbox_bearing
					,TemperatureNacelle					AS tdp_nacelle_temp
					,TemperatureMainShaft				AS tdp_temp_main_bearing
					,TemperatureGeneratorAirCooler		AS tdp_temp_gen_air_cooler
					,TemperatureGeneratorBearing_DE_	AS tdp_temp_gen_bearing_de
					,TemperatureGeneratorBearing_NDE_	AS tdp_temp_gen_bearing_nde
					,TemperatureGeneratorStatorWindi0	AS tdp_temp_gen_sttr_wndg_l1
					,TemperatureGeneratorStatorWindin	AS tdp_temp_gen_sttr_wndg_l2
					,TemperatureMainBox					AS tdp_temp_main_box
					,OilCondition						AS tdp_oil_condition
					
				/*Ferrous information only available for 1204 */
				%if (&l_windFarm EQ 1204) %then
				%do;
					,FerrousCount1 AS tdp_ferrous_count_1
					,FerrousCount2 AS tdp_ferrous_count_2
					,FerrousCount3 AS tdp_ferrous_count_3
					,FerrousCount4 AS tdp_ferrous_count_4
					,FerrousCount5 AS tdp_ferrous_count_5
					,FerrousCount6 AS tdp_ferrous_count_6
					,FerrousCount7 AS tdp_ferrous_count_7
					,FerrousCount8 AS tdp_ferrous_count_8
					,FerrousConcentrationEstimate AS tdp_ferrous_conc_est
					,NonFerrousCount1 AS tdp_non_ferrous_count_1
					,NonFerrousCount2 AS tdp_non_ferrous_count_2
					,NonFerrousCount3 AS tdp_non_ferrous_count_3
					,NonFerrousCount4 AS tdp_non_ferrous_count_4
					,NonFerrousCount5 AS tdp_non_ferrous_count_5
					,NonFerrousCount6 AS tdp_non_ferrous_count_6
					,NonFerrousCount7 AS tdp_non_ferrous_count_7
					,NonFerrousCount8 AS tdp_non_ferrous_count_8
					,NonFerrousConcentrationEstimate AS tdp_non_ferrous_conc_est
				%end;
				%else
				%do;
					,. AS tdp_ferrous_count_1
					,. AS tdp_ferrous_count_2
					,. AS tdp_ferrous_count_3
					,. AS tdp_ferrous_count_4
					,. AS tdp_ferrous_count_5
					,. AS tdp_ferrous_count_6
					,. AS tdp_ferrous_count_7
					,. AS tdp_ferrous_count_8
					,. AS tdp_ferrous_conc_est
					,. AS tdp_non_ferrous_count_1
					,. AS tdp_non_ferrous_count_2
					,. AS tdp_non_ferrous_count_3
					,. AS tdp_non_ferrous_count_4
					,. AS tdp_non_ferrous_count_5
					,. AS tdp_non_ferrous_count_6
					,. AS tdp_non_ferrous_count_7
					,. AS tdp_non_ferrous_count_8
					,. AS tdp_non_ferrous_conc_est
				%end;

					,HydraulicPressure 					AS tdp_hydraulic_pressure
					,VibrationCondition 				AS tdp_vibration_condition

					,TurbinePower 						AS tdp_turbine_power
					,TowerAcceleration					AS tdp_tower_acceleration
					,VoltageA							AS tdp_voltage_a
					,VoltageB							AS tdp_voltage_b
					,VoltageC							AS tdp_voltage_c
					,CurrentPhaseA 						AS tdp_current_phase_a
					,CurrentPhaseB 						AS tdp_current_phase_b
					,CurrentPhaseC 						AS tdp_current_phase_c
					,WindSpeed 							AS tdp_wind_speed
					,TemperatureAmbient 				AS tdp_air_temp
					,AirDensityCorrected10MinWindSpee	AS tdp_corrected_wind_speed
					,APRStatus 							AS tdp_operating_status
					,StateFault							AS tdp_state_fault

				   /*
				 	* Columns in both 1202_TURB and 1204_TURB not included:
					* BorescopeCondition
					* ExpectedEnergyAdj
					* Frequency
					* MaintenanceTimeEndOfLastMonth
					* MaintenanceTimeTotalSinceCommiss
					* TemperatureTrendCondition
					* TorqueSet
					* WeatherOutTimeEndOfLastMonth
					* WeatherOutTimeTotalSinceCommissi
				    */
					
			FROM &l_srcLib..TARGET_ETAPRO_INT_US_&l_windFarm._TURB
			
			%if (&l_loadFromDttm NE ) %then
			%do;
				WHERE timestamp GE "&l_loadFromDttm"dt
			%end;

			/* ORDER BY Unit, AssetName, TimeStamp */
			;
		quit;

		/* Round timestamp to the nearest 10 minutes */
		data  &l_tmpLib.._ml_abt_farm_&l_windFarm._tdp_ts;
			set  &l_tmpLib.._ml_abt_farm_&l_windFarm._tdp;
		
			tdp_timestamp = round(tdp_timestamp, dhms(0,0,10,0));
		run;
		
		/* Ensure no duplicates */
		proc sort data=&l_tmpLib.._ml_abt_farm_&l_windFarm._tdp_ts out=&l_tmpLib.._ml_abt_farm_&l_windFarm._tdp_ts_nd nodupkey;
			by tdp_unit tdp_asset_name tdp_timestamp;
		run;

		proc sql noprint;
			CREATE INDEX unit_date ON &l_tmpLib.._ml_abt_farm_&l_windFarm._tdp_ts_nd (tdp_unit, tdp_date);
			CREATE INDEX unit_asset_timestamp ON &l_tmpLib.._ml_abt_farm_&l_windFarm._tdp_ts_nd (tdp_unit_name, tdp_asset_name, tdp_timestamp);
		quit;


		/********************/
		/* Site data points */
		/********************/

		/* Transform */
		proc sql noprint;
			CREATE TABLE &l_tmpLib.._ml_abt_farm_&l_windFarm._sdp AS
			SELECT   Unit					AS sdp_unit
					,UnitName				AS sdp_unit_name
					,Timestamp				AS sdp_timestamp
					,SitePower				AS sdp_site_power
					,CASE
						WHEN Unit=1202 AND month(datepart(TimeStamp)) IN (11,12,1,2,3) THEN 1
						WHEN Unit=1204 AND month(datepart(TimeStamp)) IN (10,11,12,1,2,3,4) THEN 1
						ELSE 0
					 END 					AS sdp_wind_season_flg
					,AirDensityCorrection	AS sdp_corrected_air_density

				%if (&l_windFarm EQ 1202) %then
				%do;
					/* Note 1202 has 10 minute instantaneous values */
					,mean(Met501_Pressure, Met502_Pressure, Met503_Pressure, Met504_Pressure, Met505_Pressure) 					AS sdp_site_avg_air_pressure
					,mean(Met501_Temperature, Met502_Temperature, Met503_Temperature, Met504_Temperature, Met505_Temperature)	AS sdp_site_avg_air_temp
					,. 																											AS sdp_site_avg_rain
					/* Source does not have Met504_WindDirection1 */
					,mean(Met501_WindDirection1, Met502_WindDirection1, Met503_WindDirection1, Met505_WindDirection1)			AS sdp_site_avg_wind_dir
					,mean(Met501_WindSpeed1, Met502_WindSpeed1, Met503_WindSpeed1, Met504_WindSpeed1, Met505_WindSpeed1)		AS sdp_site_avg_wind_speed
				%end;
				%else %if (&l_windFarm EQ 1204) %then
				%do;
					/* Note 1204 has 10 minute average values */
					,mean(Met101_Pressure_10MinAverage, Met102_Pressure_10MinAverage) 		AS sdp_site_avg_air_pressure
					,mean(Met101_Temperature_10MinAverage, Met102_Temperature_10MinAverage) AS sdp_site_avg_air_temp
					,mean(Met101_Rain_mm, Met102_Rain_mm)									AS sdp_site_avg_rain
					,mean(Met101_Direction1_10MinAverage, Met102_Direction1_10MinAverage)	AS sdp_site_avg_wind_dir
					,mean(Met101_WindSpeed1_10MinAverage, Met102_WindSpeed1_10MinAverage)	AS sdp_site_avg_wind_speed
				%end;
				%else
				%do;
					,. AS sdp_site_avg_air_pressure
					,. AS sdp_site_avg_air_temp
					,. AS sdp_site_avg_rain
					,. AS sdp_site_avg_wind_dir
					,. AS sdp_site_avg_wind_speed
				%end;

			FROM &l_srcLib..TARGET_ETAPRO_INT_US_&l_windFarm._WIDE
			
			%if (&l_loadFromDttm NE ) %then
			%do;
				WHERE timestamp GE "&l_loadFromDttm"dt
			%end;
			
			/* ORDER BY Unit, TimeStamp */
			;
		quit;

		/* Round timestamp to the nearest 10 minutes */
		data  &l_tmpLib.._ml_abt_farm_&l_windFarm._sdp_ts;
			set  &l_tmpLib.._ml_abt_farm_&l_windFarm._sdp;
		
			sdp_timestamp = round(sdp_timestamp, dhms(0,0,10,0));
		run;
		
		/* Ensure no duplicates */
		proc sort data=&l_tmpLib.._ml_abt_farm_&l_windFarm._sdp_ts out=&l_tmpLib.._ml_abt_farm_&l_windFarm._sdp_ts_nd nodupkey;
			by sdp_unit sdp_timestamp;
		run;

		proc sql noprint;
			CREATE INDEX unit_timestamp ON &l_tmpLib.._ml_abt_farm_&l_windFarm._sdp_ts_nd (sdp_unit, sdp_timestamp);
		quit;

		/* Join into Analytic Base Table */
		proc sql _method;
			CREATE TABLE _ML_ABT_FARM_&l_windFarm._JOIN AS
			SELECT   coalesce(sdp.sdp_timestamp, tdp.tdp_timestamp) AS timestamp format=datetime20. label="Timestamp"
					,spv.spv_unit AS unit label="Site Number"
					,coalesce(sdp.sdp_unit_name, tdp.tdp_unit_name) AS unit_name label="Site Name"
					,spv.spv_site_postal_code label="Site Postal Code"
					,spv.spv_site_latitude label="Site Latitude"
					,spv.spv_site_longitude label="Site Longitude"
					,tdp.tdp_asset_name label="Asset Name"
					,era.esf_turbine_latitude label="Turbine Latitude"
					,era.esf_turbine_longitude label="Turbine Longitude"
					,era.esf_turbine_elevation label="Turbine Elevation"
					,era.erm_turbine_manufacturer label="Turbine Manufacturer"
					,era.erm_turbine_rating label="Turbine Rating"
					,era.erm_turbine_install_month label="Turbine Install Month"
					,era.erm_turbine_model label="Turbine Model"
					,era.erm_turbine_description label="Turbine Description"
					,era.erm_turbine_blade_diameter label="Turbine Blade Diameter"
					,era.esf_turbine_blade_coatings label="Turbine Blade Coatings"
					,gbx.manufacturer AS eqp_gearbox_manufacturer label="Gearbox Manufacturer"
					,gbx.valid_from_date AS eqp_gearbox_inservice_date label="Gearbox Inservice Date"
					,gbx.serial_number AS eqp_gearbox_serial_number label="Gearbox Serial Number"
					,era.esf_gearbox_oil_type label="Gearbox Oil Type"
					,gen.manufacturer AS eqp_gen_manufacturer label="Generator Manufacturer"
					,gen.valid_from_date AS eqp_gen_inservice_date label="Generator Inservice Date"
					,gen.serial_number AS eqp_gen_serial_number label="Generator Serial Number"
					,era.esf_mbearing_manufacturer label="Main Bearing Manufacturer"
					,tdp.tdp_blade_angle_1_set label="Blade Angle 1 Set"
					,tdp.tdp_blade_angle_2_set label="Blade Angle 2 Set"
					,tdp.tdp_blade_angle_3_set label="Blade Angle 3 Set"
					,tdp.tdp_blade_angle_1_actual label="Blade Angle 1 Actual"
					,tdp.tdp_blade_angle_2_actual label="Blade Angle 2 Actual"
					,tdp.tdp_blade_angle_3_actual label="Blade Angle 3 Actual"
					,tdp.tdp_yaw_nacelle_position label="Yaw/Nacelle Position"
					,tdp.tdp_gen_speed label="Generator Speed"
					,tdp.tdp_gen_speed_plc label="Generator Speed PLC"
					,tdp.tdp_rotor_speed_plc label="Rotor Speed PLC"
					,tdp.tdp_power_factor label="Power Factor"
					,coalesce(crt.erm_curtail_flg, 0) AS erm_curtail_flg label="Curtailment Flag"
					,tdp.tdp_temp_gearbox_oil label="Gearbox Oil Temperature"
					,tdp.tdp_temp_gearbox_bearing label="Gearbox Shaft Bearing Temperature"
					,tdp.tdp_nacelle_temp label="Nacelle Temperature"
					,tdp.tdp_temp_main_bearing label="Temperature Main Bearing"
					,tdp_temp_gen_air_cooler label="Temperature Generator Air Cooler"
					,tdp_temp_gen_bearing_de label="Temperature Generator Bearing DE"
					,tdp_temp_gen_bearing_nde label="Temperature Generator Bearing NDE"
					,tdp_temp_gen_sttr_wndg_l1 label="Temperature Generator Stator Winding L1"
					,tdp_temp_gen_sttr_wndg_l2 label="Temperature Generator Stator Winding L2"
					,tdp_temp_main_box label="Temperature Main Box"
					,tdp.tdp_oil_condition label="Oil Condition"
					,tdp.tdp_ferrous_count_1 label="Ferrous Count 1"
					,tdp.tdp_ferrous_count_2 label="Ferrous Count 2"
					,tdp.tdp_ferrous_count_3 label="Ferrous Count 3"
					,tdp.tdp_ferrous_count_4 label="Ferrous Count 4"
					,tdp.tdp_ferrous_count_5 label="Ferrous Count 5"
					,tdp.tdp_ferrous_count_6 label="Ferrous Count 6"
					,tdp.tdp_ferrous_count_7 label="Ferrous Count 7"
					,tdp.tdp_ferrous_count_8 label="Ferrous Count 8"
					,tdp.tdp_ferrous_conc_est label="Ferrous Concentration Estimate"
					,tdp_non_ferrous_count_1 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_2 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_3 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_4 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_5 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_6 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_7 label="Non Ferrous Count 1"
					,tdp_non_ferrous_count_8 label="Non Ferrous Count 1"
					,tdp_non_ferrous_conc_est label="Non Ferrous Concentration Estimate"
					,tdp.tdp_hydraulic_pressure label="Hydraulic Pressure"
					,tdp.tdp_vibration_condition label="Vibration Condition"
					,sdp.sdp_site_power label="Site Power"
					,vai.power_capacity AS vai_site_power_capacity label="Site Power Capacity"
					,tdp.tdp_turbine_power label="Turbine Power"
					,tdp.tdp_tower_acceleration label="Tower Acceleration"
					,tdp.tdp_voltage_a label="Voltage A"
					,tdp.tdp_voltage_b label="Voltage B"
					,tdp.tdp_voltage_c label="Voltage C"
					,tdp.tdp_current_phase_a label="Current Phase A"
					,tdp.tdp_current_phase_b label="Current Phase B"
					,tdp.tdp_current_phase_c label="Current Phase C"
					,sdp.sdp_wind_season_flg label="Wind Season Flag"
					,sdp.sdp_corrected_air_density label="Site Corrected Air Density"
					,sdp.sdp_site_avg_air_pressure label="Site Average Air Pressure"
					,sdp.sdp_site_avg_air_temp label="Site Average Air Temperature"
					,sdp_site_avg_rain label="Site Average Rain"
					,sdp_site_avg_wind_dir label="Site Average Wind Direction"
					,sdp_site_avg_wind_speed label="Site Average Wind Speed"
					,tdp.tdp_wind_speed label="Turbine Wind Speed"
					,tdp.tdp_corrected_wind_speed label="Corrected Turbine Wind Speed"
					,tdp.tdp_air_temp label="Turbine Air Temperature"
					,tdp.tdp_operating_status label="Operating Status"
					,tdp.tdp_state_fault label="State Fault"
					,erm_downtime_category 
					,erm.erm_downtime_end label="Downtime End"
					,erm.erm_downtime_duration label="Downtime Duration"
					,erm.erm_fault_code_list label="Fault Code List"
					,erm.erm_fault_notes label="Fault Notes"
					,coalesce(erm.flg_eventinnotes_any, 0) AS flg_eventinnotes_any label="Event In Notes Flag"
					,coalesce(erm.flg_gb_failure, 0) AS flg_gb_failure label="Gearbox Failure Flag"
					,coalesce(erm.flg_gb_issue, 0) AS flg_gb_issue label="Gearbox Issue Flag"
					,coalesce(erm.flg_mb_failure, 0) AS flg_mb_failure label="Main Bearing Failure Flag"
					,coalesce(erm.flg_mb_issue, 0) AS flg_mb_issue label="Main Bearing Issue Flag"
					,mnt.mnt_category label="Maintenance Category"
					,mnt.mnt_text label="Maintenance Text"
					,mnt.sapPartLoc AS mnt_sap_part_location label="Maintenance SAP Part Location"
					,mnt.mnt_text_extra label="Maintenance Text Extra"
					,coalesce(mnt.mnt_gbx_repair_flg, 0) AS mnt_gbx_repair_flg label="Maintenance Gearbox Repair Flag"
					,coalesce(mnt.mnt_gbx_replace_flg, 0) AS mnt_gbx_replace_flg label="Maintenance Gearbox Replace Flag"
					,coalesce(mnt.mnt_gbx_inspect_flg, 0) AS mnt_gbx_inspect_flg label="Maintenance Gearbox Inspect Flag"
					,coalesce(mnt.mnt_gbx_prevent_flg, 0) AS mnt_gbx_prevent_flg label="Maintenance Gearbox Preventive Flag"
					,coalesce(mnt.mnt_gen_repair_flg, 0) AS mnt_gen_repair_flg label="Maintenance Generator Repair Flag"
					,coalesce(mnt.mnt_gen_replace_flg, 0) AS mnt_gen_replace_flg label="Maintenance Generator Replace Flag"
					,coalesce(mnt.mnt_gen_inspect_flg, 0) AS mnt_gen_inspect_flg label="Maintenance Generator Inspect Flag"
					,coalesce(mnt.mnt_gen_prevent_flg, 0) AS mnt_gen_prevent_flg label="Maintenance Generator Preventive Flag"
					,coalesce(mnt.mnt_brg_repair_flg, 0) AS mnt_brg_repair_flg label="Maintenance Main Bearing Repair Flag"
					,coalesce(mnt.mnt_brg_replace_flg, 0) AS mnt_brg_replace_flg label="Maintenance Main Bearing Replace Flag"
					,coalesce(mnt.mnt_brg_inspect_flg, 0) AS mnt_brg_inspect_flg label="Maintenance Main Bearing Inspect Flag"

			FROM &l_tmpLib.._ml_abt_farm_geo_spv AS spv
			INNER JOIN &l_tmpLib.._ml_abt_farm_&l_windFarm._tdp_ts_nd AS tdp
				ON spv.spv_unit = tdp.tdp_unit
			LEFT JOIN &l_tmpLib.._ml_abt_eram_asset AS era
				ON era.erm_unit_name = tdp.tdp_unit_name
					AND era.erm_asset_name = tdp.tdp_asset_name
			LEFT JOIN &l_tmpLib.._ml_abt_farm_equipment_vdm AS gbx
				ON gbx.spv_unit = tdp.tdp_unit
					AND gbx.asset_name = tdp.tdp_asset_name
					AND tdp_date BETWEEN gbx.valid_from_date AND gbx.valid_to_date
					AND gbx.equipment_type CONTAINS "GEARBOX"
			LEFT JOIN &l_tmpLib.._ml_abt_farm_equipment_vdm AS gen
				ON gen.spv_unit = tdp.tdp_unit
					AND gen.asset_name = tdp.tdp_asset_name
					AND tdp_date BETWEEN gen.valid_from_date AND gen.valid_to_date
					AND gen.equipment_type CONTAINS "GENERATOR"
			LEFT JOIN &l_tmpLib.._ml_abt_eram_crt_flg_nd AS crt
				ON crt.erm_unit_name = tdp.tdp_unit_name
					AND crt.erm_asset_name = tdp.tdp_asset_name
					AND crt.erm_interval_downtime = tdp.tdp_timestamp
			LEFT JOIN &l_tmpLib.._FaultCodeReady AS erm
				ON erm.erm_unit_name = tdp.tdp_unit_name
					AND erm.erm_asset_name = tdp.tdp_asset_name
					AND erm.erm_downtime_round = tdp.tdp_timestamp
			LEFT JOIN &l_tmpLib.._MntReady AS mnt			
				ON mnt.unit_name = tdp.tdp_unit_name
					AND mnt.asset_name = tdp_asset_name
					AND mnt.mnt_timestamp = tdp.tdp_timestamp
			/* Capture instances where site measurements but no turbine measurements - increases resulting record count */
			FULL JOIN &l_tmpLib.._ml_abt_farm_&l_windFarm._sdp_ts_nd AS sdp
				ON sdp.sdp_unit = tdp.tdp_unit
					AND sdp.sdp_timestamp = tdp.tdp_timestamp
			LEFT JOIN &l_tmpLib.._ml_abt_vaisala_hist_trnsp_nd AS vai
				ON vai.unit_name = sdp.sdp_unit_name
					AND vai.forecast_time = sdp.sdp_timestamp
			;

	  		ALTER TABLE _ML_ABT_FARM_&l_windFarm._JOIN
    		MODIFY   tdp_asset_name CHAR(5) format=$5.
			 		,unit_name CHAR(3) format=$3.
					;

		quit;

		proc append base=&l_tgtLib..ML_ABT_UNCORRECTED (compress = yes) data=_ML_ABT_FARM_&l_windFarm._JOIN;
		run;
		
	%end;
%mend iterate_wind_farms;

%iterate_wind_farms(p_windFarms = &l_windFarms)


/**************************/
/* Check for valid values */
/**************************/

/* Build table of valid values as provided by Andrew */
data &l_tmpLib.._valid1;
	input  unit_name &$ _Column_ &$26. LowestPossible HighestPossible; 
	lines;
BG2  erm_turbine_blade_diameter  77  77  
LM  erm_turbine_blade_diameter  82  82  
BG2  erm_turbine_rating  1500  1500  
LM  erm_turbine_rating  1600  1600  
BG2  sdp_corrected_air_density  0  365  
LM  sdp_corrected_air_density  0  365  
BG2  sdp_site_avg_wind_dir  0  360  
LM  sdp_site_avg_wind_dir  0  360  
BG2  sdp_site_avg_air_pressure  0  15  
LM  sdp_site_avg_air_pressure  890  925  
BG2  sdp_site_power  -1000  232500  
LM  sdp_site_power  -1000  98000  
BG2  sdp_site_avg_air_temp  -36  45  
LM  sdp_site_avg_air_temp  -36  45  
BG2  sdp_site_avg_wind_speed  0  35  
LM  sdp_site_avg_wind_speed  0  35  
BG2  sdp_wind_season_flg  0  1  
LM  sdp_wind_season_flg  0  1  
BG2  spv_site_latitude  32.33429  32.33429  
LM  spv_site_latitude  39.00242  39.00242  
BG2  spv_site_longitude  -100.172  -100.172  
LM  spv_site_longitude  -79.8885  -79.8885  
BG2  tdp_air_temp  -30  140  
LM  tdp_air_temp  -40  140  
BG2  tdp_blade_angle_1_actual  -3  90  
LM  tdp_blade_angle_1_actual  -3  90  
BG2  tdp_blade_angle_1_set  -3  90  
LM  tdp_blade_angle_1_set  -3  90  
BG2  tdp_blade_angle_2_actual  -3  90  
LM  tdp_blade_angle_2_actual  -3  90  
BG2  tdp_blade_angle_2_set  -3  90  
LM  tdp_blade_angle_2_set  -3  90  
BG2  tdp_blade_angle_3_actual  -3  90  
LM  tdp_blade_angle_3_actual  -3  90  
BG2  tdp_blade_angle_3_set  -3  90  
LM  tdp_blade_angle_3_set  -3  90  
BG2  tdp_corrected_wind_speed  0  35  
LM  tdp_corrected_wind_speed  0  35  
BG2  tdp_current_phase_a  0  1500  
LM  tdp_current_phase_a  0  1500  
BG2  tdp_current_phase_b  0  1500  
LM  tdp_current_phase_b  0  1500  
BG2  tdp_current_phase_c  0  1500  
LM  tdp_current_phase_c  0  1500  
BG2  tdp_ferrous_conc_est  0  35  
LM  tdp_ferrous_conc_est  0  35  
BG2  tdp_ferrous_count_1  0  65535  
LM  tdp_ferrous_count_1  0  65535  
BG2  tdp_ferrous_count_2  0  65535  
LM  tdp_ferrous_count_2  0  65535  
BG2  tdp_ferrous_count_3  0  65535  
LM  tdp_ferrous_count_3  0  65535  
BG2  tdp_ferrous_count_4  0  19771  
LM  tdp_ferrous_count_4  0  19771  
BG2  tdp_ferrous_count_5  0  4404  
LM  tdp_ferrous_count_5  0  4404  
BG2  tdp_ferrous_count_6  0  2465  
LM  tdp_ferrous_count_6  0  2465  
BG2  tdp_ferrous_count_7  0  1642  
LM  tdp_ferrous_count_7  0  1642  
BG2  tdp_ferrous_count_8  0  5185  
LM  tdp_ferrous_count_8  0  5185  
BG2  tdp_hydraulic_pressure  40  90  
LM  tdp_hydraulic_pressure  40  90  
BG2  tdp_nacelle_temp  -36  48  
LM  tdp_nacelle_temp  -36  48  
BG2  tdp_oil_condition  .  .  
LM  tdp_oil_condition  .  .  
BG2  tdp_operating_status  0  1  
LM  tdp_operating_status  0  85  
BG2  tdp_power_factor  -1  1  
LM  tdp_power_factor  -2  2  
BG2  tdp_state_fault  0  1379  
LM  tdp_state_fault  0  1907  
BG2  tdp_temp_gearbox_bearing  10  80  
LM  tdp_temp_gearbox_bearing  10  80  
BG2  tdp_temp_gearbox_oil  10  70  
LM  tdp_temp_gearbox_oil  10  70  
BG2  tdp_temp_main_bearing  -3  40  
LM  tdp_temp_main_bearing  -3  40  
LM  tdp_temp_gen_air_cooler  -10  75 
LM  tdp_temp_gen_bearing_de  -10  75 
LM  tdp_temp_gen_bearing_nde  -10  75 
LM  tdp_temp_gen_sttr_wndg_l1  -10  75 
LM  tdp_temp_gen_sttr_wndg_l2  -10  75
LM  tdp_temp_main_bearing  -10  75
LM  tdp_temp_main_box  -10  75
BG2  tdp_temp_gen_air_cooler  -10  75  
BG2  tdp_temp_gen_bearing_de  -10  75 
BG2  tdp_temp_gen_bearing_nde  -10  75 
BG2  tdp_temp_gen_sttr_wndg_l1  -10  75 
BG2  tdp_temp_gen_sttr_wndg_l2  -10  75 
BG2  tdp_temp_main_bearing  -10  75
BG2  tdp_temp_main_box  -10  75
BG2  tdp_turbine_power  -100  2000  
LM  tdp_turbine_power  -100  2000  
BG2  tdp_vibration_condition  .  .  
LM  tdp_vibration_condition  .  .  
BG2  tdp_wind_speed  0  35  
LM  tdp_wind_speed  0  35  
BG2  tdp_yaw_nacelle_position  0  360  
LM  tdp_yaw_nacelle_position  0  360  
BG2  tdp_gen_speed_plc  0  5000 
BG2  tdp_gen_speed  0  5000 
BG2  tdp_rotor_speed_plc  0  5000 
LM  tdp_gen_speed_plc  0  5000 
LM  tdp_gen_speed  0  5000 
LM  tdp_rotor_speed_plc  0  5000 
LM tdp_voltage_a 0 500 
LM tdp_voltage_b 0 500
LM tdp_voltage_c 0 500
BG2 tdp_voltage_a 0 500 
BG2 tdp_voltage_b 0 500
BG2 tdp_voltage_c 0 500
;
run;

%macro applyValidValues();
	data &l_tmpLib.._valid2;
		format stmt  $256. stmt1 stmt2 stmt3 stmt4 stmt5 $128.;
		set _valid1;
		
		if missing(LowestPossible)=1 and missing(HighestPossible)=1 then stmt='';
		else
		do;
			stmt1 = cats("if Unit_name ='",compress(unit_name),"'");
			
			if missing(LowestPossible)=0 and missing(HighestPossible)=0 then 
				stmt2 = catx(' ','and (',_Column_,'<',LowestPossible, 'or',_Column_,'>',HighestPossible,')');
			else if missing(LowestPossible)=0 and missing(HighestPossible)=1 then 
				stmt2 = catx(' ','and (',_Column_,'<',LowestPossible,')');
			else if missing(LowestPossible)=1 and missing(HighestPossible)=0 then 
				stmt2 = catx(' ','and (',_Column_,'>',HighestPossible,')');
			
			stmt3 = catx(' ','then do;');
			stmt4 = cats(_Column_,'=. ;');
			stmt5 = strip('InValidVal_count = sum(1, InValidVal_count); end;' );
			stmt = catx(' ', stmt1, stmt2, stmt3, stmt4, stmt5);
		end;
		drop  stmt1 stmt2 stmt3 stmt4 stmt5;
		if missing(LowestPossible)=0 or missing(HighestPossible)=0 then output;
	run;
	
	proc delete data=&l_tmpLib.._valid1;
	run;

	filename sascode temp;
	
	data _null_;
		file sascode;
		set &l_tmpLib.._valid2;
		put stmt;
	run;

	data &l_tgtLib..ML_ABT (compress = yes);
		set &l_tgtLib..ML_ABT_UNCORRECTED;
		
		%include sascode;
		InValidVal_count=max(0,InValidVal_count);
	run;

	filename sascode clear;
%mend applyValidValues;

/* Load final ML_ABT */
%applyValidValues();


/*************************/
/* Vaisala forecast data */
/*************************/

proc sql noprint;
	CREATE TABLE  &l_tmpLib.._ml_vaisala_forecast AS
	SELECT   CASE project
				WHEN "Buffalo Gap II" THEN "BG2"
				WHEN "Laurel Mountain" THEN "LM"
			 END AS unit_name
			,forecast_time
			,'variables'n AS variable
			,catx(' - ', translate(compbl(propcase('variables'n)),' ', '_'), unit) AS label
			,'values'n AS value
	FROM &l_srcLib..TARGET_VAISALA_FORECAST_DATA
	WHERE source EQ '3TIER Blend'
		AND project IN (&l_windFarmsFullNames)

	%if (&l_loadFromDttm NE ) %then
	%do;
		AND forecast_time GE "&l_loadFromDttm"dt
	%end;

	ORDER BY unit_name, forecast_time
	;
quit;

proc transpose data=&l_tmpLib.._ml_vaisala_forecast out=&l_tgtLib..ml_vaisala_forecast (drop=_NAME_ _LABEL_);
	by unit_name forecast_time;
	id variable;
	idlabel label;
	var value;
run;

proc sql noprint;
	CREATE INDEX unit_name_forecast_time ON &l_tgtLib..ml_vaisala_forecast (unit_name, forecast_time);
quit;


/********************************/
/* Delete, Sort and load to CAS */
/********************************/
options cashost="&cas_server" casport=&cas_port;
cas mySession sessopts=(timeout=1800 locale="en_US" metrics=true);
caslib _all_ assign;
cas _all_ list;
run;
cas listabout;
run;

%macro loadToCas(l_loadToCas);
	%if (&l_loadToCas EQ Y) %then
	%do;
		/* Drop CAS tables if they exist */
		%if (%sysfunc(exist(&l_casLib..ML_ABT))) %then
		%do;
			proc sql noprint;
				DROP TABLE &l_casLib..ML_ABT;
			quit;
		%end;

		%if (%sysfunc(exist(&l_casLib..ML_ABT_UNCORRECTED))) %then
		%do;
			proc sql noprint;
				DROP TABLE &l_casLib..ML_ABT_UNCORRECTED;
			quit;
		%end;

		%if (%sysfunc(exist(&l_casLib..ML_VAISALA_FORECAST))) %then
		%do;
			proc sql noprint;
				DROP TABLE &l_casLib..ML_VAISALA_FORECAST;
			quit;
		%end;

		/* Load final tables to CAS */
		proc sql noprint;
			CREATE TABLE &l_casLib..ML_ABT (promote=yes compress=yes) AS
			SELECT *
			FROM &l_tgtLib..ML_ABT
			ORDER BY timestamp, unit, unit_name;

			CREATE TABLE &l_casLib..ML_ABT_UNCORRECTED (promote=yes compress=yes) AS
			SELECT *
			FROM &l_tgtLib..ML_ABT_UNCORRECTED
			ORDER BY timestamp, unit, unit_name;

			CREATE TABLE &l_casLib..ML_VAISALA_FORECAST (promote=yes) AS
			SELECT *
			FROM &l_tgtLib..ML_VAISALA_FORECAST
			;
		quit;

		/* Save permanent sashdat tables for reload */

		/*
		proc casutil;
		   save incaslib="&l_casLib" outcaslib="&l_casLib"
		   casdata="ML_ABT" casout="ML_ABT" replace;
		run;

		proc casutil;
		   save incaslib="&l_casLib" outcaslib="&l_casLib"
		   casdata="ML_ABT_UNCORRECTED" casout="ML_ABT_UNCORRECTED" replace;
		run;

		proc casutil;
		   save incaslib="&l_casLib" outcaslib="&l_casLib"
		   casdata="ML_VAISALA_FORECAST" casout="ML_VAISALA_FORECAST" replace;
		run;
		*/
	%end;
%mend loadToCas;

%loadToCas(&l_loadToCas)


/**********************/
/* Delete work tables */
/**********************/
