/* Required SAS setup */
options nodate nonumber ps=60 ls=120;
ods graphics on;
ods listing gpath=".";

/* Libraries (adjust paths if needed) */
/* work library is default; to persist datasets, uncomment and set a folder */
/* libname mydata "C:\path\to\folder"; */

/* -----------------------------
   Import data (semicolon-delimited; header row)
   Assumes raw_data.csv in current working directory
--------------------------------*/
filename rawcsv "raw_data.csv";
proc import datafile=rawcsv out=raw_data dbms=csv replace;
  guessingrows=max;
  delimiter=';';
  getnames=yes;
run;

/* -----------------------------
   Rename variables (acronyms -> full names)
--------------------------------*/
data raw_data;
  set raw_data;
  rename
    yd    = Financial_Distress
    tdta  = Debt_Assets
    reta  = Retained_Earnings
    opita = Income_Assets
    ebita = PreTax_Earnings_Assets
    lsls  = Log_Sales
    lta   = Log_Assets
    gempl = Employment_Growth
    invsls= Inventory_Sales
    nwcta = Net_Working_Capital_Assets
    cacl  = Current_Assets_Liabilities
    qacl  = Quick_Assets_Liabilities
    fata  = Fixed_Assets_Total_Assets
    ltdta = LongTerm_Debt_Total_Assets
    mveltd= Market_Value_Equity_LongTerm_Debt
  ;
run;

/* Convert European decimal commas to numeric (for character variables) */
proc contents data=raw_data out=_vars(keep=name type) noprint; run;
proc sql noprint;
  select name into :charvars separated by ' '
  from _vars where type=2; /* 2=character */
quit;

%macro decomma(ds);
  data &ds.;
    set &ds.;
    %if %length(&charvars.) %then %do;
      %do i=1 %to %sysfunc(countw(&charvars.));
        %let v=%scan(&charvars.,&i);
        /* make a numeric clone with dot decimal, then overwrite */
        _tmp_&i = input(tranwrd(&v., ',', '.'), best32.);
        drop &v.;
        rename _tmp_&i = &v.;
      %end;
    %end;
  run;
%mend;
%decomma(raw_data);

/* Replace sentinel -99.99 with missing */
data raw_data;
  set raw_data;
  array _nvars _numeric_;
  do over _nvars;
    if _nvars in (-99.99, -99.990000) then _nvars = .;
  end;
run;

/* Ensure dependent is 0/1 integer */
data raw_data;
  set raw_data;
  Financial_Distress = round(Financial_Distress);
run;

/* -----------------------------
   Sort and split into train/test by even/odd order within sort
--------------------------------*/
proc sort data=raw_data out=sorted;
  by Financial_Distress Income_Assets;
run;

data train test;
  set sorted;
  _ord + 1;
  if mod(_ord,2)=0 then output train;  /* even */
  else output test;                     /* odd  */
run;

/* -----------------------------
   Descriptive stats with skewness & kurtosis (training sample)
--------------------------------*/
proc contents data=train out=_v(keep=name type) noprint; run;
proc sql noprint;
  select name into :Xvars separated by ' '
  from _v where upcase(name) ne 'FINANCIAL_DISTRESS' and type=1;
quit;

proc means data=train n mean std min p25 p50 p75 max;
  var &Xvars.;
  ods output Summary=_means;
run;

proc univariate data=train noprint;
  var &Xvars.;
  ods output Moments=_moments; /* contains skewness & kurtosis */
run;

proc transpose data=_moments out=_momt_long name=Stat;
  by _var_;
  var N Skewness Kurtosis;
run;

proc sort data=_moments; by _var_; run;
proc sql;
  create table X_train_desc as
  select a._var_ as variable length=64
       , b.N, a.Mean as mean, a.StdDev as sd, a.Min as min, a.P25 as p25, a.Median as p50, a.P75 as p75, a.Max as max
       , m.Skewness as skewness, m.Kurtosis as kurtosis
  from _means a
  left join _moments m on upcase(a.Variable)=upcase(m._var_)
  left join (select distinct _var_, N from _moments) b on upcase(a.Variable)=upcase(b._var_);
quit;

/* -----------------------------
   Distribution plots: histogram + density + normal overlay
--------------------------------*/
ods graphics on;
%macro distplots(ds, vars, figtitle);
  %let n=%sysfunc(countw(&vars.));
  %do i=1 %to &n.;
    %let v=%scan(&vars., &i);
    title "&figtitle - &v";
    proc sgplot data=&ds.;
      histogram &v / nbins=30 transparency=0.3;
      density &v / type=kernel legendlabel="KDE";
      density &v / type=normal lineattrs=(pattern=shortdash) legendlabel="Normal";
    run;
  %end;
  title;
