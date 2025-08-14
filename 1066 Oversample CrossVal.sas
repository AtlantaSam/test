%Let Data1 = casuser.ads_mbx2; 
*%Let Data1 = canlytcs.ads_mbx2; 
%let interval_inputs = tdp_air: tdp_blade: tdp_gen: tdp_hyd: tdp_temp: tdp_wind: tdp_yaw: ;
%let interval_inputs = /*tdp_air_temp_Max tdp_air_temp_Mean tdp_air_temp_StdDev*/ 
	tdp_gen_speed_Max tdp_gen_speed_Mean tdp_gen_speed_StdDev 
	tdp_hydraulic_pressure_Max tdp_hydraulic_pressure_Mean tdp_hydraulic_pressure_StdDev 
	tdp_temp_gen_air_cooler_Max tdp_temp_gen_air_cooler_Mean tdp_temp_gen_air_cooler_StdDev 
	tdp_temp_gen_bearing_de_Max tdp_temp_gen_bearing_de_Mean tdp_temp_gen_bearing_de_StdDev 
	tdp_temp_gen_bearing_nd_StdDev tdp_temp_gen_bearing_nde_Max tdp_temp_gen_bearing_nde_Mean 
	tdp_temp_main_bearing_Max tdp_temp_main_bearing_Mean tdp_temp_main_bearing_StdDev 
	tdp_wind_speed_Max tdp_wind_speed_Mean tdp_wind_speed_StdDev 
	tdp_yaw_nacelle_positio_StdDev 
	tdp_yaw_nacelle_position_Max tdp_yaw_nacelle_position_Mean ;

%let target = targetMB2;

%global TimeID;	
ods trace off;
%Let saswork = %sysfunc(getoption(work));
options nosymbolgen;

proc contents data=&Data1.(keep=&interval_inputs.) out=_varlist(keep=name) noprint;
run;
Data _null_; set _varlist;
put name;
run;

%Macro ASample();
	ods exclude all;
	option  nonotes nodate;
/* 	ods html close ; */
	Data _null_;
		Call symput('TimeID', catx('_',put(datetime(),datetime24.), round(rand('uniform')*10000)));
	run;
	data casuser._a; set &Data1.;
	_ObsIDnum_+1;
	run;
	proc partition data=casuser._a samppctevt=100 eventprop=0.25
	   event="1" seed=10 nthreads=1;
	   by &Target.;
	   output out=casuser._b copyvars=(_ObsIDnum_)
	          freqname=_freq2;
	display / excludeall;
	run;
	Data casuser._sample; 
		format _GrpTime_ $32.;
		merge casuser._a(In=In1) casuser._b(In=In2 drop=_freq2);
		by _ObsIDnum_;
		_GrpTime_ = "&TimeID.";
		If In2;
		drop _ObsIDnum_;
	run;
	proc delete data=casuser._a casuser._b;
	run;
	proc forest data=casuser._sample ntrees=100 numbin=20 minleafsize=5;
		input &Interval_inputs. / level=interval;
		target &target / level=nominal;
		code file="&saswork./forest&ii..sas";
		ods output FitStatistics=_FitStat0_ VariableImportance=_VarImp0_;
	run;

	data _FitStat0_&ii.; 
		format _GrpTime_ $32.;
		set _FitStat0_;
		_GrpTime_ = "&TimeID.";
	run;
	data _VarImp0_&ii.; 
		format _GrpTime_ $32.;
		set _VarImp0_;
		_GrpTime_ = "&TimeID.";
	run;
	proc delete data=_FitStat0_ _VarImp0_;
	run;
	proc gradboost data=casuser._sample ;
		input &Interval_inputs. / level=interval;
		target &target / level=nominal;
		code file="&saswork./gb&ii..sas";
		ods output FitStatistics=_FitStat0_ VariableImportance=_VarImp0_;
	run;
	data _VarImpGrad_&ii.; 
		format _GrpTime_ $32.;
		set _VarImp0_;
		_GrpTime_ = "&TimeID.";
	run;
	proc delete data=_FitStat0_ _VarImp0_;
	run;
	ods exclude none; 
	option notes;
