* Pulizia dei dataset: li rende leggibili e utilizzabili in Stata
clear all
set more off
* I percorsi ($root, $raw, $clean) sono definiti in 00_main.do
if "$root" == "" {
    display as error "Eseguire prima 00_main.do (imposta i percorsi)"
    exit 198
}

**Dataset PINQua
**Progetti
import delimited "$raw/progetti.csv", clear
describe

keep if codice_misura == "M5C2I2.03.01"
keep progetto_id cup codice_misura titolo

duplicates report cup
duplicates drop cup, force

count
save "$clean/pinqua_progetti.dta", replace

*Pagamenti 
import delimited "$raw/progetti_pagamenti.csv", clear
describe

keep cup pagamento_pnrr
keep if pagamento_pnrr > 0

merge m:1 cup using "$clean/pinqua_progetti.dta"
keep if _merge == 3
drop _merge

collapse (sum) pagamento_pnrr, by(cup)
save "$clean/pinqua_pagamenti.dta", replace

*Territori
import delimited "$raw/progetti_territori.csv", clear

keep if tipologia == "C"

merge m:1 cup using "$clean/pinqua_progetti.dta"
keep if _merge == 3
drop _merge

gen cod_comune = string(istat_id, "%06.0f")
gen cod_prov = substr(cod_comune, 1, 3)

keep cup cod_comune cod_prov denominazione
save "$clean/pinqua_territori.dta", replace

*Sistemiamo il problema dei duplicati dividendo i pagamenti per comuni 
use "$clean/pinqua_pagamenti.dta", clear

merge 1:m cup using "$clean/pinqua_territori.dta"
keep if _merge == 3
drop _merge

bysort cup: gen n_comuni = _N
gen pagamento_comune = pagamento_pnrr / n_comuni

collapse (sum) pagamento_comune, by(cod_prov)
rename pagamento_comune pagamenti_pinqua_prov
* Armonizzazione codici PINQuA → ISTAT
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

save "$clean/pinqua_provincia.dta", replace
*Colleghiamo con i codici provincia e province
import excel "$raw/istat_codici_prov_pulito.xlsx", firstrow clear
describe
drop if missing(cod_prov)
duplicates drop cod_prov, force
count
save "$clean/istat_codici_prov_pulito.dta", replace

merge 1:1 cod_prov using "$clean/pinqua_provincia.dta"
tab _merge
assert _merge != 2 
replace pagamenti_pinqua_prov = 0 if _merge == 1
drop _merge
destring cod_prov, replace

save "$clean/province_pinqua_completo.dta", replace

*DATASET ISTAT

*CRIMINALITA
 import delimited "$raw/criminalita.csv", clear varnames(1) stringcols(_all) encoding(utf8) delimiter(",") bindquotes(nobind) maxquotedrows(1000)
list territorio tipodidelitto time_period osservazione in 1/10
describe 

keep if type_crime == "TOT"
keep if tipodidelitto == "Totale"

rename territorio provincia
rename time_period anno
rename osservazione reati
keep provincia anno reati

destring anno, replace
destring reati, replace ignore(".")

list provincia anno reati in 1/20
summ anno reati 
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

order cod_prov provincia anno reati 
sort cod_prov anno 
list cod_prov provincia anno reati in 1/20 
destring cod_prov, replace
duplicates drop cod_prov anno, force
isid cod_prov anno
save "$clean/criminalita_province_panel.dta", replace 

*POPOLAZIONE 
clear

import delimited "$raw/pop_2019.csv", clear varnames(1) encoding(utf8)
gen anno = 2019
save "$clean/pop_panel.dta", replace

foreach y in 2020 2021 2022 2023 2024 {
    import delimited "$raw/pop_`y'.csv", clear varnames(1) encoding(utf8)
    gen anno = `y'
    append using "$clean/pop_panel.dta"
    save "$clean/pop_panel.dta", replace
}

rename totale popolazione

keep provincia anno popolazione

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
keep cod_prov provincia anno popolazione
sort cod_prov anno
duplicates drop cod_prov anno, force
isid cod_prov anno

save "$clean/popolazione_province_panel.dta", replace


*PIL PROVINCIALE
import delimited "$raw/pil_province.csv", clear varnames(1) stringcols(_all) encoding(utf8) delimiter(",") bindquotes(nobind) maxquotedrows(1000)

keep territorio time_period osservazione
rename territorio provincia
rename time_period anno
rename osservazione pil

destring anno, replace
destring pil, replace ignore(".")

* togliamo il 2024 per tutti, per coerenza (mancante per quasi tutte le province)
drop if anno == 2024

* stesse correzioni nomi già usate per criminalità e popolazione
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

save "$clean/pil_province_panel.dta", replace

*DISOCCUPAZIONE PROVINCIALE
import delimited "$raw/disoccupazione_province.csv", clear varnames(1) stringcols(_all) encoding(utf8) delimiter(",") bindquotes(nobind) maxquotedrows(1000)

keep if sesso == "Totale"
keep territorio time_period osservazione
rename territorio provincia
rename time_period anno
rename osservazione disoccupazione

destring anno, replace
destring disoccupazione, replace 

* stesse correzioni nomi già usate per gli altri dataset
replace provincia = "L'Aquila" if strpos(provincia, "Aquila") > 0
replace provincia = "Reggio nell'Emilia" if strpos(provincia, "Reggio nell") > 0
replace provincia = "Valle d'Aosta/Vallée d'Aoste" if strpos(provincia, "Valle") > 0 & strpos(provincia, "Aosta") > 0
replace provincia = "Bolzano/Bozen" if strpos(provincia, "Bolzano") > 0
replace provincia = "Reggio Calabria" if provincia == "Reggio di Calabria"
replace provincia = "Trento" if provincia == "Provincia Autonoma Trento"

* --- controllo diagnostico duplicati ---
duplicates report provincia anno
list provincia anno disoccupazione if provincia == "Valle d'Aosta/Vallée d'Aoste"
* ----------------------------------------

merge m:1 provincia using "$clean/istat_codici_prov_pulito.dta"
tab _merge
keep if _merge == 3
drop _merge

destring cod_prov, replace
duplicates drop cod_prov anno, force
isid cod_prov anno

save "$clean/disoccupazione_province_panel.dta", replace