%mend;
%distplots(train, &Xvars., Figure 1);

/* -----------------------------
   Extreme observations: 90th pct per var; flag rows with >=5 exceedances
--------------------------------*/
proc sql noprint;
  create table _q90 as
  select %let j=1;
         %do i=1 %to %sysfunc(countw(&Xvars.));
           %let v=%scan(&Xvars.,&i);
           %if &i>1 %then ,;
           quantile(0.90, &v) as q90_&i
         %end;
  from train;
quit;

/* Create indicators and count */
data train_ext;
  if _n_=1 then set _q90;
  set train;
  array xv{*} &Xvars.;
  array qv{*} %do i=1 %to %sysfunc(countw(&Xvars.)); q90_&i %end;;
  array hi{*} %do i=1 %to %sysfunc(countw(&Xvars.)); hi&i %end;;
  ncrit = 0;
  do i=1 to dim(xv);
    hi{i} = (xv{i} >= qv{i});
    if hi{i}=1 then ncrit+1;
  end;
run;

data X_train_extreme;
  set train_ext;
  if ncrit>=5;
run;

data X_train_clean;
  set train_ext;
  if ncrit<5;
run;

/* Skew/Kurtosis improvement metrics */
proc univariate data=train noprint; var &Xvars.; ods output Moments=m_base; run;
proc univariate data=X_train_clean noprint; var &Xvars.; ods output Moments=m_clean; run;

data X_average_stats_improvement;
  merge m_base(rename=(Skewness=Skew_b Kurtosis=Kurt_b) in=a)
        m_clean(rename=(Skewness=Skew_c Kurtosis=Kurt_c) in=b);
  by _var_;
  if a and b;
  Train_Skew_AbsDiff     = abs(Skew_b - 0);
  Cleaned_Skew_AbsDiff   = abs(Skew_c - 0);
  Train_Kurt_AbsDiff     = abs(Kurt_b - 3);
  Cleaned_Kurt_AbsDiff   = abs(Kurt_c - 3);
run;

proc means data=X_average_stats_improvement mean;
  var Train_Skew_AbsDiff Cleaned_Skew_AbsDiff Train_Kurt_AbsDiff Cleaned_Kurt_AbsDiff;
run;

/* -----------------------------
   Adjusted distributions (keep between 10th/90th pct)
--------------------------------*/
data adj_X_train;
  set train;
  %do i=1 %to %sysfunc(countw(&Xvars.));
    %let v=%scan(&Xvars.,&i);
    /* compute 10th/90th per var */
    if _n_=1 then do;
      call missing(_l, _u);
    end;
  %end;
run;

/* Compute cutoffs and apply */
%macro trim10_90(ds, vars);
  proc sql noprint;
    create table _cuts as
    select %do i=1 %to %sysfunc(countw(&vars.));
             %let v=%scan(&vars.,&i);
             %if &i>1 %then ,;
             quantile(0.10, &v) as l&i, quantile(0.90, &v) as u&i
           %end;
    from &ds.;
  quit;
  data adj_X_train;
    if _n_=1 then set _cuts;
    set &ds.;
    %do i=1 %to %sysfunc(countw(&vars.));
      %let v=%scan(&vars.,&i);
      length adj_&v 8;
      adj_&v = &v;
      if &v < l&i or &v > u&i then adj_&v = .;
    %end;
  run;
%mend;
%trim10_90(train, &Xvars.);

%macro kde_adjusted(vars);
  %do i=1 %to %sysfunc(countw(&vars.));
    %let v=%scan(&vars.,&i);
    title "Figure 2 - Adjusted Distribution of &v";
    proc sgplot data=adj_X_train;
      density adj_&v / type=kernel;
      density adj_&v / type=normal lineattrs=(pattern=shortdash);
    run;
  %end;
  title;
%mend;
%kde_adjusted(&Xvars.);

/* -----------------------------
   Distress vs Non-distress KDE overlays
--------------------------------*/
%macro kde_by_group(vars);
  %do i=1 %to %sysfunc(countw(&vars.));
    %let v=%scan(&vars.,&i);
    title "Figure 3 - Distribution of &v by Financial Distress";
    proc sgplot data=train;
      density &v / group=Financial_Distress type=kernel;
    run;
  %end;
  title;
%mend;
%kde_by_group(&Xvars.);

/* -----------------------------
   Boxplots (all X) by group
--------------------------------*/
proc sgplot data=train;
  vbox Debt_Assets / category=Financial_Distress;
  title "Box Plot: Debt/Assets by Financial Distress";
