*Qua lavoriamo sulle regressioni e gli exposure indexes
clear all 
set more off 
* I percorsi ($root, $raw, $clean) sono definiti in 00_main.do
if "$root" == "" {
    display as error "Eseguire prima 00_main.do (imposta i percorsi)"
    exit 198
}
ssc install estout, replace
ssc install coefplot, replace

** MERGE FINALE DEI DATASET **
use "$clean/criminalita_province_panel.dta", clear 

merge 1:1 cod_prov anno using "$clean/popolazione_province_panel.dta"
tab _merge 
drop _merge 
gen pop2019 = popolazione if anno == 2019
bysort cod_prov: egen pop_base = max(pop2019)
replace popolazione = pop_base if missing(popolazione)
drop pop2019 pop_base

merge 1:1 cod_prov anno using "$clean/pil_province_panel.dta"
tab _merge
drop _merge

merge 1:1 cod_prov anno using "$clean/disoccupazione_province_panel.dta"
tab _merge
drop _merge

merge m:1 cod_prov using "$clean/province_pinqua_completo.dta"
tab _merge
keep if _merge != 2
replace pagamenti_pinqua_prov = 0 if missing(pagamenti_pinqua_prov)
drop _merge

save "$clean/panel_base.dta", replace

gen pinqua_pc = pagamenti_pinqua_prov / popolazione
gen post = anno >= 2021
gen trattamento = pinqua_pc * post
gen tasso_crimine = (reati / popolazione) * 100000
label variable tasso_crimine "Crime rate"
gen crimine_2020 = tasso_crimine if anno == 2020
bysort cod_prov: egen baseline_crimine = max(crimine_2020)
drop crimine_2020
gen baseline_x_post = baseline_crimine * post

save "$clean/panel_finale_pinqua_crimine.dta", replace

summ tasso_crimine trattamento pinqua_pc
tab anno

** LINEAR REGRESSION **
xtset cod_prov anno
xtreg tasso_crimine trattamento i.anno, fe vce(cluster cod_prov)

** LOG LINEAR REGRESSION **
gen log_pinqua = log(1 + pinqua_pc)
gen tratt_log = log_pinqua * post
xtreg tasso_crimine tratt_log i.anno, fe vce(cluster cod_prov)

** CLASSIC DID **
gen trattato = pagamenti_pinqua_prov > 0
gen did = trattato * post
xtreg tasso_crimine did i.anno, fe vce(cluster cod_prov)

** LAG DEL TRATTAMENTO **
gen did_lag = trattato * (anno >= 2022)
xtreg tasso_crimine did_lag i.anno, fe vce(cluster cod_prov)

** EVENT STUDY CON LEADS (test formale di parallel trends) **
gen ev_m5 = trattato * (anno == 2016)
gen ev_m4 = trattato * (anno == 2017)
gen ev_m3 = trattato * (anno == 2018)
gen ev_m2 = trattato * (anno == 2019)
* 2020 = anno di riferimento omesso (ultimo anno pre-trattamento)
gen ev_p1 = trattato * (anno == 2021)
gen ev_p2 = trattato * (anno == 2022)
gen ev_p3 = trattato * (anno == 2023)
gen ev_p4 = trattato * (anno == 2024)

xtreg tasso_crimine ev_m5 ev_m4 ev_m3 ev_m2 ev_p1 ev_p2 ev_p3 ev_p4 i.anno, fe vce(cluster cod_prov)
eststo event_study

coefplot event_study, ///
    keep(ev_m5 ev_m4 ev_m3 ev_m2 ev_p1 ev_p2 ev_p3 ev_p4) ///
    vertical ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xline(4.5, lpattern(dash) lcolor(red)) ///
    coeflabels(ev_m5="2016" ev_m4="2017" ev_m3="2018" ev_m2="2019" ///
               ev_p1="2021" ev_p2="2022" ev_p3="2023" ev_p4="2024") ///
ciopts(recast(rcap) lcolor(navy)) ///
mcolor(navy) ///    xtitle("Year") ytitle("Effect on crime rate (per 100,000)") ///
    title("") ///
    graphregion(color(white)) plotregion(margin(small)) ///
    note("Reference year: 2020")

graph export "$clean/grafico_event_study.pdf", replace
** LOG OUTCOME **
gen log_crimine = log(tasso_crimine)
label variable log_crimine "Log(Crime rate)"
xtreg log_crimine did i.anno, fe vce(cluster cod_prov)

** PLACEBO TEST (campione ristretto a pre-2021, soglia fittizia 2019) **
gen placebo = trattato * (anno >= 2019)
xtreg tasso_crimine placebo i.anno if anno < 2021, fe vce(cluster cod_prov)

** MODELLI CON CONTROLLI (baseline crimine + PIL + disoccupazione) **
xtreg tasso_crimine trattamento baseline_x_post i.anno, fe vce(cluster cod_prov)
xtreg tasso_crimine trattamento pil i.anno, fe vce(cluster cod_prov)
xtreg tasso_crimine trattamento disoccupazione i.anno, fe vce(cluster cod_prov)
xtreg tasso_crimine trattamento baseline_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)

save "$clean/panel_regressioni.dta", replace

** TABELLA A: SUMMARY STATISTICS PANEL-LEVEL (province-anno) **
use "$clean/panel_regressioni.dta", clear

