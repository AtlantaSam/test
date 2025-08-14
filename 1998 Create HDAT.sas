
CAS MySession sessopts=(timeout=1800);
CASLib _all_ assign;

%macro hDat_It(Lib1=, File=);
%Put Running code for &Lib1..&File.;
     proc cas;
          table.save / caslib="&Lib1" table={name="&File." , caslib="&Lib1"} 
              name="&File..sashdat" replace=True;
     quit;

%mend;

%Let LibNow=casuser;

Proc contents data=&LibNow.._ALL_ out=temp(keep=memname) noprint;
run;
proc sort data=temp nodupkey;
     by memname;
run;

Data temp;
     set temp;
     format cmd $1280.;
     libnow="&LibNow.";
     cmd=cats('%hDat_It(Lib1=', LibNow, ',File=', memname , ');') ;
     call execute(cmd);
run;
