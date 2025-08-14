/************************************************************************/
/* This snippet showcases a sample Machine Learning workflow for        */
/* supervised learning using SAMPLEML.HMEQ data set. The steps include:  */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Load data set into CAS                                        */
/*     b) Explore                                                       */
/*     c) Partition                                                     */
/*     d) Impute                                                        */
/*     e) Identify variables that explain variance                      */
/*                                                                      */
/* (2) PERFORM SUPERVISED LEARNING                                      */
/*     a) Fit model using random forest                                 */
/*                                                                      */
/* (3) EVALUATE AND IMPLEMENT                                           */
/*     a) Score the data                                                */
/*     b) Assess model performance                                      */
/*     c) Generate ROC and Lift charts                                  */
/************************************************************************/


/************************************************************************/
/* Define the macro variables for later use in the program              */
/************************************************************************/
/* Specify a folder path to write the temporary output files */
%let outdir = &_SASWORKINGDIR; 

/* Create a CAS engine libref to save the output data sets */
%let caslibname = mycas;     
libname &caslibname cas caslib=casuser;

/* Specify the data set names */
*%let sasdata          = casuser.ads_mbx2;                     
%let casdata          = &caslibname..ads_mbx2;            
%let partitioned_data = &caslibname.._part;  

/* Specify the data set inputs and target */
*%let class_inputs    = tdp_asset_name;
%let interval_inputs = tdp_air: tdp_blade: tdp_gen: tdp_hyd: tdp_temp: tdp_wind: tdp_yaw: ; 
%let target          = targetMB2;

/************************************************************************/
/* Load data into CAS                                                   */
/************************************************************************/
/* data &casdata; */
/* 	set &casdata; */
/* run; */

/************************************************************************/
/* Explore the data and look for missing value                          */
/************************************************************************/
proc cardinality data=&casdata outcard=&caslibname..data_card;
run;

proc print data=&caslibname..data_card(where=(_nmiss_>0));
        title "Data Summary";
run;

data data_missing;
	set &caslibname..data_card
        (where=(_nmiss_>0) keep=_varname_ _nmiss_ _nobs_);
	_percentmiss_ = (_nmiss_/_nobs_)*100;
	label _percentmiss_ = 'Percent Missing';
run;

proc sgplot data=data_missing;
        title "Percentage of Missing Values";
	vbar _varname_ / response=_percentmiss_ 
                         datalabel categoryorder=respdesc;
run;
title;

/************************************************************************/
/* Partition the data into training and validation                      */
/************************************************************************/
proc partition data=&casdata partition samppct=50;
	by &target;
	output out=&partitioned_data copyvars=(_ALL_);
run;

/************************************************************************/
/* Impute missing values                                                */
/************************************************************************/
proc varimpute data=&partitioned_data;
	input tdp_hydraulic_pressure_: tdp_temp_main_bearing_: /ctech=median;
	code file="&outdir./impute1.sas";
	output out=&caslibname.._prepped copyvars=(_ALL_);
run;
    
/************************************************************************/
/* Identify variables that explain variance in the target               */
/************************************************************************/
/* Discriminant analysis for class target */
proc varreduce data=&caslibname.._prepped technique=discriminantanalysis;  
	class &target;
	reduce supervised &target=&interval_inputs. /
            maxeffects=8;
	ods output selectionsummary=summary;	     
run;

data out_iter (keep=Iteration VarExp Base Increment Parameter);
	set summary;
	Increment=dif(VarExp);
	if Increment=. then Increment=0;
	Base=VarExp - Increment;
run;

proc transpose data=out_iter out=out_iter_trans;
	by Iteration VarExp Parameter;
run;

proc sort data=out_iter_trans;
	label _NAME_='Group';
	by _NAME_;
run;

/* Variance explained by Iteration plot */
proc sgplot data=out_iter_trans;
	title "Variance Explained by Iteration";
	yaxis label="Variance Explained";
	vbar Iteration / response=COL1 group=_NAME_;
run;

/************************************************************************/
/* Capture variables identified with PROC VARREDUCE                     */
/************************************************************************/
proc sql;
   select distinct Variable
   into :VarSet separated by ' '
   from work.summary;
quit;


/************************************************************************/
/* Build a predictive model using Random Forest                         */
/************************************************************************/
proc forest data=&caslibname.._prepped ntrees=50 numbin=20 minleafsize=5;
    *input &interval_inputs. / level = interval;
    input &VarSet. / level=interval;
    *input &class_inputs.    / level = nominal;
    target &target          / level = nominal;
    partition rolevar=_partind_(train='1' validate='0');
    code file="&outdir./forest.sas";
    ods output FitStatistics=fitstats;
run;

/************************************************************************/
/* Score the data using the generated model                             */
/************************************************************************/
data &caslibname.._scored_forest;
	set &caslibname.._prepped;
	%include "&outdir./forest.sas";
