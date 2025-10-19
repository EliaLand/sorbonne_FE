* Required Stata packages (run once; harmless if already installed)
cap which esttab
if _rc ssc install estout, replace
cap which tuples
if _rc ssc install tuples, replace
cap which winsor2
if _rc ssc install winsor2, replace

clear all
set more off
version 18.0

* -----------------------------
* Paths
* (Assumes raw_data.csv is in the current working directory. Adjust as needed.)
local datafile "raw_data.csv"

* -----------------------------
* Import data (semicolon-delimited; header row)
import delimited using "`datafile'", clear varn(1) delim(";") bindquote(strict) stringcols(_all)

* Variables dictionary (rename acronyms -> full names)
rename yd  "Financial Distress"
rename tdta "Debt/Assets"
rename reta "Retained Earnings"
rename opita "Income/Assets"
rename ebita "Pre-Tax Earnings/Assets"
rename lsls "Log Sales"
rename lta  "Log Assets"
rename gempl "Employment Growth"
rename invsls "Inventory/Sales"
rename nwcta "Net Working Capital/Assets"
rename cacl "Current Assets/Liabilities"
rename qacl "Quick Assets/Liabilities"
rename fata "Fixed Assets/Total Assets"
rename ltdta "Long-Term Debt/Total Assets"
rename mveltd "Market Value Equity/Long-Term Debt"

* Convert European decimal commas to numeric
ds
foreach v of varlist `r(varlist)' {
    capture confirm string variable `v'
    if !_rc {
        destring `v', replace dpcomma force
    }
}

* Replace sentinel -99.99 with missing
foreach v of varlist _all {
    capture confirm numeric variable `v'
    if !_rc {
        replace `v' = . if `v' == -99.99 | `v' == -99.990000
    }
}

* Ensure dependent is 0/1 byte
capture confirm numeric variable "Financial Distress"
if !_rc {
    replace "Financial Distress" = round("Financial Distress")
    recast byte "Financial Distress"
}

* -----------------------------
* Sorted split into training/testing (even/odd rows) by Financial Distress, Income/Assets
tempfile sorted train test
sort "Financial Distress" "Income/Assets"
gen long __ord = _n
save `sorted', replace

preserve
use `sorted', clear
keep if mod(__ord,2)==0   // even -> training
tempfile train
save `train', replace
restore

preserve
use `sorted', clear
keep if mod(__ord,2)==1   // odd -> testing
tempfile test
save `test', replace
restore

* -----------------------------
* Set macros for X variables (independents)
local Xvars "Debt/Assets Retained Earnings Income/Assets Pre-Tax Earnings/Assets Log Sales Log Assets Employment Growth Inventory/Sales Net Working Capital/Assets Current Assets/Liabilities Quick Assets/Liabilities Fixed Assets/Total Assets Long-Term Debt/Total Assets Market Value Equity/Long-Term Debt"

* -----------------------------
* Descriptive statistics (training sample)
use `train', clear
qui ds `Xvars', has(type numeric)
local Xnum `r(varlist)'

display as text "Training sample sizes:"
count
local Ntrain = r(N)
display as result "N(train) = `Ntrain'"

* Summary table with skewness and kurtosis (sktest reports them)
tempname posth
postfile `posth' str40 varname double N mean sd p25 p50 p75 min max skew kurt using train_desc, replace
foreach v of varlist `Xnum' {
    qui count if !missing(`v')
    local n = r(N)
    qui summ `v', detail
    local mean = r(mean)
    local sd   = r(sd)
    local p25  = r(p25)
    local p50  = r(p50)
    local p75  = r(p75)
    local min  = r(min)
    local max  = r(max)
    capture noisily sktest `v'
    local skew = .
    local kurt = .
    if _rc==0 {
        local skew = r(skewness)
        local kurt = r(kurtosis)
    }
    post `posth' ("`v'") (`n') (`mean') (`sd') (`p25') (`p50') (`p75') (`min') (`max') (`skew') (`kurt')
}
postclose `posth'
use train_desc, clear
sort varname
tempfile X_train_desc
save `X_train_desc', replace