run;
/* Repeat as needed for other variables; long multi-var box matrix is not directly supported in one call */

/* -----------------------------
   Scatter matrix (selected vars)
--------------------------------*/
proc sgscatter data=train;
  matrix Income_Assets Debt_Assets Retained_Earnings PreTax_Earnings_Assets Employment_Growth Financial_Distress / diagonal=(histogram kernel);
  title "Figure 7 Scatter Plot for Selected Variables";
run;

/* -----------------------------
   Correlations and t-stats
--------------------------------*/
proc corr data=train nosimple outp=_corr cov;
  var Financial_Distress &Xvars.;
run;

data corr_t;
  set _corr;
  if _TYPE_="CORR";
run;

/* t = r*sqrt((n-2)/(1-r^2)) — we display via PROC PRINT */
proc sql noprint;
  select count(*) into :_n from train where not missing(Financial_Distress);
quit;

/* -----------------------------
   Normality tests (Jarque-Bera computed)
--------------------------------*/
proc univariate data=train noprint;
  var &Xvars.;
  ods output Moments=jb_moments;
run;

data df_train_jarque_bera;
  set jb_moments;
  length group $20;
  group="AGGREGATE";
  n = N;
  JB = n/6 * (Skewness**2 + (Kurtosis-3)**2/4);
  /* p-value ~ chi-square with 2 df */
  p_value = 1 - probchi(JB, 2);
  keep _var_ JB p_value group;
run;

/* NFD subset */
proc univariate data=train(where=(Financial_Distress=0)) noprint;
  var &Xvars.;
  ods output Moments=jb_moments0;
run;
data jb0; set jb_moments0; length group $20; group="NO DISTRESS";
  n=N; JB = n/6*(Skewness**2 + (Kurtosis-3)**2/4); p_value=1-probchi(JB,2);
  keep _var_ JB p_value group;
run;
/* FD subset */
proc univariate data=train(where=(Financial_Distress=1)) noprint;
  var &Xvars.;
  ods output Moments=jb_moments1;
run;
data jb1; set jb_moments1; length group $20; group="DISTRESS";
  n=N; JB = n/6*(Skewness**2 + (Kurtosis-3)**2/4); p_value=1-probchi(JB,2);
  keep _var_ JB p_value group;
run;

data df_train_jarque_bera; set df_train_jarque_bera jb0 jb1; run;

/* -----------------------------
   Levene test for equality of variances (ALL and NFD vs FD)
--------------------------------*/
%macro hov_all(vars);
  %do i=1 %to %sysfunc(countw(&vars.));
    %let v=%scan(&vars.,&i);
    proc glm data=train noprint;
      class Financial_Distress;
      model &v = Financial_Distress;
      means Financial_Distress / hovtest=levene(type=abs);
      ods output HOVFTest=hov_&i;
    quit;
    data hov_&i; set hov_&i; length variable $64; variable="&v"; run;
    %if &i=1 %then %do; data df_train_levene; set hov_&i; run; %end;
    %else %do; proc append base=df_train_levene data=hov_&i force; run; %end;
  %end;
%mend;
%hov_all(&Xvars.);

/* -----------------------------
   Kolmogorov-Smirnov tests
   - Between groups: PROC NPAR1WAY EDF KS
   - Agg vs Normal: PROC UNIVARIATE NORMAL with KS
--------------------------------*/
%macro ks_tests(vars);
  %do i=1 %to %sysfunc(countw(&vars.));
    %let v=%scan(&vars.,&i);
    proc npar1way data=train edf;
      class Financial_Distress;
      var &v;
      ods output KS2Sample=ks2_&i;
    run;
    data ks2_&i; set ks2_&i; length variable $64; variable="&v"; run;

    proc univariate data=train normal;
      var &v;
      ods output TestsForNormality=ksnorm_&i;
    run;
    data ksnorm_&i; set ksnorm_&i; length variable $64; variable="&v"; run;

    %if &i=1 %then %do;
      data df_train_ks; set ks2_&i ksnorm_&i; run;
    %end;
    %else %do;
      proc append base=df_train_ks data=ks2_&i force; run;
      proc append base=df_train_ks data=ksnorm_&i force; run;
    %end;
  %end;
%mend;
%ks_tests(&Xvars.);

/* -----------------------------
   Pearson correlation of X with y
--------------------------------*/
proc corr data=train pearson nosimple;
  var &Xvars.;
  with Financial_Distress;
  ods output PearsonCorr=df_train_r;
run;