/* 	ods html ; */
%Mend;
%Macro ManyIters(Niter=6);
	/* %Let Niter=3; */
	%Do ii = 1 %To &NIter;
		%ASample();
		%put Iteration (&ii.) {&TimeId.};
		%If &ii.=1 %then %do;
			Data casuser.AllData; set casuser._sample;
			run;
		%end;
		%Else %Do;
			Data casuser.AllData; set casuser.AllData casuser._sample;
			run;		
		%end;
		proc delete data=casuser._sample; 
		run;
	%End;
	Proc summary data=casuser.alldata nway;
		class _GrpTime_;
		var &Target.;
		output out=_sum(drop=_type_ _freq_) n=nobs_in_sample mean=Event_Rate sum=Num_Events;
	run; 
	title2 'Data subsets created';
	proc freq data=_sum;
		format Event_Rate percent8.3;
		table nobs_in_sample*Event_Rate*Num_Events / list nopercent nocum;
	run;
	proc delete data=_sum;
	run;

	Data _all_VarImp; set _VarImp0_:;
		InForest=1;
	run;
	proc freq data=_all_VarImp noprint;
		table Variable*_GrpTime_ / out=_misscomb(drop=percent where=(count=0)) sparse;
	run;
	Data all_VarImpForest; set _all_VarImp _misscomb(drop=count In=In2); 
		array setzero {*} Importance RelativeImportance InForest;
		do ii = 1 to dim(setzero); drop ii;
			if In2 and missing(setzero(ii)) then setzero(ii)=0;
		end;
	run;
	proc sql ;
		create table _tmp as select *, mean(Importance) as meanImp
			from all_VarImpForest group by Variable order by meanImp desc, Variable;
	quit;
/* 	Proc sgplot data=all_VarImpForest; */
/* 		vbox Importance /group=Variable grouporder=data; */
/* 	run; */
	proc summary data=all_VarImpForest nway;
		class Variable;
		var Importance RelativeImportance;
		output out=_sum0(drop=_type_ _freq_) 
			min(Importance RelativeImportance)= 
			q1(Importance RelativeImportance)= 
			median(Importance RelativeImportance)= 
			mean(Importance RelativeImportance InForest)=
			q3(Importance RelativeImportance)= 
			max(Importance RelativeImportance)= 
		/ autoname;
	run;
	proc sort data=_sum0(rename=(InForest_mean=InForestPct));
		by descending Importance_Mean;
	run;

	title2 'Importance';
	proc print data=_sum0(keep=Variable Importance_: InForestPct) noobs;
	label Importance_Min='Min' 
		Importance_Q1='Q1' 
		Importance_Median='Median' 
		Importance_Mean='Mean' 
		Importance_Q3='Q3' 
		Importance_Max = 'Max'
	;
	format InForestPct percent8.2;
	var Variable InForestPct Importance_:  ;
	run;
/* 	title2 'Relative Importance'; */
/* 	proc print data=_sum0(keep=Variable RelativeImportance_:  InForestPct) noobs; */
/* 	label RelativeImportance_Min='Min'  */
/* 		RelativeImportance_Q1='Q1'  */
/* 		RelativeImportance_Median='Median'  */
/* 		RelativeImportance_Mean='Mean'  */
/* 		RelativeImportance_Q3='Q3'  */
/* 		RelativeImportance_Max = 'Max' */
/* 	;	 */
/* 	format InForestPct percent8.2; */
/* 	var Variable InForestPct RelativeImportance_:  ; */
/* 	run; */
	proc sort data=_sum0(drop=Importance_: RelativeImportance_Max RelativeImportance_Min  
		rename=(RelativeImportance_Q1= Forest_Q1 
			RelativeImportance_Median=Forest_Median 
			RelativeImportance_Mean=Forest_Mean 
			RelativeImportance_Q3=Forest_Q3
		))
		out= _Forestsum;
			by variable;
	run;
	proc delete data=_sum0 _all_VarImp _tmp;
	run;
	Data all_FitStat; set _FitStat0_:;
	run;
	proc datasets lib=work nolist;
		delete _FitStat0_: _VarImp0_:;
	run;

	Data _all_VarImpGrad; set _VarImpGrad_:;
		InGradBoost=1;
	run;
	proc freq data=_all_VarImpGrad noprint;
		table Variable*_GrpTime_ / out=_misscomb(drop=percent where=(count=0)) sparse;
	run;
	Data all_VarImpGrad; set _all_VarImpGrad _misscomb(drop=count In=In2); 
		array setzero {*} Importance RelativeImportance InGradBoost;
		do ii = 1 to dim(setzero); drop ii;
			if In2 and missing(setzero(ii)) then setzero(ii)=0;
		end;
	run;
	proc datasets lib=work nolist;
		delete _all_VarImpGrad  _misscomb _VarImpGrad_:;
	run;
	proc summary data=all_VarImpGrad nway;
		class Variable;
		var Importance RelativeImportance;
		output out=_sum0(drop=_type_ _freq_) 
			min(Importance RelativeImportance)= 
			q1(Importance RelativeImportance)= 
			median(Importance RelativeImportance)= 
			mean(Importance RelativeImportance InGradBoost)=
			q3(Importance RelativeImportance)= 
			max(Importance RelativeImportance)= 
		/ autoname;
	run;
	proc sort data=_sum0(rename=(InGradBoost_mean=InGradBoostPct));
		by descending Importance_Mean;
	run;

	title2 'Importance';
	proc print data=_sum0(keep=Variable Importance_: InGradBoostPct) noobs;
	label Importance_Min='Min' 
		Importance_Q1='Q1' 
		Importance_Median='Median' 
		Importance_Mean='Mean' 
		Importance_Q3='Q3' 
		Importance_Max = 'Max'
	;
	format InGradBoostPct percent8.2;
	var Variable InGradBoostPct Importance_:  ;
	run;