* -----------------------------
* Distribution plots: histogram + kdensity + normal overlay
use `train', clear
foreach v of varlist `Xnum' {
    capture noisily histogram `v', kdensity normal title("Distribution of `v'") name(h_`v', replace)
}

* -----------------------------
* Extreme observations: top 90th percentile indicator per var; flag rows with >=5 exceedances
use `train', clear
gen byte __ext = 0
tempname c90
foreach v of varlist `Xnum' {
    qui centile `v', centile(90)
    scalar `c90' = r(c_1)
    gen byte _hi_`=substr("`v'",1,18)' = (`v' >= `c90') if !missing(`v')
    replace __ext = __ext + _hi_`=substr("`v'",1,18)'
}
gen byte __ext5 = (__ext >= 5)

preserve
keep if __ext5
order __ext * // view
tempfile X_train_extreme
save `X_train_extreme', replace
restore

preserve
keep if !__ext5
tempfile X_train_clean
save `X_train_clean', replace
restore

* Compare skew/kurt before/after cleaning extremes
preserve
tempname posth2
postfile `posth2' str40 stat double baseline cleaned using X_stats_improvement, replace
foreach stat in skewness kurtosis {
    tempname bmean cmean
    scalar `bmean' = .
    scalar `cmean' = .
    * compute abs deviation vs 0 (skew) or 3 (kurt)
    local acc_baseline = 0
    local acc_cleaned  = 0
    local kcount = 0
    foreach v of varlist `Xnum' {
        qui sktest `v'
        local b = cond("`stat'"=="skewness", abs(r(skewness)-0), abs(r(kurtosis)-3))
        preserve
        use `X_train_clean', clear
        qui sktest `v'
        local c = cond("`stat'"=="skewness", abs(r(skewness)-0), abs(r(kurtosis)-3))
        restore
        local acc_baseline = `acc_baseline' + `b'
        local acc_cleaned  = `acc_cleaned' + `c'
        local kcount = `kcount' + 1
    }
    scalar `bmean' = `acc_baseline' / `kcount'
    scalar `cmean' = `acc_cleaned'  / `kcount'
    post `posth2' ("`stat'") (`bmean') (`cmean')
}
postclose `posth2'
use X_stats_improvement, clear
gen pct_change = 100*(baseline - cleaned)/baseline
tempfile X_average_stats_improvement
save `X_average_stats_improvement', replace

* -----------------------------
* Adjusted distributions (drop outside 10th-90th percentiles)
use `train', clear
tempfile adj
save `adj', replace
foreach v of varlist `Xnum' {
    qui centile `v', centile(10 90)
    gen double __adj_`v' = `v'
    replace __adj_`v' = . if `v' < r(c_1) | `v' > r(c_2)
    capture noisily kdensity __adj_`v', normal title("Distribution of Adjusted `v'") name(k_`v', replace)
}
erase `adj'

* -----------------------------
* Distress vs Non-distress distributions (kdensity overlays)
use `train', clear
preserve
keep "Financial Distress" `Xnum'
tempfile tr_core
save `tr_core', replace
restore

foreach v of varlist `Xnum' {
    twoway (kdensity `v' if "Financial Distress"==1, lcolor(red) fcolor(red%30)) ///
           (kdensity `v' if "Financial Distress"==0, lcolor(green) fcolor(green%30)), ///
           legend(order(1 "Distress (y=1)" 2 "No Distress (y=0)")) ///
           title("Distribution of `v'") name(ovl_`v', replace)
}

