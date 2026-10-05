# Housing, Urban Regeneration, and Crime
### A province-level analysis of Italy's PINQuA program

Stata code for my Bachelor thesis in Economic and Social Sciences (Bocconi University, 2026).

## Research question

Is provincial exposure to PINQuA funding associated with a change in the provincial crime rate?

PINQuA (*Programma Innovativo Nazionale per la Qualità dell'Abitare*) is an Italian program for social housing and urban regeneration, funded by the 2020 Budget Law and later incorporated into the National Recovery and Resilience Plan (PNRR, Mission 5, Component 2, Investment 2.3). About EUR 2.8 billion went to 159 selected projects.

## Main finding

Across all specifications and sub-analyses, I find **no robust evidence of a systematic association** between PINQuA exposure and provincial crime rates over 2015-2024.

- Baseline estimate: 0.513 (s.e. 0.593), not statistically significant. The 95% confidence interval runs from about -0.65 to +1.68, so the estimates are imprecise.
- The only marginally significant estimate (0.970, s.e. 0.566, 10% level) appears when all three controls are included jointly. It does not appear when each control is added separately on the same restricted sample (N = 636).
- The placebo test and the event study show no evidence of differential pre-trends.
- Results are unchanged when crime is split by offense type (thefts, robberies, property damage) and when provinces are split by migrant population share (a descriptive comparison, not a formal interaction test).

A null result at the province level does not rule out effects at a finer geographic scale. The thesis discusses this, along with the short post-treatment window, limits to statistical precision, and the fact that payments are an imperfect proxy for completed projects.

## Method

- **Panel:** 106 of Italy's 107 provinces, 2015-2024 (1,060 province-year observations). Sud Sardegna is excluded because it cannot be matched across data sources.
- **Specification:** continuous-intensity difference-in-differences with province and year fixed effects, standard errors clustered by province.
- **Treatment:** PINQuA payments per capita, interacted with a post-2021 indicator.
- **Outcome:** reported crimes per 100,000 inhabitants.
- **Robustness:** log-transformed exposure, binary treatment, lagged binary treatment, log outcome, placebo test (fictitious threshold at 2019, pre-2021 sample), event study with 2020 as reference year, additional controls (baseline crime x post, provincial GDP, unemployment rate), and a fixed-sample comparison.
- **Supplementary analyses:** micro-crime and offense-specific rates; heterogeneity by baseline migrant population share (above vs. below median, 2020).

Staggered-adoption estimators (Callaway and Sant'Anna; Sun and Abraham) are not used because province-level treatment timing cannot be reconstructed from the available payment data.

## Data

The raw data are **not included** in this repository. The scripts expect these files in `Dataset/`:

| Data | Source | Expected files |
|---|---|---|
| PINQuA projects, payments, territories | OpenPNRR | `progetti.csv`, `progetti_pagamenti.csv`, `progetti_territori.csv` |
| Province code crosswalk | built by hand from ISTAT codes | `istat_codici_prov_pulito.xlsx` |
| Reported crimes (total and by offense) | ISTAT, IstatData | `criminalita.csv`, `criminalita_furti.csv`, `criminalita_rapine.csv`, `criminalita_danneggiamenti.csv`, `criminalita_estorsioni.csv` |
| Resident population | ISTAT, IstatData | `pop_2019.csv` ... `pop_2024.csv` |
| Provincial GDP | ISTAT, IstatData | `pil_province.csv` |
| Unemployment rate | ISTAT, IstatData | `disoccupazione_province.csv` |
| Resident foreign population | ISTAT, IstatData | `stranieri_residenti.csv` |

PINQuA projects are identified by the PNRR measure code `M5C2I2.03.01`.

## Repository structure

```
code/
  00_main.do                  sets paths and runs everything in order
  01_cleaning_dataset.do      cleans PINQuA and ISTAT data
  02_regressions.do           merges the panel, main regressions, robustness, event study
  03_microcriminality.do      offense-specific analysis
  04_subanalysis_migrants.do  heterogeneity by migrant population share
  05_graphs.do                descriptive and summary figures
```

## How to run

1. Create a project folder with `code/` (these scripts) and `Dataset/` (the raw files above).
2. Open `code/00_main.do` and set `global root` to the project folder.
3. Run `00_main.do` in Stata. Outputs (`.dta` files, `.tex` tables, `.pdf` figures) are written to `Dataset_dta/`.

The scripts install two Stata packages: `estout` and `coefplot`.

## Notes and limitations

- **Not re-run after cleaning.** The code was tidied after the thesis was submitted: file names, comments and path handling were changed (paths are now set in `00_main.do`). The analysis itself is unchanged, but I have not been able to re-run the cleaned version.
- **Population for 2015-2018.** The population files in the code cover 2019-2024. For 2015-2018 the code uses each province's 2019 population as the denominator.
- **Projects spanning several municipalities.** The payment of each project is split equally across its municipalities before being aggregated to the province.
- **Province codes.** Codes of the metropolitan cities are harmonized between OpenPNRR and ISTAT in `01_cleaning_dataset.do`.

## Author

Riccardo Rinaudo, MSc student in Data Science and AI for Business (HEC Paris and École Polytechnique).
