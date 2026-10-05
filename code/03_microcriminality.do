*Sottoanalisi_Microcriminalita.do
*Qua lavoriamo sulla sotto-analisi per tipologia di reato (microcriminalità)
clear all
set more off
* I percorsi ($root, $raw, $clean) sono definiti in 00_main.do
if "$root" == "" {
    display as error "Eseguire prima 00_main.do (imposta i percorsi)"
    exit 198
}
ssc install estout, replace

** PULIZIA DEI QUATTRO DATASET DI TIPOLOGIA DI REATO **
foreach tipo in furti rapine danneggiamenti estorsioni {
    import delimited "$raw/criminalita_`tipo'.csv", clear varnames(1) stringcols(_all) encoding(utf8) delimiter(",") bindquotes(nobind) maxquotedrows(1000)

    * escludiamo il livello comunale (codici REF_AREA numerici), teniamo solo il livello provinciale (codici NUTS che iniziano con "IT")
    keep if strpos(ref_area, "IT") == 1

    keep territorio time_period osservazione
    rename territorio provincia
    rename time_period anno
    rename osservazione reati_`tipo'

    destring anno, replace
    destring reati_`tipo', replace

    replace provincia = "L'Aquila" if strpos(provincia, "Aquila") > 0
    replace provincia = "Reggio nell'Emilia" if strpos(provincia, "Reggio nell") > 0
    replace provincia = "Valle d'Aosta/Vallée d'Aoste" if strpos(provincia, "Valle") > 0 & strpos(provincia, "Aosta") > 0
    replace provincia = "Bolzano/Bozen" if strpos(provincia, "Bolzano") > 0
    replace provincia = "Reggio Calabria" if provincia == "Reggio di Calabria"
    replace provincia = "Trento" if provincia == "Provincia Autonoma Trento"

    merge m:1 provincia using "$clean/istat_codici_prov_pulito.dta"
    tab _merge
    keep if _merge == 3
    drop _merge

    destring cod_prov, replace
    duplicates drop cod_prov anno, force
    isid cod_prov anno

    save "$clean/criminalita_`tipo'_panel.dta", replace
}

** MERGE CON IL PANEL PRINCIPALE GIÀ PRONTO **
use "$clean/panel_finale_pinqua_crimine.dta", clear
foreach tipo in furti rapine danneggiamenti estorsioni {
    merge 1:1 cod_prov anno using "$clean/criminalita_`tipo'_panel.dta"
    tab _merge
    drop _merge
}

gen reati_micro = reati_furti + reati_rapine + reati_danneggiamenti
gen tasso_micro = (reati_micro / popolazione) * 100000

gen tasso_furti = (reati_furti / popolazione) * 100000
gen tasso_rapine = (reati_rapine / popolazione) * 100000
gen tasso_danneggiamenti = (reati_danneggiamenti / popolazione) * 100000
gen tasso_estorsioni = (reati_estorsioni / popolazione) * 100000

gen trattato = pagamenti_pinqua_prov > 0
gen did = trattato * post

save "$clean/panel_microcriminalita.dta", replace

** REGRESSIONI SULLA MICROCRIMINALITÀ **
xtset cod_prov anno

* Baseline specifico per micro-criminalità (coerente con baseline_x_post del modello principale)
gen micro_2020 = tasso_micro if anno == 2020
bysort cod_prov: egen baseline_micro = max(micro_2020)
drop micro_2020
gen baseline_micro_x_post = baseline_micro * post

eststo micro1: xtreg tasso_micro trattamento i.anno, fe vce(cluster cod_prov)
eststo micro2: xtreg tasso_micro did i.anno, fe vce(cluster cod_prov)
eststo micro3: xtreg tasso_micro trattamento baseline_micro_x_post i.anno, fe vce(cluster cod_prov)
eststo micro4: xtreg tasso_micro trattamento pil i.anno, fe vce(cluster cod_prov)
eststo micro5: xtreg tasso_micro trattamento disoccupazione i.anno, fe vce(cluster cod_prov)
eststo micro6: xtreg tasso_micro trattamento baseline_micro_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)

esttab micro1 micro2 micro3 micro4 micro5 micro6 using "$clean/regression_table_micro.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) label booktabs ///
    varlabels(trattamento "Exposure × Post" did "Treated × Post" ///
              baseline_micro_x_post "Baseline micro-crime × Post" ///
              pil "Provincial GDP" disoccupazione "Unemployment rate") ///
    title("Effect of PINQuA on Micro-Crime") stats(N r2, labels("Observations" "R-squared"))