* -----------------------------
* Box plots by group
use `train', clear
local Xsel : list Xnum - "Financial Distress"

graph box `Xsel' if "Financial Distress"==0, title("Box Plot for X, No Financial Distress") name(box_nfd, replace)
graph box `Xsel' if "Financial Distress"==1, title("Box Plot for X, Financial Distress") name(box_fd, replace)

* Excluding high-range variables
local Xsel2 : list Xnum - "Financial Distress Log Sales Log Assets Long-Term Debt/Total Assets Current Assets/Liabilities Quick Assets/Liabilities"

graph box `Xsel2' if "Financial Distress"==0, title("Box Plot (Selected X), No Financial Distress") name(box2_nfd, replace)
graph box `Xsel2' if "Financial Distress"==1, title("Box Plot (Selected X), Financial Distress") name(box2_fd, replace)

* -----------------------------
* Scatter matrix for selected variables
use `train', clear
local Xy "Income/Assets Debt/Assets Retained Earnings Pre-Tax Earnings/Assets Employment Growth"
graph matrix `Xy' "Financial Distress", half title("Figure 7 Scatter Plot for Selected Variables") name(gmat7, replace)

* -----------------------------
* Correlation matrix with t-stats (print)
use `train', clear
preserve
* Create short names map (full->acronym)
* (We keep original names; show corr + N then compute t)
corr `Xnum' "Financial Distress"
matrix R = r(C)
local n = r(N)
matrix T = J(colsof(R), colsof(R), .)
forvalues i=1/`=colsof(R)' {
    forvalues j=1/`=colsof(R)' {
        scalar r_ij = R[`i',`j']
        scalar t_ij = r_ij*sqrt((`n'-2)/(1-r_ij^2))
        matrix T[`i',`j'] = t_ij
    }
}
matrix list R
matrix list T
restore

* -----------------------------
* Normality (Jarque-Bera equivalent): sktest per variable overall and within groups
use `train', clear
tempname jbpost
postfile `jbpost' str40 var str12 group double jb_p using jb_out, replace
foreach v of varlist `Xnum' {
    capture noisily sktest `v'
    if !_rc post `jbpost' ("`v'") ("AGGREGATE") (r(P_chi2))
    capture noisily sktest `v' if "Financial Distress"==0
    if !_rc post `jbpost' ("`v'") ("NO DISTRESS") (r(P_chi2))
    capture noisily sktest `v' if "Financial Distress"==1
    if !_rc post `jbpost' ("`v'") ("DISTRESS") (r(P_chi2))
}
postclose `jbpost'
use jb_out, clear
reshape wide jb_p, i(var) j(group) string
tempfile df_train_jarque_bera
save `df_train_jarque_bera', replace

* -----------------------------
* Levene/Brown-Forsythe variance test: robvar (median-centered) for ALL and pair NFD vs FD
use `train', clear
tempname levpost
postfile `levpost' str40 var double all_F all_p nfdfd_F nfdfd_p using lev_out, replace
foreach v of varlist `Xnum' {
    qui robvar `v', by("Financial Distress")
    post `levpost' ("`v'") (r(F)) (r(p)) (.)(.)
    * 2-group re-run (same as above because y is binary)
    qui robvar `v', by("Financial Distress")
    post `levpost' ("`v'") (.)(.) (r(F)) (r(p))
}
postclose `levpost'
use lev_out, clear
bysort var: replace all_F = all_F[1] if missing(all_F)
bysort var: replace all_p = all_p[1] if missing(all_p)
bysort var: keep if _n==1
tempfile df_train_levene
save `df_train_levene', replace

* -----------------------------
* Kolmogorov-Smirnov tests
use `train', clear
tempname kspost
postfile `kspost' str40 var double ks_nfdfd_p ks_aggnorm_p using ks_out, replace
foreach v of varlist `Xnum' {
    * NFD vs FD
    capture noisily ksmirnov `v', by("Financial Distress")
    local p1 = .
    if !_rc local p1 = r(p)
    * Aggregate vs Normal
    quietly sum `v'
    local mu = r(mean)
    local sd = r(sd)
    tempvar z
    gen double `z' = (`v' - `mu')/`sd'
    capture noisily ksmirnov `z' = normal()
    local p2 = .
    if !_rc local p2 = r(p)
    post `kspost' ("`v'") (`p1') (`p2')
    drop `z'
}
postclose `kspost'
use ks_out, clear
tempfile df_train_ks
save `df_train_ks', replace

* -----------------------------
* Pearson r between each X and y
use `train', clear
drop if missing("Financial Distress")
tempname rpost
postfile `rpost' str40 var double r p using r_out, replace
foreach v of varlist `Xnum' {
    capture noisily pwcorr `v' "Financial Distress", sig
    if !_rc {
        matrix list r(rho)
        scalar rr = r(rho)[1,1]
        scalar pp = r(sig)[1,1]
        post `rpost' ("`v'") (rr) (pp)
    }
}
postclose `rpost'
use r_out, clear
tempfile df_train_r
save `df_train_r', replace