/* -----------------------------
   Two-sample t-tests (NFD vs FD)
--------------------------------*/
%macro ttests(vars);
  %do i=1 %to %sysfunc(countw(&vars.));
    %let v=%scan(&vars.,&i);
    proc ttest data=train;
      class Financial_Distress;
      var &v;
      ods output TTests=tt_&i;
    run;
    data tt_&i; set tt_&i; length variable $64; variable="&v"; run;
    %if &i=1 %then %do; data df_train_ttest; set tt_&i; run; %end;
    %else %do; proc append base=df_train_ttest data=tt_&i force; run; %end;
  %end;
%mend;
%ttests(&Xvars.);

/* -----------------------------
   One-way ANOVA via inverted regression Xi ~ y
--------------------------------*/
%macro anova_inverted(vars);
  %do i=1 %to %sysfunc(countw(&vars.));
    %let v=%scan(&vars.,&i);
    proc reg data=train noprint;
      model &v = Financial_Distress;
      ods output ParameterEstimates=pe_&i;
    quit;
    data pe_&i; set pe_&i; length variable $64; variable="&v"; if Variable="Financial_Distress"; keep variable Estimate StdErr tValue Probt; run;
    %if &i=1 %then %do; data df_train_ANOVA; set pe_&i; run; %end;
    %else %do; proc append base=df_train_ANOVA data=pe_&i force; run; %end;
  %end;
%mend;
%anova_inverted(&Xvars.);

/* -----------------------------
   Univariate LPM / LOGIT / PROBIT (Debt_Assets)
--------------------------------*/
data reg1; set train; if cmiss(of _all_) then delete; run;
proc reg data=reg1;
  model Financial_Distress = Debt_Assets;
  output out=reg1_lpm p=yhat_lpm1 r=resid_lpm1 h=lev_lpm1;
run; quit;

proc logistic data=reg1 plots(only)=roc(id=prob) noprint;
  model Financial_Distress(event='1') = Debt_Assets;
  output out=reg1_logit p=yhat_logit1;
  roc; ods output ROCAssociation=roc_logit1;
run;

proc probit data=reg1 noprint plots(only)=roc;
  class;
  model Financial_Distress(event='1') = Debt_Assets / d=normal;
  output out=reg1_probit p=yhat_probit1;
run;

/* Simple comparison table can be assembled from ODS outputs if needed */

/* -----------------------------
   Concordant/discordant/tied for LPM score (Debt_Assets)
--------------------------------*/
proc sql;
  create table conc as
  select a.Debt_Assets as da_fd, b.Debt_Assets as da_nfd,
         (a.yhat_lpm1 > b.yhat_lpm1) as concordant,
         (a.yhat_lpm1 < b.yhat_lpm1) as discordant,
         (a.yhat_lpm1 = b.yhat_lpm1) as tied
  from reg1_lpm as a inner join reg1_lpm as b
  on a.Financial_Distress=1 and b.Financial_Distress=0;
quit;

proc means data=conc noprint;
  var concordant discordant tied;
  output out=concordants sum=Concordant Discordant Tied;
run;

/* -----------------------------
   Multivariate models (selected variables)
--------------------------------*/
data reg2; set train; if cmiss(of Financial_Distress Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales) then delete; run;

proc reg data=reg2;
  model Financial_Distress = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
  output out=reg2_lpm p=yhat_lpm2 r=resid_lpm2 h=lev_lpm2;
run; quit;

proc logistic data=reg2 plots(only)=roc noprint;
  model Financial_Distress(event='1') = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
  output out=reg2_logit p=yhat_logit2;
  roc; ods output ROCAssociation=roc_logit2;
run;

proc probit data=reg2 noprint plots(only)=roc;
  model Financial_Distress(event='1') = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales / d=normal;
  output out=reg2_probit p=yhat_probit2;
run;

/* Compute AUC for LPM using PROC LOGISTIC with supplied scores */
data score_compare; merge reg2(keep=Financial_Distress) reg2_lpm(keep=yhat_lpm2) reg2_logit(keep=yhat_logit2) reg2_probit(keep=yhat_probit2); run;

proc logistic data=score_compare noprint;
  model Financial_Distress(event='1') = / nofit;
  roc 'LPM' pred=yhat_lpm2;
  roc 'Logit' pred=yhat_logit2;
  roc 'Probit' pred=yhat_probit2;
  ods output ROCContrastStatistics=auc_train;
run;

/* Probability curves vs Income_Assets (hold others at means) */
proc means data=reg2 noprint; var Debt_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales Income_Assets; output out=_m mean=; run;
data grid;
  if _n_=1 then set _m;
  do Income_Assets = Income_Assets-0.0001 to Income_Assets+0.0001 by ( (Income_Assets+0.0001)-(Income_Assets-0.0001) )/199;
    output;
  end;
  keep Debt_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales Income_Assets;
