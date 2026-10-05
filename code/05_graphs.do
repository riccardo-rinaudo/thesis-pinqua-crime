* 05_graphs.do
*Qua generiamo i grafici descrittivi e di sintesi per la tesi
clear all
set more off
* I percorsi ($root, $raw, $clean) sono definiti in 00_main.do
if "$root" == "" {
    display as error "Eseguire prima 00_main.do (imposta i percorsi)"
    exit 198
}
ssc install coefplot, replace

** CARICAMENTO PANEL FINALE (già pronto da 02_regressions.do) **
use "$clean/panel_regressioni.dta", clear
xtset cod_prov anno

** HISTOGRAM: DISTRIBUZIONE EXPOSURE TRA PROVINCE FINANZIATE (2020) **
preserve
keep if anno == 2020 & trattato == 1

histogram pinqua_pc, bin(15) frequency ///
    xtitle("PINQuA exposure per capita (EUR)") ///
    ytitle("Number of provinces") ///
    color(navy%70) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    title("")

graph export "$clean/grafico_histogram_exposure.pdf", replace
restore

** RISTIMA DEI 5 MODELLI A EXPOSURE CONTINUA (necessari per il coefplot) **
eststo clear
eststo m1: xtreg tasso_crimine trattamento i.anno, fe vce(cluster cod_prov)
eststo m7: xtreg tasso_crimine trattamento baseline_x_post i.anno, fe vce(cluster cod_prov)
eststo m8: xtreg tasso_crimine trattamento pil i.anno, fe vce(cluster cod_prov)
eststo m9: xtreg tasso_crimine trattamento disoccupazione i.anno, fe vce(cluster cod_prov)
eststo m10: xtreg tasso_crimine trattamento baseline_x_post pil disoccupazione i.anno, fe vce(cluster cod_prov)

coefplot (m1, keep(trattamento) rename(trattamento = "Baseline")) ///
         (m7, keep(trattamento) rename(trattamento = "+ Baseline crime")) ///
         (m8, keep(trattamento) rename(trattamento = "+ GDP")) ///
         (m9, keep(trattamento) rename(trattamento = "+ Unemployment")) ///
         (m10, keep(trattamento) rename(trattamento = "+ All controls")), ///
    vertical ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    ciopts(recast(rcap) lcolor(navy)) ///
    mcolor(navy) ///
    xtitle("") ytitle("Estimated effect (Exposure × Post)") ///
    legend(off) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    title("")

graph export "$clean/grafico_coefplot_controls.pdf", replace

** QUOTA PROGETTI PER MACROAREA (deduplicati, con codici armonizzati) **
use "$clean/pinqua_territori.dta", clear

* stessa armonizzazione codici usata in 01_cleaning_dataset.do
replace cod_prov = "201" if cod_prov == "001"   // Torino
replace cod_prov = "210" if cod_prov == "010"   // Genova
replace cod_prov = "215" if cod_prov == "015"   // Milano
replace cod_prov = "227" if cod_prov == "027"   // Venezia
replace cod_prov = "237" if cod_prov == "037"   // Bologna
replace cod_prov = "248" if cod_prov == "048"   // Firenze
replace cod_prov = "258" if cod_prov == "058"   // Roma
replace cod_prov = "263" if cod_prov == "063"   // Napoli
replace cod_prov = "272" if cod_prov == "072"   // Bari
replace cod_prov = "280" if cod_prov == "080"   // Reggio Calabria
replace cod_prov = "282" if cod_prov == "082"   // Palermo
replace cod_prov = "283" if cod_prov == "083"   // Messina
replace cod_prov = "287" if cod_prov == "087"   // Catania
replace cod_prov = "318" if cod_prov == "092"   // Cagliari
replace cod_prov = "312" if cod_prov == "090"   // Sassari
replace cod_prov = "088" if cod_prov == "095"   // Ragusa

gen cod_prov_num = real(cod_prov)

gen macroarea = ""
replace macroarea = "North" if inlist(cod_prov_num, 2,3,4,5,6,7,8,9,11,12,13,14,16,17,18,19,20,21,22,23,24,25,26,28,29,30,31,32,33,34,35,36,38,39,40,93,96,97,98,99,103,108,201,210,215,227,237)
replace macroarea = "Center" if inlist(cod_prov_num, 41,42,43,44,45,46,47,49,50,51,52,53,54,55,56,57,59,60,100,109,248,258)
replace macroarea = "South" if inlist(cod_prov_num, 61,62,64,65,66,67,68,69,70,71,73,74,75,76,77,78,79,81,84,85,86,88,89,94,101,102,110,114,115,263,272,280,282,283,287,312,318)

* controllo: non deve restare nessuna riga senza macroarea
count if macroarea == ""
assert macroarea != ""

egen tag_cup = tag(cup)
keep if tag_cup == 1
contract macroarea
egen tot_projects = total(_freq)
gen project_share = (_freq / tot_projects) * 100
keep macroarea project_share
save "$clean/macroarea_projects.dta", replace

** QUOTA PAGAMENTI PER MACROAREA **
use "$clean/panel_regressioni.dta", clear
keep if anno == 2020

gen macroarea = ""
replace macroarea = "North" if inlist(cod_prov, 2,3,4,5,6,7,8,9,11,12,13,14,16,17,18,19,20,21,22,23,24,25,26,28,29,30,31,32,33,34,35,36,38,39,40,93,96,97,98,99,103,108,201,210,215,227,237)
replace macroarea = "Center" if inlist(cod_prov, 41,42,43,44,45,46,47,49,50,51,52,53,54,55,56,57,59,60,100,109,248,258)
replace macroarea = "South" if inlist(cod_prov, 61,62,64,65,66,67,68,69,70,71,73,74,75,76,77,78,79,81,84,85,86,88,89,94,101,102,110,114,115,263,272,280,282,283,287,312,318)

collapse (sum) pagamenti_pinqua_prov, by(macroarea)
egen tot_pay = total(pagamenti_pinqua_prov)
gen payment_share = (pagamenti_pinqua_prov / tot_pay) * 100
keep macroarea payment_share

merge 1:1 macroarea using "$clean/macroarea_projects.dta"
drop _merge

** GRAFICO A BARRE AFFIANCATE: PROGETTI vs PAGAMENTI **
graph bar payment_share project_share, over(macroarea, sort(payment_share) descending) ///
    legend(label(1 "Share of payments") label(2 "Share of projects")) ///
    ytitle("Share (%)") ///
    bar(1, color(navy%70)) bar(2, color(orange%70)) ///
    blabel(bar, format(%4.1f)) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    title("")

graph export "$clean/grafico_bar_macroarea.pdf", replace

list macroarea payment_share project_share