** ROBUSTNESS: STESSO CAMPIONE DI micro6 SU TUTTE LE SPECIFICAZIONI **
xtreg tasso_micro trattamento baseline_micro_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)
gen sample_micro6 = e(sample)
count if sample_micro6 == 1

eststo rm1: xtreg tasso_micro trattamento i.anno if sample_micro6==1, fe vce(cluster cod_prov)
eststo rm3: xtreg tasso_micro trattamento baseline_micro_x_post i.anno if sample_micro6==1, fe vce(cluster cod_prov)
eststo rm4: xtreg tasso_micro trattamento pil i.anno if sample_micro6==1, fe vce(cluster cod_prov)
eststo rm5: xtreg tasso_micro trattamento disoccupazione i.anno if sample_micro6==1, fe vce(cluster cod_prov)

esttab rm1 rm3 rm4 rm5 micro6, se star(* 0.10 ** 0.05 *** 0.01) label ///
    varlabels(trattamento "Exposure × Post" ///
              baseline_micro_x_post "Baseline micro-crime × Post" pil "Provincial GDP" ///
              disoccupazione "Unemployment rate") ///
    stats(N r2, labels("Observations" "R-squared")) ///
    mtitles("Base (restr.)" "+Baseline" "+GDP" "+Disocc" "Tutti (micro6)")
	
** REGRESSIONI DISAGGREGATE PER TIPO DI REATO **
foreach tipo in furti rapine danneggiamenti {
    gen `tipo'_2020 = tasso_`tipo' if anno == 2020
    bysort cod_prov: egen baseline_`tipo' = max(`tipo'_2020)
    drop `tipo'_2020
    gen baseline_`tipo'_x_post = baseline_`tipo' * post

    eststo `tipo'1: xtreg tasso_`tipo' trattamento i.anno, fe vce(cluster cod_prov)
    eststo `tipo'2: xtreg tasso_`tipo' did i.anno, fe vce(cluster cod_prov)
    eststo `tipo'3: xtreg tasso_`tipo' trattamento baseline_`tipo'_x_post i.anno, fe vce(cluster cod_prov)
    eststo `tipo'4: xtreg tasso_`tipo' trattamento pil i.anno, fe vce(cluster cod_prov)
    eststo `tipo'5: xtreg tasso_`tipo' trattamento disoccupazione i.anno, fe vce(cluster cod_prov)
    eststo `tipo'6: xtreg tasso_`tipo' trattamento baseline_`tipo'_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)

    esttab `tipo'1 `tipo'2 `tipo'3 `tipo'4 `tipo'5 `tipo'6 using "$clean/regression_table_`tipo'.tex", replace ///
        se star(* 0.10 ** 0.05 *** 0.01) label booktabs ///
        varlabels(trattamento "Exposure × Post" did "Treated × Post" ///
                  baseline_`tipo'_x_post "Baseline `tipo' × Post" ///
                  pil "Provincial GDP" disoccupazione "Unemployment rate") ///
        title("Effect of PINQuA on `tipo'") stats(N r2, labels("Observations" "R-squared"))
}

** TABELLA DI SINTESI: EFFETTO SU AGGREGATO VS SINGOLI REATI **
esttab micro1 furti1 rapine1 danneggiamenti1 using "$clean/confronto_tipo_reato_base.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) label booktabs keep(trattamento) ///
	varlabels(trattamento "Exposure × Post") ///
    mtitles("Micro (aggregato)" "Furti" "Rapine" "Danneggiamenti") ///
    title("Treatment Effect by Crime Type — Baseline Specification") ///
    stats(N r2, labels("Observations" "R-squared"))

esttab micro6 furti6 rapine6 danneggiamenti6 using "$clean/confronto_tipo_reato_full.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) label booktabs keep(trattamento baseline_micro_x_post) ///
	varlabels(trattamento "Exposure × Post" baseline_micro_x_post "Baseline micro-crime × Post") ///
    mtitles("Micro (aggregato)" "Furti" "Rapine" "Danneggiamenti") ///
    title("Treatment Effect by Crime Type — Full Controls") ///
    stats(N r2, labels("Observations" "R-squared"))