run;

proc score data=grid score=reg2 type=parms out=grid_lpm; /* for OLS, proc score with parms requires additional prep; simpler: refit model on grid via PROC REG SCORE statement */
run; /* (Placeholder; plotting curves often requires DATA step predictions via coefficients from OUTEST) */

proc reg data=reg2 outest=betas noprint;
  model Financial_Distress = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
run; quit;

data lpm_curve;
  if _n_=1 then set betas(keep=Intercept Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales);
  set grid;
  p_lpm = Intercept + Debt_Assets*Debt_Assets + Income_Assets*Income_Assets + Current_Assets_Liabilities*Current_Assets_Liabilities
          + Market_Value_Equity_LongTerm_Debt*Market_Value_Equity_LongTerm_Debt + Inventory_Sales*Inventory_Sales;
run;

/* For logistic and probit, we can use PROC LOGISTIC/PROBIT SCORE statement */
proc logistic data=reg2 outmodel=mdl_logit noprint;
  model Financial_Distress(event='1') = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
run;
proc logistic inmodel=mdl_logit;
  score data=grid out=logit_curve(rename=(P_1=p_logit));
run;

proc probit data=reg2 outest=est_probit noprint;
  model Financial_Distress(event='1') = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales / d=normal;
run;
/* approximate probit curve via DATA step using coefficients */
data probit_curve;
  if _n_=1 then set est_probit(keep=Intercept Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales);
  set grid;
  lin = Intercept + Debt_Assets*Debt_Assets + Income_Assets*Income_Assets + Current_Assets_Liabilities*Current_Assets_Liabilities
        + Market_Value_Equity_LongTerm_Debt*Market_Value_Equity_LongTerm_Debt + Inventory_Sales*Inventory_Sales;
  p_probit = cdf('normal', lin);
run;

/* Plot curves */
proc sgplot data=lpm_curve;
  series x=Income_Assets y=p_lpm / legendlabel='LPM';
  title "Figure 11 - Probability of Financial Distress vs Income/Assets";
run;
proc sgplot data=logit_curve;
  series x=Income_Assets y=p_logit / legendlabel='Logit';
run;
proc sgplot data=probit_curve;
  series x=Income_Assets y=p_probit / legendlabel='Probit';
run;

/* -----------------------------
   Variables combinations optimization for k in {2,3,4} (LPM)
--------------------------------*/
%macro best_models(ds, y, xlist, kmin=2, kmax=4);
  %local n i j a b c d xi xj xk xl comb;
  %let n=%sysfunc(countw(&xlist.));
  data model_cmp; length Estimator $12 variables $400 R2 AUC 8 k 8; stop; run;

  %do k=&kmin. %to &kmax.;
    %if &k=2 %then %do;
      %do i=1 %to %eval(&n.-1);
        %do j=%eval(&i.+1) %to &n.;
          %let xi=%scan(&xlist.,&i);
          %let xj=%scan(&xlist.,&j);
          %let comb=&xi. &xj.;
          proc reg data=&ds. outest=_b noprint;
            model &y = &comb.;
          run; quit;
          data _null_;
            set _b;
            call symputx('R2', _RSQ_);
          run;
          /* Compute in-sample AUC for OLS predictions */
          proc reg data=&ds. noprint outest=_parms;
            model &y = &comb.;
            output out=_pred p=phat;
          run; quit;
          proc logistic data=_pred noprint;
            model &y(event='1') = / nofit;
            roc 'LPM' pred=phat;
            ods output ROCContrastStatistics=_auc;
          run;
          data _auc; set _auc; if Label2='LPM' then call symputx('AUC', C);
          run;
          data model_cmp; set model_cmp; Estimator='LPM (OLS)'; variables="&comb."; R2=&R2.; AUC=&AUC.; k=&k.; output; run;
        %end;
      %end;
    %end;
    %else %if &k=3 %then %do;
      %do i=1 %to %eval(&n.-2);
        %do j=%eval(&i.+1) %to %eval(&n.-1);
          %do a=%eval(&j.+1) %to &n.;
            %let xi=%scan(&xlist.,&i);
            %let xj=%scan(&xlist.,&j);
            %let xk=%scan(&xlist.,&a);
            %let comb=&xi. &xj. &xk.;
            proc reg data=&ds. outest=_b noprint;
              model &y = &comb.;
            run; quit;
            data _null_; set _b; call symputx('R2', _RSQ_); run;
            proc reg data=&ds. noprint;
              model &y = &comb.;
              output out=_pred p=phat;
            run; quit;
            proc logistic data=_pred noprint;
              model &y(event='1') = / nofit;
              roc 'LPM' pred=phat;
              ods output ROCContrastStatistics=_auc;
            run;
            data _auc; set _auc; if Label2='LPM' then call symputx('AUC', C); run;
            data model_cmp; set model_cmp; Estimator='LPM (OLS)'; variables="&comb."; R2=&R2.; AUC=&AUC.; k=&k.; output; run;
          %end;
        %end;
      %end;
    %end;
    %else %if &k=4 %then %do;
      %do i=1 %to %eval(&n.-3);
        %do j=%eval(&i.+1) %to %eval(&n.-2);
          %do a=%eval(&j.+1) %to %eval(&n.-1);
            %do b=%eval(&a.+1) %to &n.;
              %let xi=%scan(&xlist.,&i);
              %let xj=%scan(&xlist.,&j);
              %let xk=%scan(&xlist.,&a);
              %let xl=%scan(&xlist.,&b);
              %let comb=&xi. &xj. &xk. &xl.;
              proc reg data=&ds. outest=_b noprint;
                model &y = &comb.;
              run; quit;
              data _null_; set _b; call symputx('R2', _RSQ_); run;
              proc reg data=&ds. noprint;
                model &y = &comb.;
                output out=_pred p=phat;
              run; quit;
              proc logistic data=_pred noprint;
                model &y(event='1') = / nofit;
                roc 'LPM' pred=phat;
                ods output ROCContrastStatistics=_auc;
              run;
              data _auc; set _auc; if Label2='LPM' then call symputx('AUC', C); run;
              data model_cmp; set model_cmp; Estimator='LPM (OLS)'; variables="&comb."; R2=&R2.; AUC=&AUC.; k=&k.; output; run;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  proc sort data=model_cmp; by k descending AUC descending R2; run;
