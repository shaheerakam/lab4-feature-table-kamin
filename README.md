# Lab 4: Database-Driven Feature Table

PUBH 4201 — Applied Computing for Health Data Science

## Overview

Builds a one-row-per-patient feature table from `cohort.db`, a SQLite
database of real, de-identified TCGA Lung Adenocarcinoma (LUAD)
PanCancer Atlas data from cBioPortal (566 patients).

## Schema

- **patients** (566 rows, one row per patient): `patient_id` (key), `sex`, `age_at_diagnosis`, `stage`, `vital_status`, `followup_months`
- **samples** (566 rows, one row per tumor sample): `sample_id` (key), `patient_id` → `patients.patient_id`, `tissue_source_site`, `tmb_nonsynonymous`, `aneuploidy_score`, `msi_mantis_score`
- **mutations** (200,789 rows, one row per mutation): `mutation_id` (key), `sample_id` → `samples.sample_id`, `gene_symbol` → `genes.gene_symbol`, `variant_classification`, `variant_type`, `protein_change`, `chromosome`, `start_pos`, `end_pos`, `t_ref_count`, `t_alt_count`
- **genes** (17,756 rows, one row per gene): `gene_symbol` (key), `entrez_gene_id`, `chromosome`

Relationships confirmed directly from the database with `PRAGMA foreign_key_list(...)`, not guessed from column names. `patients` to `samples` is one-to-one in this dataset (both have 566 rows); `samples` to `mutations` is one-to-many.

## How to rebuild the feature table

1. Install R packages: `install.packages(c("DBI", "RSQLite", "tidyverse"))` (or run `renv::restore()` for the exact versions used here).
2. Make sure `data/raw/cohort.db` is present.
3. From the project root, run:
   ```r
   source("build_feature_table.R")
   ```
   (or `Rscript build_feature_table.R` from a terminal).
   This connects to the database, runs both required SQL queries, builds the feature table, and writes `feature_table.tsv` and `data_dictionary.tsv`.

## Queries

- **Query 1**: per-patient, per-gene count of protein-altering mutations (excluding Silent) for TP53, KRAS, EGFR, STK11, KEAP1. Expected 566 × 5 = 2830 rows; got 2830.
- **Query 2**: patient count per tissue source site per tumor stage, keeping patients with a missing stage. Expected the counts to sum back to 566 patients; got 566.

Both queries are in `build_feature_table.R`, labeled `query1` and `query2`.

## Feature table

- One row per patient (566), checked with `stopifnot(nrow(feature_table) == 566)` in the script.
- Columns: `sex`, `age_at_diagnosis`, `stage`, `tissue_source_site`, `tmb_nonsynonymous`, plus one mutation-count column per gene (`TP53`, `KRAS`, `EGFR`, `STK11`, `KEAP1`).
- The gene columns come from a long-format SQL query result, reshaped to wide format in R with `pivot_wider()` — not pivoted in SQL.

## Missing data

- 52 patients missing `sex`, 71 missing `age_at_diagnosis`, 54 missing `stage` — left as `NA`, not dropped or filled in. These match the counts found directly on the `patients` table before any joins.
- Every patient has exactly one sample (566 patients, 566 samples), so nobody was lost in the `samples` join. Patient counts before (`patient_base`) and after (`feature_table`) the final join are both printed in the script and both equal 566.
- A gene count of `0` means no protein-altering mutation was found for that patient/gene — a real, counted zero, not a missing value. The gene columns are never `NA`.

## Files

- `build_feature_table.R` — runs everything: schema checks, both SQL queries, the feature table build, and the data dictionary
- `feature_table.tsv` — final output, 566 rows
- `data_dictionary.tsv` — column-by-column documentation
- `data/raw/cohort.db` — source database
- `AI_USAGE.md` — AI assistance log