/* 	title2 'Relative Importance'; */
/* 	proc print data=_sum0(keep=Variable RelativeImportance_:  InGradBoostPct) noobs; */
/* 	label RelativeImportance_Min='Min'  */
/* 		RelativeImportance_Q1='Q1'  */
/* 		RelativeImportance_Median='Median'  */
/* 		RelativeImportance_Mean='Mean'  */
/* 		RelativeImportance_Q3='Q3'  */
/* 		RelativeImportance_Max = 'Max' */
/* 	;	 */
/* 	format InGradBoostPct percent8.2; */
/* 	var Variable InGradBoostPct RelativeImportance_:  ; */
/* 	run; */
	proc sort data=_sum0(drop=Importance_: RelativeImportance_Max RelativeImportance_Min 
		rename=(RelativeImportance_Q1= GradBoost_Q1 
			RelativeImportance_Median=GradBoost_Median 
			RelativeImportance_Mean=GradBoost_Mean 
			RelativeImportance_Q3=GradBoost_Q3
		))
		out= _Gradboostsum;
			by variable;
	run;
	proc delete data=_sum0 _all_VarImp _tmp;
	run;
	proc datasets lib=work nolist;
		delete  _VarImp0_:;
	run;
	Data All_sum; merge _Gradboostsum(In=In1) _Forestsum(In=In2);
		By Variable;
		array nums {*} _numeric_;
		do ii = 1 to dim(nums); drop ii;
			if missing(nums(ii)) then nums(ii)=0;
		end;
		If In1 or In2;
	run;
	proc cluster data=all_sum method=ward ccc pseudo outtree=_tree noprint;
		var _numeric_;
		copy variable GradBoost_Mean Forest_Mean; 
	run;
	proc tree nclusters=5 out=_out noprint;
		copy Variable GradBoost_Mean Forest_Mean;
	run;
	proc sort data=_out ;
		by descending Forest_mean;
	run;
	proc print data=_out(drop=_NAME_ CLUSNAME) noobs;
	run;
	proc delete data=_Gradboostsum _Forestsum _tree ;
	run;

	title2;
%Mend;

%ManyIters(Niter=50);


%Macro HistEvent(DataIn=&Data1., varnow = , Eventnow=&Target.);
/*
%let DataIn=&Data1.; %let varnow=tdp_air_temp_Max; %Let Eventnow=&Target.;
*/
/*	proc sql noprint;
		select count(*), min(&varnow.), max(&varnow.)
		into :nobsnow, :MinValNow, :MaxValNow
		from &DataIn. where missing(&varnow.)=0;
	quit;
	Data _null_;
		Nbin=round(max(20,min(sqrt(&nobsnow.),50)),1);
		BinWidth = 1.005*(&MaxValNow. - &MinValNow.)/NBin;
		call symput('nbinNow', strip(nbin));
		call symput('BinWidthNow', strip(BinWidth));
	run;
	%Put nobs:&nobsnow. -> &nbinNow. bins, width {&BinWidthNow.};
	Data _Grouped; set &DataIn.;
		_Grp_ = max(1,floor((&Varnow.-&MinValNow.)/&BinWidthNow.));
	run;
*/
	proc sgplot data=&DataIn. (where = (missing(&varnow.)=0)) ;
		label &varnow.="&varnow.";
		histogram &Varnow. / group=&EventNow. scale=count;
		yaxis grid  gridattrs=(thickness=1.5 pattern=solid)
			type=linear /*type=log logbase=10*/ 
			minorcount =4 minorgrid minorgridattrs=(thickness=.5 pattern=dot color=gray)
;
	run;	
%mend;
%Let nvar=6;
Data _null_;
set _out(obs=&nvar.);
call execute(cats('%HistEvent(varnow =', Variable , ');'));
run;
proc sql noprint;
	select variable into :topvars separated by ' ' from _out(obs=&nvar.);
quit;
proc sgscatter data=&Data1.;
	matrix &topvars. / group=&target.;
run;



data casuser.VarSelect_MB2b (promote=yes); set work._out;
run;