%mend;

%best_models(reg2, Financial_Distress, &Xvars., kmin=2, kmax=4);

/* Keep top 5 by k */
data summary_results_model_comparison;
  set model_cmp;
  by k;
  if first.k then rank=0;
  rank+1;
  if rank<=5;
run;

/* -----------------------------
   Out-of-sample testing (apply train models to test set)
--------------------------------*/
data test2; set test;
  if cmiss(of Financial_Distress Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales) then delete;
run;

/* Refit on train for scoring dataset creation */
proc reg data=reg2 outest=betas2 noprint;
  model Financial_Distress = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
run; quit;

/* LPM predictions on test */
data test_scores;
  if _n_=1 then set betas2(keep=Intercept Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales);
  set test2(keep=Financial_Distress Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales);
  yhat_lpm = Intercept + Debt_Assets*Debt_Assets + Income_Assets*Income_Assets + Current_Assets_Liabilities*Current_Assets_Liabilities
             + Market_Value_Equity_LongTerm_Debt*Market_Value_Equity_LongTerm_Debt + Inventory_Sales*Inventory_Sales;
run;

/* Logit model score */
proc logistic data=reg2 outmodel=mdl_logit2 noprint;
  model Financial_Distress(event='1') = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
run;
proc logistic inmodel=mdl_logit2;
  score data=test2 out=logit_scores(rename=(P_1=yhat_logit));
run;

/* Probit model score */
proc probit data=reg2 outest=est_probit2 noprint;
  model Financial_Distress(event='1') = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales / d=normal;
run;
data probit_scores;
  if _n_=1 then set est_probit2(keep=Intercept Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales);
  set test2(keep=Financial_Distress Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales);
  lin = Intercept + Debt_Assets*Debt_Assets + Income_Assets*Income_Assets + Current_Assets_Liabilities*Current_Assets_Liabilities
        + Market_Value_Equity_LongTerm_Debt*Market_Value_Equity_LongTerm_Debt + Inventory_Sales*Inventory_Sales;
  yhat_probit = cdf('normal', lin);
run;

/* Merge test scores */
data test_all;
  merge test_scores(keep=Financial_Distress yhat_lpm)
        logit_scores(keep=yhat_logit)
        probit_scores(keep=yhat_probit);
run;

/* AUC (continuous and binary at 0.5) */
data test_all;
  set test_all;
  yhat_lpm_bin    = (yhat_lpm   >= 0.5);
  yhat_logit_bin  = (yhat_logit >= 0.5);
  yhat_probit_bin = (yhat_probit>= 0.5);
run;

