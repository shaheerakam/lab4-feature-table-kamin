# AI Usage — Lab 4

**Tool used:** Claude (Anthropic), Sonnet 5

## What Claude helped with

- Walked me step by step through setting up the repo, RStudio project, and renv.
- Helped me interpret the schema once I ran `dbListTables()` and `dbListFields()` myself — e.g. noting that `samples` having 566 rows, same as `patients`, means one sample per patient here.
- Assisted with SQL syntax for the two queries: counting protein-altering mutations by patient and gene (excluding silent mutations) and summarizing patient counts by tissue source site and stage, including patients with missing stage information.
- Provided assistance with R data manipulation using `pivot_wider()` and `left_join()` to restructure the gene-count results and combine them with patient and sample information.

## Errors I hit and how I understood/fixed them

- `Error in library(DBI) : there is no package called 'DBI'` — happened because `renv::init()` switched the project to its own separate package library, so packages installed before that point weren't available inside it. Fixed by re-running `install.packages(c("DBI", "RSQLite", "tidyverse"))` after `renv::init()`, then `renv::snapshot()` to record them.
- `could not find function "%>%"` — happened because I had loaded `DBI`/`RSQLite` but never `library(tidyverse)` in this script, and the pipe and `pivot_wider()` come from tidyverse, not base R. Fixed by adding `library(tidyverse)`.

## How I checked the SQL was correct

- Query 1: expected 566 patients × 5 genes = 2830 rows; `nrow()` confirmed 2830.
- Query 2: no fixed expected row count, so I checked `sum(site_stage_counts$n_patients)` equaled 566, confirming every patient was counted once and nobody was dropped by the `LEFT JOIN`.
- Checked `nrow()` was 566 at every step of building `feature_table` (base table, pivoted gene table, final join), and compared the missing-value counts in the final table (52/71/54 for sex/age/stage) against the same counts run directly on `patients` earlier — they matched exactly.

## What I did myself

- Ran every query and check myself and read the output before moving on.
- Wrote this README and AI_USAGE.md based on what actually happened in my session.