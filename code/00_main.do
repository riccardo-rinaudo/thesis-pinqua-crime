* 00_main.do
* Esegue l'intera analisi nell'ordine corretto.
* Prima di lanciarlo, impostare $root con il percorso della cartella del progetto.
* Struttura attesa:
*   $root/code          -> questi script
*   $root/Dataset       -> file grezzi (CSV/XLSX, non inclusi nel repository)
*   $root/Dataset_dta   -> file .dta e output (creati dagli script)

clear all
set more off

global root "CAMBIARE/CON/IL/PERCORSO/DEL/PROGETTO"
global raw "$root/Dataset"
global clean "$root/Dataset_dta"

do "$root/code/01_cleaning_dataset.do"
do "$root/code/02_regressions.do"
do "$root/code/03_microcriminality.do"
do "$root/code/04_subanalysis_migrants.do"
do "$root/code/05_graphs.do"