proc logistic data=test_all noprint;
  model Financial_Distress(event='1') = / nofit;
  roc 'LPM (cont)'   pred=yhat_lpm;
  roc 'Logit (cont)' pred=yhat_logit;
  roc 'Probit (cont)' pred=yhat_probit;
  roc 'LPM (bin)'    pred=yhat_lpm_bin;
  roc 'Logit (bin)'  pred=yhat_logit_bin;
  roc 'Probit (bin)' pred=yhat_probit_bin;
  ods output ROCContrastStatistics=auc_test;
  ods output ROCCurve=roc_points;
run;

/* Show first 15 predicted rows */
proc print data=test_all(obs=15); run;

/* -----------------------------
   ROC curves plotting (from roc_points)
--------------------------------*/
proc sgplot data=roc_points;
  series x=1_Specificity y=Sensitivity / group=ROCModel;
  lineparm x=0 y=0 slope=1 / lineattrs=(pattern=shortdash);
  xaxis label="False Positive Rate";
  yaxis label="True Positive Rate";
  title "Figure 12 - ROC Curves (out-of-sample)";
run;

/* -----------------------------
   Standardized Pearson residuals (training sample)
   - LPM: via PROC REG outputs + formula
   - Logit/Probit: via PROC GENMOD for Pearson residuals and leverage
--------------------------------*/
proc reg data=reg2;
  model Financial_Distress = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales;
  output out=res_lpm p=ph r=r_lpm h=h_lpm;
run; quit;

data res_lpm;
  set res_lpm;
  /* Pearson residual for binary: (y - p)/sqrt(p*(1-p)) */
  pearson = (Financial_Distress - ph)/sqrt(max(ph*(1-ph), 1e-8));
  stdres_lpm = pearson / sqrt(max(1 - h_lpm, 1e-8));
run;

proc genmod data=reg2;
  model Financial_Distress = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales / dist=bin link=logit;
  output out=res_logit pred=plogit reschi=pearson h=h_logit;
run;
data res_logit; set res_logit; stdres_logit = pearson / sqrt(max(1-h_logit, 1e-8)); run;

proc genmod data=reg2;
  model Financial_Distress = Debt_Assets Income_Assets Current_Assets_Liabilities Market_Value_Equity_LongTerm_Debt Inventory_Sales / dist=bin link=probit;
  output out=res_probit pred=pprobit reschi=pearson h=h_probit;
run;
data res_probit; set res_probit; stdres_probit = pearson / sqrt(max(1-h_probit, 1e-8)); run;

/* Distributions by group */
proc sgplot data=res_lpm;
  density stdres_lpm / group=Financial_Distress type=kernel;
  title "Figure 13 - Std Pearson Residuals (LPM)";
run;
proc sgplot data=res_logit;
  density stdres_logit / group=Financial_Distress type=kernel;
  title "Std Pearson Residuals (Logit)";
run;
proc sgplot data=res_probit;
  density stdres_probit / group=Financial_Distress type=kernel;
  title "Std Pearson Residuals (Probit)";
run;

/* Outliers threshold and tables (|stdres| > 2) */
%let outthr=2;
proc sql;
  create table out_lpm as
  select monotonic() as Obs_Index, stdres_lpm as Residual,
         (case when stdres_lpm>0 then "Positive extreme" else "Negative extreme" end) as Side length=20,
         (case when Financial_Distress=1 then "FD (yd=1)" else "NFD (yd=0)" end) as Firm_cluster length=12
  from res_lpm
  where abs(stdres_lpm) > &outthr.;
quit;
proc sql;
  create table out_logit as
  select monotonic() as Obs_Index, stdres_logit as Residual,
         (case when stdres_logit>0 then "Positive extreme" else "Negative extreme" end) as Side length=20,
         (case when Financial_Distress=1 then "FD (yd=1)" else "NFD (yd=0)" end) as Firm_cluster length=12
  from res_logit
  where abs(stdres_logit) > &outthr.;
quit;
proc sql;
  create table out_probit as
  select monotonic() as Obs_Index, stdres_probit as Residual,
         (case when stdres_probit>0 then "Positive extreme" else "Negative extreme" end) as Side length=20,
         (case when Financial_Distress=1 then "FD (yd=1)" else "NFD (yd=0)" end) as Firm_cluster length=12
  from res_probit
  where abs(stdres_probit) > &outthr.;
quit;

/* -----------------------------
   Best threshold minimizing expected loss
--------------------------------*/
proc sql noprint;
  select mean(Financial_Distress) into :fd_ratio from test_all;
quit;
%let nfd_ratio = %sysevalf(1 - &fd_ratio.);
%let cost_FP = 0.1;
%let cost_FN = 0.2;

/* OUTROC gives Sensitivity/Specificity at cutoffs; compute Expected Loss */
proc logistic data=test_all noprint;
  model Financial_Distress(event='1') = / nofit;
  roc 'LPM' pred=yhat_lpm;
  ods output ROCCurve=roc_lpm;
