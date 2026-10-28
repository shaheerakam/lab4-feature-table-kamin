library(DBI)
library(RSQLite)
library(tidyverse)

con <- dbConnect(SQLite(), "data/raw/cohort.db")

# schema exploration
dbListTables(con)
dbListFields(con, "patients")
dbListFields(con, "samples")
dbListFields(con, "mutations")
dbListFields(con, "genes")

dbGetQuery(con, "PRAGMA foreign_key_list(samples)")
dbGetQuery(con, "PRAGMA foreign_key_list(mutations)")

dbGetQuery(con, "SELECT COUNT(*) AS n FROM patients")
dbGetQuery(con, "SELECT COUNT(*) AS n FROM samples")
dbGetQuery(con, "SELECT COUNT(*) AS n FROM mutations")
dbGetQuery(con, "SELECT COUNT(*) AS n FROM genes")

dbGetQuery(con, "SELECT DISTINCT variant_classification FROM mutations ORDER BY variant_classification")

dbGetQuery(con, "SELECT COUNT(*) AS missing_sex FROM patients WHERE sex IS NULL")
dbGetQuery(con, "SELECT COUNT(*) AS missing_age FROM patients WHERE age_at_diagnosis IS NULL")
dbGetQuery(con, "SELECT COUNT(*) AS missing_stage FROM patients WHERE stage IS NULL")

# query 1: per-patient, per-gene protein-altering mutation counts
query1 <- "
WITH target_genes(gene_symbol) AS (
  VALUES ('TP53'), ('KRAS'), ('EGFR'), ('STK11'), ('KEAP1')
),
patient_gene AS (
  SELECT p.patient_id, g.gene_symbol
  FROM patients p
  CROSS JOIN target_genes g
)
SELECT pg.patient_id, pg.gene_symbol, COUNT(m.mutation_id) AS mutation_count
FROM patient_gene pg
LEFT JOIN samples s ON s.patient_id = pg.patient_id
LEFT JOIN mutations m
  ON m.sample_id = s.sample_id
  AND m.gene_symbol = pg.gene_symbol
  AND m.variant_classification != 'Silent'
GROUP BY pg.patient_id, pg.gene_symbol
ORDER BY pg.patient_id, pg.gene_symbol
"

gene_counts <- dbGetQuery(con, query1)
nrow(gene_counts) # expect 566 * 5 = 2830
head(gene_counts, 10)

# hand-verified check: TCGA-05-4382 EGFR should be 2 (confirmed below, both Missense_Mutation)
dbGetQuery(con, "
  SELECT m.gene_symbol, m.variant_classification, COUNT(*) AS n
  FROM mutations m
  JOIN samples s ON s.sample_id = m.sample_id
  WHERE s.patient_id = 'TCGA-05-4382' AND m.gene_symbol = 'EGFR'
  GROUP BY m.variant_classification
")

# query 2: patients per tissue source site per tumor stage
query2 <- "
SELECT s.tissue_source_site, p.stage, COUNT(DISTINCT p.patient_id) AS n_patients
FROM patients p
LEFT JOIN samples s ON s.patient_id = p.patient_id
GROUP BY s.tissue_source_site, p.stage
ORDER BY s.tissue_source_site, p.stage
"

site_stage_counts <- dbGetQuery(con, query2)
nrow(site_stage_counts)
sum(site_stage_counts$n_patients) # expect 566
head(site_stage_counts, 15)

# build the feature table
patient_base <- dbGetQuery(con, "
  SELECT p.patient_id, p.sex, p.age_at_diagnosis, p.stage,
         s.tissue_source_site, s.tmb_nonsynonymous
  FROM patients p
  LEFT JOIN samples s ON s.patient_id = p.patient_id
")
nrow(patient_base)

gene_counts_wide <- gene_counts %>%
  pivot_wider(names_from = gene_symbol, values_from = mutation_count)
nrow(gene_counts_wide)

feature_table <- patient_base %>%
  left_join(gene_counts_wide, by = "patient_id")

stopifnot(nrow(feature_table) == 566)
cat("patients before samples join:", nrow(patient_base), "\n")
cat("patients after final join:", nrow(feature_table), "\n")
head(feature_table)

sum(is.na(feature_table$sex))
sum(is.na(feature_table$age_at_diagnosis))
sum(is.na(feature_table$stage))

write_tsv(feature_table, "feature_table.tsv")

data_dictionary <- tribble(
  ~column, ~meaning, ~units, ~source_table, ~missing_coding, ~notes,
  "patient_id", "Unique patient identifier (TCGA barcode)", "", "patients", "none", "",
  "sex", "Patient sex", "male/female", "patients", "NA = not recorded", "",
  "age_at_diagnosis", "Patient age at diagnosis", "years", "patients", "NA = not recorded", "",
  "stage", "AJCC pathologic tumor stage", "", "patients", "NA = not recorded", "",
  "tissue_source_site", "Institution/site that submitted the tumor sample", "", "samples", "NA = no sample on file", "",
  "tmb_nonsynonymous", "Tumor mutation burden, nonsynonymous", "mutations per megabase", "samples", "NA = no sample on file", "",
  "EGFR", "Count of protein-altering mutations in EGFR", "count", "mutations (via samples)", "0 = no such mutation found; column is never NA", "Counts Frame_Shift_Del, Frame_Shift_Ins, In_Frame_Del, In_Frame_Ins, Missense_Mutation, Nonsense_Mutation, Nonstop_Mutation, Splice_Site, Translation_Start_Site; excludes Silent",
  "KEAP1", "Count of protein-altering mutations in KEAP1", "count", "mutations (via samples)", "0 = no such mutation found; column is never NA", "Same variant types as EGFR",
  "KRAS", "Count of protein-altering mutations in KRAS", "count", "mutations (via samples)", "0 = no such mutation found; column is never NA", "Same variant types as EGFR",
  "STK11", "Count of protein-altering mutations in STK11", "count", "mutations (via samples)", "0 = no such mutation found; column is never NA", "Same variant types as EGFR",
  "TP53", "Count of protein-altering mutations in TP53", "count", "mutations (via samples)", "0 = no such mutation found; column is never NA", "Same variant types as EGFR"
)

write_tsv(data_dictionary, "data_dictionary.tsv")