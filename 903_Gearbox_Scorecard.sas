
data temp;
   merge casuser.tmpScoreData_GBX2_BG2 (rename=(em_eventprobability=scoreGBX2))
         casuser.tmpScoreData_GBX1_BG2 (rename=(em_eventprobability=scoreGBX1))
         casuser.tmpScoreData_GBX0_BG2 (rename=(em_eventprobability=scoreGBX0));
   by tdp_Asset_Name;
   keep tdp_asset_name target: score:;
run;

proc means data=work.temp; var Score:; run;

data eval00;
   set temp;
   if scoreGBX0 ge .10 then evalGBX0=3;
   if scoreGBX1 ge .20 then evalGBX1=3;
   if scoreGBX2 ge .20 then evalGBX2=3;
run;

/* Gearbox0 */
%macro meanSco(in,out,st);
%Global &st;
proc means data=eval00 nway noprint;
   where &in. ne 3;
   var scoreGBX0;
   output out=&out. mean=mean;
run;
data _null_;
   set &out.;
   call symput("&st.",mean);
run;
%mend;
%meanSco(evalGBX0,StatsEval0,meanScore0);
%meanSco(evalGBX1,StatsEval1,meanScore1);
%meanSco(evalGBX2,StatsEval2,meanScore2);


data eval01;
   set eval00;
   if evalGBX0 ne 3 then do;
      if scoreGBX0 > &meanScore0. then EvalGBX0=2;
      else EvalGBX0=1;
   end;
   if evalGBX1 ne 3 then do;
      if scoreGBX1 ge &meanScore1. then EvalGBX1=2;
      else EvalGBX1=1;
   end;
   if evalGBX2 ne 3 then do;
      if scoreGBX2 ge &meanScore2. then EvalGBX2=2;
      else EvalGBX2=1;
   end;
run;
proc freq; table EvalGBX0; run;
proc freq; table EvalGBX1; run;
proc freq; table EvalGBX2; run;

proc casutil; droptable incaslib='casuser' casdata='GearBoxScorecard' quiet;
run;
data casuser.GearBoxScorecard (promote=yes);
   retain tdp_asset_name scoreGBX2 evalGBX2 targetGB2 scoreGBX1 evalGBX1 targetGB1 scoreGBX0 evalGBX0 targetGB0 targetX;
   set eval01;
run;
proc sort; by tdp_asset_name; run;

proc casutil; droptable incaslib='public' casdata='GearBoxScorecard' quiet;
run;