eststo clear
estpost summarize tasso_crimine pil disoccupazione pinqua_pc

esttab using "$clean/summary_stats_panel.tex", replace ///
    cells("count(label(N)) mean(fmt(2) label(Mean)) sd(fmt(2) label(SD)) min(fmt(2) label(Min)) max(fmt(2) label(Max))") ///
    label booktabs nomtitle nonumber ///
    varlabels(tasso_crimine "Crime rate (per 100,000)" ///
              pil "Provincial GDP" ///
              disoccupazione "Unemployment rate" ///
              pinqua_pc "PINQuA exposure per capita") ///
    title("Summary Statistics: Province-Year Panel")
** TABELLA B: INTENSITÀ TRATTAMENTO A LIVELLO PROVINCIA (cross-section) **
preserve
keep if anno == 2020
keep cod_prov pinqua_pc trattato

count if trattato == 1
count if trattato == 0
summ pinqua_pc if trattato == 1, detail

eststo clear
estpost summarize pinqua_pc if trattato == 1

esttab using "$clean/summary_stats_treated.tex", replace ///
    cells("count(label(N)) mean(fmt(2) label(Mean)) sd(fmt(2) label(SD)) min(fmt(2) label(Min)) max(fmt(2) label(Max))") ///
    label booktabs nomtitle nonumber ///
    varlabels(pinqua_pc "PINQuA exposure per capita (EUR)") ///
    title("PINQuA Exposure Among Treated Provinces")
restore

** TABELLA CON TUTTI I RISULTATI **
eststo clear
eststo m1: xtreg tasso_crimine trattamento i.anno, fe vce(cluster cod_prov)
eststo m2: xtreg tasso_crimine tratt_log i.anno, fe vce(cluster cod_prov)
eststo m3: xtreg tasso_crimine did i.anno, fe vce(cluster cod_prov)
eststo m4: xtreg tasso_crimine did_lag i.anno, fe vce(cluster cod_prov)
eststo m5: xtreg log_crimine did i.anno, fe vce(cluster cod_prov)
eststo m6: xtreg tasso_crimine placebo i.anno if anno < 2021, fe vce(cluster cod_prov)
eststo m7: xtreg tasso_crimine trattamento baseline_x_post i.anno, fe vce(cluster cod_prov)
eststo m8: xtreg tasso_crimine trattamento pil i.anno, fe vce(cluster cod_prov)
eststo m9: xtreg tasso_crimine trattamento disoccupazione i.anno, fe vce(cluster cod_prov)
eststo m10: xtreg tasso_crimine trattamento baseline_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)

esttab m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 using "$clean/regression_table.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) label booktabs ///
    varlabels(trattamento "Exposure × Post" tratt_log "Log Exposure × Post" ///
              did "Treated × Post" did_lag "Treated × Post (lag)" ///
              baseline_x_post "Baseline crime × Post" pil "Provincial GDP" ///
              disoccupazione "Unemployment rate" placebo "Placebo") ///
    title("Effect of PINQuA on Crime") stats(N r2, labels("Observations" "R-squared"))

** ROBUSTNESS: STESSO CAMPIONE DI m10 SU TUTTE LE SPECIFICAZIONI **
xtreg tasso_crimine trattamento baseline_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)
gen sample_m10 = e(sample)
count if sample_m10 == 1

eststo r1: xtreg tasso_crimine trattamento i.anno if sample_m10==1, fe vce(cluster cod_prov)
eststo r7: xtreg tasso_crimine trattamento baseline_x_post i.anno if sample_m10==1, fe vce(cluster cod_prov)
eststo r8: xtreg tasso_crimine trattamento pil i.anno if sample_m10==1, fe vce(cluster cod_prov)
eststo r9: xtreg tasso_crimine trattamento disoccupazione i.anno if sample_m10==1, fe vce(cluster cod_prov)

esttab r1 r7 r8 r9 m10 using "$clean/regression_table_robustness.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) label booktabs ///
    varlabels(trattamento "Exposure × Post" ///
              baseline_x_post "Baseline crime × Post" pil "Provincial GDP" ///
              disoccupazione "Unemployment rate") ///
    title("Robustness: Fixed Sample Comparison (N = 636)") ///
    stats(N r2, labels("Observations" "R-squared")) ///
	mtitles("Base" "+Baseline" "+GDP" "+Unemployment" "All")
** PARALLEL TRENDS **
preserve
collapse (mean) tasso_crimine, by(anno trattato)

twoway ///
    (line tasso_crimine anno if trattato==1, lwidth(medthick)) ///
    (line tasso_crimine anno if trattato==0, lpattern(dash) lwidth(medium)), ///
    legend(order(1 "Treated provinces" 2 "Control provinces") ///
           position(6) ring(0) cols(1) size(small) region(lstyle(none))) ///
    title("") ///
    xtitle("Year", size(medsmall)) ///
    ytitle("Crime rate (per 100,000 inhabitants)", size(medsmall)) ///
    xlabel(2015(1)2024, labsize(small)) ///
    ylabel(2500(500)4000, labsize(small)) ///
    graphregion(color(white)) ///
    plotregion(margin(small)) ///
    bgcolor(white)

graph export "$clean/grafico_parallel_trends.pdf", replace
restore