* -----------------------------
* Two-sample t-tests (NFD vs FD)
use `train', clear
tempname tpost
postfile `tpost' str40 var double tstat p using t_out, replace
foreach v of varlist `Xnum' {
    capture noisily ttest `v', by("Financial Distress")
    if !_rc post `tpost' ("`v'") (r(t)) (r(p))
}
postclose `tpost'
use t_out, clear
tempfile df_train_ttest
save `df_train_ttest', replace

* -----------------------------
* One-way ANOVA via inverted regression: Xi on y (binary)
use `train', clear
tempname apost
postfile `apost' str40 var double tstat p using a_out, replace
foreach v of varlist `Xnum' {
    capture noisily regress `v' "Financial Distress"
    if !_rc post `apost' ("`v'") (_b["Financial Distress"]/_se["Financial Distress"]) (2*ttail(e(df_r),abs(_b["Financial Distress"]/_se["Financial Distress"])))
}
postclose `apost'
use a_out, clear
tempfile df_train_ANOVA
save `df_train_ANOVA', replace

* -----------------------------
* Univariate LPM/Logit/Probit (Debt/Assets)
use `train', clear
drop if missing("Financial Distress") | missing("Debt/Assets")

eststo clear
regress "Financial Distress" "Debt/Assets"
eststo lpm1
logit  "Financial Distress" "Debt/Assets"
eststo logit1
probit "Financial Distress" "Debt/Assets"
eststo probit1

* Alternative table
esttab lpm1 logit1 probit1, se b(%9.4f) star(* 0.05 ** 0.01 *** 0.001) label title("Financial Distress - Univariate Models Comparison (Debt/Assets)")

* Concordant/discordant/tied via somersd (approximate, reports concordance probability)
predict double phat_lpm1 if e(sample), xb
somersd "Financial Distress" phat_lpm1
* (Outputs include concordance probability; exact counts not recovered here.)

* -----------------------------
* Multivariate models with selected variables
use `train', clear
drop if missing("Financial Distress")
foreach v in "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales" {
    drop if missing(`v')
}
eststo clear
regress "Financial Distress" "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales"
eststo lpm2
logit   "Financial Distress" "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales"
eststo logit2
probit  "Financial Distress" "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales"
eststo probit2

* AUC (training)
predict double yhat_lpm_tr, xb
predict double yhat_logit_tr, pr
predict double yhat_probit_tr, pr
roctab "Financial Distress" yhat_lpm_tr, detail
scalar AUC_LPM_tr = r(area)
roctab "Financial Distress" yhat_logit_tr, detail
scalar AUC_LOG_tr = r(area)
roctab "Financial Distress" yhat_probit_tr, detail
scalar AUC_PRO_tr = r(area)

* Table
esttab lpm2 logit2 probit2, se b(%9.4f) star(* 0.05 ** 0.01 *** 0.001) label title("Financial Distress - Model Comparison with Selected Target Variables")

* Probability curves vs Income/Assets (hold others at means)
quietly summarize "Debt/Assets"
scalar m_tdta = r(mean)
quietly summarize "Current Assets/Liabilities"
scalar m_cacl = r(mean)
quietly summarize "Market Value Equity/Long-Term Debt"
scalar m_mveltd = r(mean)
quietly summarize "Inventory/Sales"
scalar m_invsls = r(mean)

range incgrid = r(min) r(max) 200
drop _all in 1/0
use `train', clear
quietly summarize "Income/Assets"
scalar incmin = r(min)
scalar incmax = r(max)
range incx incmin incmax 200
gen double tdta_m = m_tdta
gen double cacl_m = m_cacl
gen double mveltd_m = m_mveltd
gen double invsls_m = m_invsls
gen byte yd = .
tempfile curves
keep incx tdta_m cacl_m mveltd_m invsls_m yd
save `curves', replace

* Predict on grid
use `curves', clear
rename incx "Income/Assets"
rename tdta_m "Debt/Assets"
rename cacl_m "Current Assets/Liabilities"
rename mveltd_m "Market Value Equity/Long-Term Debt"
rename invsls_m "Inventory/Sales"
predict double p_lpm using lpm2
predict double p_logit using logit2, pr
predict double p_probit using probit2, pr
twoway (line p_lpm "Income/Assets") (line p_logit "Income/Assets") (line p_probit "Income/Assets"), ///
       legend(order(1 "LPM" 2 "Logit" 3 "Probit")) ///
       title("Figure 11 - Probability of Financial Distress vs Income/Assets")

* -----------------------------
* Variables combinations optimization for k in {2,3,4} using tuples
use `train', clear
drop if missing("Financial Distress")
local allX : list Xnum - "Financial Distress"
tempname cmp
postfile `cmp' str60 estimator str400 variables double R2 AUC byte k using model_cmp, replace
foreach K in 2 3 4 {
    tuples `allX', k(`K') local(combos)
    foreach combo of local combos {
        quietly regress "Financial Distress" `combo'
        predict double yxb, xb
        quietly roctab "Financial Distress" yxb
        local auc = r(area)
        local r2  = e(r2)
        post `cmp' ("LPM (OLS)") ("`combo'") (`r2') (`auc') (`K')
        drop yxb
    }
}
postclose `cmp'
use model_cmp, clear
gsort k -AUC -R2
by k: gen rank = _n
keep if rank<=5
list, abbreviate(30)

* -----------------------------
* Out-of-sample testing
use `test', clear
drop if missing("Financial Distress")
foreach v in "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales" {
    drop if missing(`v')
}
* Use stored estimates from training
est restore lpm2
predict double yhat_lpm_te, xb
est restore logit2
predict double yhat_logit_te, pr
est restore probit2
predict double yhat_probit_te, pr

* AUC for test (continuous)
roctab "Financial Distress" yhat_lpm_te, detail
scalar AUC_LPM_te_c = r(area)
roctab "Financial Distress" yhat_logit_te, detail
scalar AUC_LOG_te_c = r(area)
roctab "Financial Distress" yhat_probit_te, detail
scalar AUC_PRO_te_c = r(area)

* AUC for test (binary, cutoff 0.5)
gen byte yhat_lpm_bin = yhat_lpm_te>=0.5
gen byte yhat_logit_bin = yhat_logit_te>=0.5
gen byte yhat_probit_bin = yhat_probit_te>=0.5
roctab "Financial Distress" yhat_lpm_bin
scalar AUC_LPM_te_b = r(area)
roctab "Financial Distress" yhat_logit_bin
scalar AUC_LOG_te_b = r(area)
roctab "Financial Distress" yhat_probit_bin
scalar AUC_PRO_te_b = r(area)

* Summary of predicted values
list yhat_lpm_te yhat_lpm_bin yhat_logit_te yhat_logit_bin yhat_probit_te yhat_probit_bin in 1/15, abbreviate(24)

* -----------------------------
* ROC curves (test sample): compare continuous and binary for each model
roccomp "Financial Distress" yhat_lpm_te yhat_logit_te yhat_probit_te, graph name(roc_cont, replace) title("Figure 12 - ROC (continuous)")
roccomp "Financial Distress" yhat_lpm_bin yhat_logit_bin yhat_probit_bin, graph name(roc_bin, replace) title("Figure 12 - ROC (binary)")

* -----------------------------
* Standardized Pearson residuals per model (training sample), refit glm to get leverage
use `train', clear
drop if missing("Financial Distress")
foreach v in "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales" {
    drop if missing(`v')
}

* LPM
est restore lpm2
predict double phat_lpm_tr = yhat_lpm_tr, replace
predict double hat_lpm, hat
gen double pearson_lpm = ("Financial Distress" - phat_lpm_tr)/sqrt(phat_lpm_tr*(1-phat_lpm_tr) + 1e-8)
gen double stdres_lpm = pearson_lpm/sqrt(1 - hat_lpm)

* Logit via glm to access leverage
glm "Financial Distress" "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales", family(binomial) link(logit)
predict double phat_logit_tr, mu
predict double pearson_logit, pearson
predict double hat_logit, hat
gen double stdres_logit = pearson_logit/sqrt(1 - hat_logit)

* Probit via glm to access leverage
glm "Financial Distress" "Debt/Assets" "Income/Assets" "Current Assets/Liabilities" "Market Value Equity/Long-Term Debt" "Inventory/Sales", family(binomial) link(probit)
predict double phat_probit_tr, mu
predict double pearson_probit, pearson
predict double hat_probit, hat
gen double stdres_probit = pearson_probit/sqrt(1 - hat_probit)

* Density plots by cluster
twoway (kdensity stdres_lpm if "Financial Distress"==1, lcolor(red) fcolor(red%30)) ///
       (kdensity stdres_lpm if "Financial Distress"==0, lcolor(blue) fcolor(blue%30)), ///
       title("Linear Probability (LPM)") name(res_lpm, replace)
twoway (kdensity stdres_logit if "Financial Distress"==1, lcolor(red) fcolor(red%30)) ///
       (kdensity stdres_logit if "Financial Distress"==0, lcolor(blue) fcolor(blue%30)), ///
       title("Logit") name(res_logit, replace)
twoway (kdensity stdres_probit if "Financial Distress"==1, lcolor(red) fcolor(red%30)) ///
       (kdensity stdres_probit if "Financial Distress"==0, lcolor(blue) fcolor(blue%30)), ///
       title("Probit") name(res_probit, replace)

* Outliers threshold
local outthr = 2

* Outliers tables
preserve
keep if abs(stdres_lpm) > `outthr'
gen str20 side = cond(stdres_lpm>0,"Positive extreme","Negative extreme")
gen str12 cluster = cond("Financial Distress"==1,"FD (yd=1)","NFD (yd=0)")
gen long obs_index = _n
list stdres_lpm side cluster obs_index, abbreviate(24)
restore

preserve
keep if abs(stdres_logit) > `outthr'
gen str20 side = cond(stdres_logit>0,"Positive extreme","Negative extreme")
gen str12 cluster = cond("Financial Distress"==1,"FD (yd=1)","NFD (yd=0)")
gen long obs_index = _n
list stdres_logit side cluster obs_index, abbreviate(24)
restore

preserve
keep if abs(stdres_probit) > `outthr'
gen str20 side = cond(stdres_probit>0,"Positive extreme","Negative extreme")
gen str12 cluster = cond("Financial Distress"==1,"FD (yd=1)","NFD (yd=0)")
gen long obs_index = _n
list stdres_probit side cluster obs_index, abbreviate(24)
restore

* -----------------------------
* Best threshold minimizing expected loss (private banker profile)
use `test', clear
drop if missing("Financial Distress")
est restore lpm2
predict double s_lpm_c, xb
est restore logit2
predict double s_logit_c, pr
est restore probit2
predict double s_probit_c, pr
gen byte s_lpm_b = s_lpm_c>=0.5
gen byte s_logit_b = s_logit_c>=0.5
gen byte s_probit_b = s_probit_c>=0.5

summ "Financial Distress"
scalar fd_ratio = r(mean)
scalar nfd_ratio = 1 - fd_ratio
scalar cost_FP = 0.1
scalar cost_FN = 0.2

program define bestthr, rclass
    syntax varlist(min=2 max=2)
    tempname area
    roctab `varlist', detail
    tempvar thr fpr tpr eloss
    gen double `thr' = r(cutoff)
    gen double `tpr' = r(sensitivity)
    gen double `fpr' = 1 - r(specificity)
    gen double `eloss' = `fpr'*nfd_ratio*cost_FP + (1-`tpr')*fd_ratio*cost_FN
    sort `eloss'
    return scalar thr = `thr'[1]
    return scalar eloss = `eloss'[1]
    return scalar fpr = `fpr'[1]
    return scalar tpr = `tpr'[1]
end

quietly bestthr "Financial Distress" s_lpm_c
display as text "LPM best threshold: " %6.4f r(thr) " | Min ELoss=" %6.4f r(eloss) " | FPR=" %6.4f r(fpr) " | TPR=" %6.4f r(tpr)
quietly bestthr "Financial Distress" s_logit_c
display as text "Logit best threshold: " %6.4f r(thr) " | Min ELoss=" %6.4f r(eloss) " | FPR=" %6.4f r(fpr) " | TPR=" %6.4f r(tpr)
quietly bestthr "Financial Distress" s_probit_c
display as text "Probit best threshold: " %6.4f r(thr) " | Min ELoss=" %6.4f r(eloss) " | FPR=" %6.4f r(fpr) " | TPR=" %6.4f r(tpr)

* Sensitivity/Specificity vs Probability Cutoff (example: Logit)
tempfile rocgrid
roctab "Financial Distress" s_lpm_c, detail
preserve
keep r(cutoff) r(sensitivity) r(specificity)
rename (r(cutoff) r(sensitivity) r(specificity)) (cut sens spec)
sort cut
twoway (line sens cut) (line spec cut), title("Figure 14 - Sensitivity/Specificity vs Cutoff (LPM)") legend(order(1 "Sensitivity" 2 "Specificity")) name(ss_lpm, replace)
restore

roctab "Financial Distress" s_logit_c, detail
preserve
keep r(cutoff) r(sensitivity) r(specificity)
rename (r(cutoff) r(sensitivity) r(specificity)) (cut sens spec)
sort cut
twoway (line sens cut) (line spec cut), title("Figure 15 - Sensitivity/Specificity vs Cutoff (Logit)") legend(order(1 "Sensitivity" 2 "Specificity")) name(ss_logit, replace)
restore

roctab "Financial Distress" s_probit_c, detail
preserve
keep r(cutoff) r(sensitivity) r(specificity)
rename (r(cutoff) r(sensitivity) r(specificity)) (cut sens spec)
sort cut
twoway (line sens cut) (line spec cut), title("Figure 16 - Sensitivity/Specificity vs Cutoff (Probit)") legend(order(1 "Sensitivity" 2 "Specificity")) name(ss_probit, replace)
restore

* -----------------------------
* Dummy Trap Analysis
use `train', clear
gen byte yd = "Financial Distress"
gen byte ynd = 1 - yd
gen double tdta = "Debt/Assets"

* Model 1: tdta on yd + ynd + constant (collinearity expected)
capture noisily regress tdta yd ynd
eststo tdta_m1

* Model 2: tdta on yd + constant
regress tdta yd
eststo tdta_m2

* Model 3: tdta on ynd + constant
regress tdta ynd
eststo tdta_m3

* Model 4: constrained (yd + ynd = 0) via cnsreg
constraint drop _all
constraint 1 _b[yd] + _b[ynd] = 0
cnsreg tdta yd ynd, constraint(1)
eststo tdta_m4

esttab tdta_m1 tdta_m2 tdta_m3 tdta_m4, se b(%9.4f) star(* 0.05 ** 0.01 *** 0.001) label ///
      title("Debt-to-Assets Regression Results: Dummy Trap Comparison") ///
      mlabels("Model 1: yd + ynd" "Model 2: yd" "Model 3: ynd" "Model 4: Restricted yd + ynd")

* -----------------------------
* End of script
display as result "Done."