run;

/* create data set from forest stats output */
data fitstats;
	set fitstats;
	label Trees     = 'Number of Trees';
	label MiscTrain   = 'Training';
	label MiscValid = 'Validation';
run;

/* plot misclassification as function of number of trees */
proc sgplot data=fitstats;
	title "Training vs Validation";
	series x=Trees y=MiscTrain;
	series x=Trees y=MiscValid/
           lineattrs=(pattern=shortdash thickness=2);
	yaxis label='Misclassification Rate';
run;
title;

/************************************************************************/
/* Assess model performance                                             */
/************************************************************************/
proc assess data=&caslibname.._scored_forest;
	input p_targetMB21;
	target &target / level=nominal event='1';
	fitstat pvar=p_targetMB20 / pevent='0';
	by _partind_;
	ods output fitstat  = forest_fitstat 
	           rocinfo  = forest_rocinfo 
	           liftinfo = forest_liftinfo;
run;

/************************************************************************/
/* Analyze model using ROC and Lift charts                              */
/************************************************************************/
ods graphics on;
proc format;
	value partindlbl 0 = 'Validation' 1 = 'Training';
run;
       
/* Construct a ROC chart */
proc sgplot data=forest_rocinfo aspect=1;
	title "ROC Curve";
	xaxis label="False positive rate" values=(0 to 1 by 0.1);
	yaxis label="True positive rate"  values=(0 to 1 by 0.1);
	lineparm x=0 y=0 slope=1 / transparency=.7 LINEATTRS=(Pattern=34);
	series x=fpr y=sensitivity /group=_partind_;
	format _partind_ partindlbl.;
run;
      
/* Construct a Lift chart */
proc sgplot data=forest_liftinfo; 
	title "Lift Chart";
	xaxis label="Population Percentage";
	yaxis label="Lift";
	series x=depth y=lift / 
	       group=_partind_ markers markerattrs=(symbol=circlefilled);
	format _partind_ partindlbl.;
run;

title;
ods graphics off;


***********************************************************************;


/************************************************************************/
/* Random Forest                                                        */
/************************************************************************/
ods graphics on;
proc forest data=&caslibname..ads_mbx2 ntrees=50 numbin=20 minleafsize=5;
    input &Interval_inputs.  / level=interval;
    target &target  / level = nominal;
    code file="&outdir./forest.sas";
    ods output FitStatistics=FitStatsRandFor;
run;
data casuser._scored_forest;
	set &caslibname..ads_mbx2;
	%include "&outdir./forest.sas";
run;
proc assess data=casuser._scored_forest;;
	input p_targetMB21;
	target &target / level=nominal event='1';
	fitstat pvar=p_targetMB20 / pevent='0';
	ods output fitstat  = forest_fitstat 
	           rocinfo  = forest_rocinfo 
	           liftinfo = forest_liftinfo;
run;



%let xlabel=False Positive Fraction;
%let ylabel=True Positive Fraction;
proc logistic data=&caslibname..ads_mbx2 plots(only)=roc;
   class targetMB2;
   model targetMB2 (event='1') = tdp_temp_main_bearing_stddev tdp_air_temp_mean tdp_yaw_nacelle_position_mean;
   id tdp_asset_name;
run;
%symdel xlabel ylabel;
     
/* Construct a ROC chart */
proc sgplot data=forest_rocinfo aspect=1;
	title "ROC Curve";
	xaxis label="False positive rate" values=(0 to 1 by 0.1);
	yaxis label="True positive rate"  values=(0 to 1 by 0.1);
	lineparm x=0 y=0 slope=1 / transparency=.7 LINEATTRS=(Pattern=34);
	series x=fpr y=sensitivity;
	format _partind_ partindlbl.;
run;
/* Construct a Lift chart */
proc sgplot data=forest_liftinfo; 
	title "Lift Chart";
	xaxis label="Population Percentage";
	yaxis label="Lift";
	series x=depth y=lift / 
	       markers markerattrs=(symbol=circlefilled);
run;

title;
ods graphics off;

proc gradboost data=&caslibname..ads_mbx2 outmodel=casuser.gradboost_mbx2 seed=12345;
   input &Interval_inputs.   / level=interval;
   target &target   / level = nominal;
   code file="&outdir./GradBoost.sas";
   output out=casuser.scored_GradBoost;
   ods output FitStatistics=FitStatsGradBoost;
run;
data casuser._scored_GradBoost;
	set &caslibname..ads_mbx2;
	%include "&outdir./GradBoost.sas";
run;
proc assess data=casuser._scored_GradBoost;
	input p_targetMB21;
	target &target / level=nominal event='1';
	fitstat pvar=p_targetMB20 / pevent='0';
	ods output fitstat  = GradBoost_fitstat 
	           rocinfo  = GradBoost_rocinfo 
	           liftinfo = GradBoost_liftinfo;
run;
   