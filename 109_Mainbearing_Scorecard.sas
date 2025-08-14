
data temp;
   merge casuser.scoreMB0 (keep=tdp_asset_name scoreMB0 evalMB0 targetMB0)
         casuser.scoreMB1 (keep=tdp_asset_name scoreMB1 evalMB1 targetMB1)
         casuser.scoreMB2 (keep=tdp_asset_name scoreMB2 evalMB2 targetMB2);
   by tdp_Asset_Name;
run;

proc casutil;
   droptable incaslib='casuser' casdata='MainBearingScorecard' quiet;
run;

data casuser.MainbearingScorecard (promote=yes);
   *retain tdp_asset_name scoreGBX2 scoreGBX1 scoreGBX0 targetX;
   set temp;
run;
proc sort; by tdp_asset_name; run;

proc casutil;
   droptable incaslib='public' casdata='MainBearingScorecard' quiet;
run;

options VALIDMEMNAME=EXTEND VALIDVARNAME=ANY;
data public.MainbearingScorecard (promote=yes);
   set casuser.MainbearingScorecard;


   /*------------------------------------------
   Generated SAS Scoring Code
     Date             : 26Jul2021:17:46:14
     Locale           : en_US
     Model Type       : Cluster
     Interval variable: ScoreMB0(Score (in week))
     Interval variable: scoreMB1(Score (1 week))
     Interval variable: scoreMB2(Score (2 weeks))
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

   array _intVals_641{3} _temporary_;
   array _intStdVals_641{3} _temporary_;
   array _intVars_641[3] _temporary_;
   _intVars_641[1] =
   ScoreMB0;
   _intVars_641[2] =
   scoreMB1;
   _intVars_641[3] =
   scoreMB2;
   array _cntrcoordsInt_641{5,3} _temporary_ (
   0.0092302268847
   0.1004319193996
   0.0165691470276
   0.0065021001536
   0.0805242587049
   0.0116000056682
   0.0281146785563
   0.1260258288841
    0.020343849811
   0.5675089965383
   0.1339245937055
   0.3459492753863
   0.0082756673001
   0.1052531056775
   0.3421235141582
   );
   array _stdcntrcoordsInt_641 {5,3} _temporary_ (
   -0.192906500964
    0.078376711853
   -0.182478130241
   -0.218154243487
   -1.026053859579
   -0.239512809781
   -0.018138310011
    1.498267100304
   -0.139152946262
    4.973744472904
    1.936472145042
    3.598072413435
     -0.2017405754
    0.345844878881
    3.554161192187
   );
   array _stdscaleInt_641 {3} _temporary_ (
   0.1080542836118
   0.0180252713115
   0.0871249106588
   );
   array _stdcenterInt_641 {3} _temporary_ (
   0.0300746006504
    0.099019157904
    0.032467537822
   );

   *************** check missing interval value ******************;
   _missingflag4Int_ = 0;
   do _i_ = 1 to _numberOfIntVars_ until(_missingflag4Int_);
      if missing( _intVars_641[_i_] ) then
         _missingflag4Int_ = 1;
   end;

   if (_missingflag4Int_ = 1) then
      substr(_WARN_, 1, 1) = 'M';
   ********** prepare interval variable values *********;
   do _i_ = 1 to _numberOfIntVars_;
      if missing (_intVars_641[_i_] ) then do;
         _intVals_641[_i_] = .;
         _intStdVals_641[_i_] = .;
      end; else do;
         if missing (_stdscaleInt_641[_i_] ) then do;
            _intStdVals_641[_i_] = ( _intVars_641[_i_] -  _stdcenterInt_641[_i_]);
         end; else do;
            _intStdVals_641[_i_] = ( _intVars_641[_i_] -  _stdcenterInt_641[_i_])
                  /  _stdscaleInt_641[_i_];
         end;
         _intVals_641[_i_] = _intVars_641[_i_];
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
            _dist_ = _intStdVals_641{_j_} - _stdcntrcoordsInt_641{_i_,_j_};
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
         _dist_ = _intVals_641{_j_} - _cntrcoordsInt_641{_i_,_j_};
         _dist_ = _dist_ ** 2;
         _intMindist2cntr_ = _intMindist2cntr_ + _dist_;
      end;
      _intMindist2cntr_ = _intMindist2cntr_ **              0.5;
      _DISTANCE_ = _intMindist2cntr_;
   end;

if (MISSING('_CLUSTER_ID_'n))then _CLUSTER_ID_ = -1;
   /*------------------------------------------*/
   /*_VA_DROP*/ drop '_CLUSTER_ID_'n '_DISTANCE_'n '_WARN_'n '_STANDARDIZED_DISTANCE_'n;
      '_CLUSTER_ID__641'n='_CLUSTER_ID_'n;
'_DISTANCE__641'n='_DISTANCE_'n;
'_WARN__641'n='_WARN_'n;
'_STANDARDIZED_DISTANCE__641'n='_STANDARDIZED_DISTANCE_'n;
   /*------------------------------------------*/

ScoreCluster=_Cluster_ID_;

run;

proc freq data=public.MainbearingScorecard; 
   table ScoreCluster ScoreCluster*targetMB0; 
run;