run;

data best_lpm;
  set roc_lpm;
  length Model $28;
  fpr = 1 - _SPE_;
  tpr = _SENS_;
  Expected_Loss = &cost_FP.*fpr*&nfd_ratio. + &cost_FN.*(1 - tpr)*&fd_ratio.;
  Model = "Linear Probability (LPM)";
run;
proc sort data=best_lpm; by Expected_Loss; run;
data best_lpm; set best_lpm(obs=1); keep Model _PROB_ Expected_Loss fpr tpr; rename _PROB_=Best_Threshold; run;

proc logistic data=test_all noprint; model Financial_Distress(event='1') = / nofit; roc 'Logit' pred=yhat_logit; ods output ROCCurve=roc_logit; run;
data best_logit; set roc_logit; length Model $28; fpr=1-_SPE_; tpr=_SENS_; Expected_Loss=&cost_FP.*fpr*&nfd_ratio.+&cost_FN.*(1-tpr)*&fd_ratio.; Model="Logit"; run;
proc sort data=best_logit; by Expected_Loss; run; data best_logit; set best_logit(obs=1); keep Model _PROB_ Expected_Loss fpr tpr; rename _PROB_=Best_Threshold; run;

proc logistic data=test_all noprint; model Financial_Distress(event='1') = / nofit; roc 'Probit' pred=yhat_probit; ods output ROCCurve=roc_probit; run;
data best_probit; set roc_probit; length Model $28; fpr=1-_SPE_; tpr=_SENS_; Expected_Loss=&cost_FP.*fpr*&nfd_ratio.+&cost_FN.*(1-tpr)*&fd_ratio.; Model="Probit"; run;
proc sort data=best_probit; by Expected_Loss; run; data best_probit; set best_probit(obs=1); keep Model _PROB_ Expected_Loss fpr tpr; rename _PROB_=Best_Threshold; run;

data summary_table4_thresholds; set best_lpm best_logit best_probit; format Expected_Loss fpr tpr Best_Threshold 8.4; run;
proc print data=summary_table4_thresholds; title "Best Thresholds by Expected Loss"; run;

/* Sensitivity and Specificity vs Probability Cutoff (for each model) */
%macro sens_spec_plot(scorevar, figtitle);
  proc logistic data=test_all noprint;
    model Financial_Distress(event='1') = / nofit;
    roc pred=&scorevar;
    ods output ROCCurve=ss_curve;
  run;
  proc sort data=ss_curve; by _PROB_; run;
  data ss_curve; set ss_curve; Sensitivity=_SENS_; Specificity=_SPE_; keep _PROB_ Sensitivity Specificity; run;
  proc sgplot data=ss_curve;
    series x=_PROB_ y=Sensitivity;
    series x=_PROB_ y=Specificity / lineattrs=(pattern=shortdash);
    yaxis min=-0.05 max=1.05;
    xaxis label="Probability Cutoff";
    title "&figtitle";
  run;
%mend;

%sens_spec_plot(yhat_lpm,   Figure 14 - Sensitivity/Specificity vs Cutoff (LPM));
%sens_spec_plot(yhat_logit, Figure 15 - Sensitivity/Specificity vs Cutoff (Logit));
%sens_spec_plot(yhat_probit,Figure 16 - Sensitivity/Specificity vs Cutoff (Probit));

/* -----------------------------
   Dummy Trap Analysis
   Models:
   1) tdta on yd + ynd + const (collinearity expected)
   2) tdta on yd + const
   3) tdta on ynd + const
   4) tdta on yd + ynd with constraint (b_yd + b_ynd = 0)
--------------------------------*/
data dt; set train(keep=Financial_Distress Debt_Assets);
  yd  = Financial_Distress;
  ynd = 1 - yd;
  tdta = Debt_Assets;
run;

/* Model 1 */
proc reg data=dt;
  model tdta = yd ynd;
  ods output ParameterEstimates=tdta_m1;
run; quit;

/* Model 2 */
proc reg data=dt;
  model tdta = yd;
  ods output ParameterEstimates=tdta_m2;
run; quit;

/* Model 3 */
proc reg data=dt;
  model tdta = ynd;
  ods output ParameterEstimates=tdta_m3;
run; quit;

/* Model 4 with restriction using PROC MODEL */
proc model data=dt;
  parms b0 b1 b2;
  tdta = b0 + b1*yd + b2*ynd;
  fit tdta / ols;
  restrict b1 + b2 = 0;
  ods output ParameterEstimates=tdta_m4;
quit;

title; ods graphics off;
