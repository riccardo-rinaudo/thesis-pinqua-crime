*Sottoanalisi_Migranti.do
*Qua lavoriamo sulla sotto-analisi di eterogeneità per quota di popolazione migrante
clear all
set more off
* I percorsi ($root, $raw, $clean) sono definiti in 00_main.do
if "$root" == "" {
    display as error "Eseguire prima 00_main.do (imposta i percorsi)"
    exit 198
}
ssc install estout, replace

** PULIZIA DATI MIGRANTI (IstatData - Stranieri residenti al 1° gennaio) **
import delimited "$raw/stranieri_residenti.csv", clear varnames(1) stringcols(_all) encoding(utf8) delimiter(",") bindquotes(nobind) maxquotedrows(1000)

rename territorio provincia
rename time_period anno
rename osservazione stranieri

destring anno, replace
destring stranieri, replace ignore(".")

* teniamo solo 2019-2024 (2025-2026 sono stime, contrassegnate obs_status = "e")
keep if anno >= 2019 & anno <= 2024

keep provincia anno stranieri

* stesse correzioni nomi già usate per gli altri dataset
replace provincia = "L'Aquila" if strpos(provincia, "Aquila") > 0
replace provincia = "Reggio nell'Emilia" if strpos(provincia, "Reggio nell") > 0
replace provincia = "Valle d'Aosta/Vallée d'Aoste" if strpos(provincia, "Valle") > 0 & strpos(provincia, "Aosta") > 0
replace provincia = "Bolzano/Bozen" if strpos(provincia, "Bolzano") > 0
replace provincia = "Reggio Calabria" if provincia == "Reggio di Calabria"
replace provincia = "Trento" if provincia == "Provincia Autonoma Trento"
replace provincia = "Sud Sardegna" if strpos(provincia, "Sardegna") > 0
merge m:1 provincia using "$clean/istat_codici_prov_pulito.dta"
tab _merge
keep if _merge == 3
drop _merge

destring cod_prov, replace
duplicates drop cod_prov anno, force
isid cod_prov anno

save "$clean/stranieri_province_panel.dta", replace

** COSTRUZIONE QUOTA MIGRANTI (baseline 2020, coerente con baseline_crimine/baseline_micro) **
keep if anno == 2020
rename stranieri stranieri_2020
drop anno

save "$clean/stranieri_2020.dta", replace

** MERGE NEL PANEL PRINCIPALE **
use "$clean/panel_finale_pinqua_crimine.dta", clear
merge m:1 cod_prov using "$clean/stranieri_2020.dta"
tab _merge
keep if _merge == 3
drop _merge

gen quota_migranti = (stranieri_2020 / popolazione) * 100 if anno == 2020
bysort cod_prov: egen quota_migranti_base = max(quota_migranti)
drop quota_migranti

** SPLIT CAMPIONE SOPRA/SOTTO MEDIANA **
summ quota_migranti_base, detail
gen alta_quota_migranti = quota_migranti_base > r(p50)
label define gruppo 0 "Bassa quota migranti" 1 "Alta quota migranti"
label values alta_quota_migranti gruppo

tab alta_quota_migranti

save "$clean/panel_migranti.dta", replace

** REGRESSIONI SEPARATE PER SOTTOGRUPPO **
xtset cod_prov anno

eststo migr_bassa: xtreg tasso_crimine trattamento i.anno if alta_quota_migranti==0, fe vce(cluster cod_prov)
eststo migr_alta:  xtreg tasso_crimine trattamento i.anno if alta_quota_migranti==1, fe vce(cluster cod_prov)

esttab migr_bassa migr_alta using "$clean/regression_table_migranti.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) label booktabs keep(trattamento) ///
	varlabels(trattamento "Exposure × Post") ///
    mtitles("Bassa quota migranti" "Alta quota migranti") ///
    title("Effect of PINQuA on Crime by Migrant Population Share") ///
    stats(N r2, labels("Observations" "R-squared"))