options VALIDMEMNAME=EXTEND VALIDVARNAME=ANY;
data public.GearBoxScorecard (promote=yes);
   set casuser.Gearboxscorecard;


   /*------------------------------------------
   Generated SAS Scoring Code
     Date             : 26Jul2021:17:02:33
     Locale           : en_US
     Model Type       : Cluster
     Interval variable: scoreGBX1(Score (1 week))
     Interval variable: scoreGBX2(Score (2 weeks))
     Interval variable: scoreGBX0(Score (in week))
     ------------------------------------------*/


   length _WARN_ $4;
   label _WARN_ = 'Warnings';
   label _CLUSTER_ID_ = 'Cluster ID';
   label _DISTANCE_ = 'Distance to Centroid';

   _i_ = 0;
   _j_ = 0;
   _k_ = 0;
   _l_ = 0;
   _dist_ = 0;
   _minDist_ = 0;
   _found_ = 0;
   _unknown_ = 0;
   _unknownflag_ = 0;
   _intMindist2cntr_ = 0;
   _missingflag4Int_ = 0;
   _numberOfIntVars_ = 3;
   _minDistInt_ = 0;
   label _STANDARDIZED_DISTANCE_ = 'Standardized Distance to Centroid';

   drop _i_;
   drop _j_;
   drop _k_;
   drop _l_;
   drop _dist_;
   drop _minDist_;
   drop _minDistInt_;
   drop _unknown_;
   drop _unknownflag_;
   drop _found_;
   drop _intMindist2cntr_;
   drop _missingflag4Int_;
   drop _numberOfIntVars_;
   drop _minDistInt_;

   array _intVals_666{3} _temporary_;
   array _intStdVals_666{3} _temporary_;
   array _intVars_666[3] _temporary_;
   _intVars_666[1] =
   scoreGBX1;
   _intVars_666[2] =
   scoreGBX2;
   _intVars_666[3] =
   scoreGBX0;
   array _cntrcoordsInt_666{5,3} _temporary_ (
   0.0355654761904
   0.1020649092971
   0.0316936143788
   0.2336631393298
   0.2492151675485
   0.7938134326748
    0.016189484127
   0.0257965167549
   0.0222823848435
   0.1874688644689
   0.1994206349206
   0.0442253473471
   0.1446264720942
   0.0511003584229
   0.0347261876821
   );
   array _stdcntrcoordsInt_666 {5,3} _temporary_ (
   -0.448878251611
    0.374505725741
   -0.226321301404
    1.919914540126
    2.256038924795
    3.872535003475
    -0.68057058763
   -0.600698220972
   -0.276937066263
    1.367537174457
    1.619342344143
   -0.158922748768
    0.855240620174
   -0.277151264767
   -0.210011422162
   );
   array _stdscaleInt_666 {3} _temporary_ (
   0.0836281095714
    0.078207633182
   0.1859347490149
   );
   array _stdcenterInt_666 {3} _temporary_ (
   0.0731043158004
   0.0727757028737
   0.0737746087521
   );

   *************** check missing interval value ******************;
   _missingflag4Int_ = 0;
   do _i_ = 1 to _numberOfIntVars_ until(_missingflag4Int_);
      if missing( _intVars_666[_i_] ) then
         _missingflag4Int_ = 1;
   end;

   if (_missingflag4Int_ = 1) then
      substr(_WARN_, 1, 1) = 'M';
   ********** prepare interval variable values *********;
   do _i_ = 1 to _numberOfIntVars_;
      if missing (_intVars_666[_i_] ) then do;
         _intVals_666[_i_] = .;
         _intStdVals_666[_i_] = .;
      end; else do;
         if missing (_stdscaleInt_666[_i_] ) then do;
            _intStdVals_666[_i_] = ( _intVars_666[_i_] -  _stdcenterInt_666[_i_]);
         end; else do;
            _intStdVals_666[_i_] = ( _intVars_666[_i_] -  _stdcenterInt_666[_i_])
                  /  _stdscaleInt_666[_i_];
         end;
         _intVals_666[_i_] = _intVars_666[_i_];
      end;
   end;
   ****************** find the closest cluster ******************;
   if _missingflag4Int_ > 0  then
   do;
      _CLUSTER_ID_ = .;
      _DISTANCE_ = .;
      _minDistInt_ = .;
      _STANDARDIZED_DISTANCE_ = .;
   end;
   else
   do;
      _CLUSTER_ID_ = .;
      _minDist_ = 8.988465674E307;
      do _i_=1 to               5;
         _intMindist2cntr_ = 0;
         do _j_=1 to               3;
            _dist_ = _intStdVals_666{_j_} - _stdcntrcoordsInt_666{_i_,_j_};
            _dist_ = _dist_ ** 2;
            _intMindist2cntr_ = _intMindist2cntr_ + _dist_;
         end;
         _intMindist2cntr_ = _intMindist2cntr_ **              0.5;
         if( _minDist_  > _intMindist2cntr_) then do;
            _CLUSTER_ID_ = _i_;
            _minDist_ = _intMindist2cntr_;
         end;
         _STANDARDIZED_DISTANCE_ = _minDist_;
      end;
      _DISTANCE_ = 8.988465674E307;
      _i_ = _CLUSTER_ID_;
      _intMindist2cntr_ = 0;
      do _j_=1 to               3;
         _dist_ = _intVals_666{_j_} - _cntrcoordsInt_666{_i_,_j_};
         _dist_ = _dist_ ** 2;
         _intMindist2cntr_ = _intMindist2cntr_ + _dist_;
      end;
      _intMindist2cntr_ = _intMindist2cntr_ **              0.5;
      _DISTANCE_ = _intMindist2cntr_;
   end;

if (MISSING('_CLUSTER_ID_'n))then _CLUSTER_ID_ = -1;
   /*------------------------------------------*/
   /*_VA_DROP*/ drop '_CLUSTER_ID_'n '_DISTANCE_'n '_WARN_'n '_STANDARDIZED_DISTANCE_'n;
      '_CLUSTER_ID__666'n='_CLUSTER_ID_'n;
'_DISTANCE__666'n='_DISTANCE_'n;
'_WARN__666'n='_WARN_'n;
'_STANDARDIZED_DISTANCE__666'n='_STANDARDIZED_DISTANCE_'n;
   /*------------------------------------------*/

ScoreCluster=_Cluster_ID_;

run;

proc freq data=public.GearBoxScorecard; 
   table ScoreCluster ScoreCluster*targetGB0; 
run;


