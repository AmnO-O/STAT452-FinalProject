# Activity 1 — Task 01: Data Preprocessing (Plan)

**Owner:** Member A (Data & EDA Lead) · **Cross-reviewer:** Member B · **Hand-off checkpoint:** Aug 17
**Requirement source:** `requirement.md` lines 54–58 (Task 1 of Activity 1)
**Source files to update:** `activity1/1. Data Preprocessing.R` and `activity1/1. Data Preprocessing.Rmd`

---

## 1. Objective & Scope

Prepare the raw `ds_salaries.csv` dataset for all downstream analyses (EDA, Factorial ANOVA, continuous regression, binary logistic regression) by:

1. Checking for and handling missing values, duplicate records, and potential outliers.
2. Grouping the 52 granular job titles into major, meaningful job categories.
3. Encoding categorical variables (Ordinal / One-Hot) and scaling numerical features.

Every decision must be justified in the report in the group's own words (AI policy). No decision is "silent": each step either takes an action or documents why no action is needed.

---

## 2. Input / Output

| Item | Path |
|---|---|
| Input | `dataset/ds_salaries.csv` (607 obs × 11 vars incl. `X` id column) |
| Output | `dataset/ds_salaries_clean.csv` (cleaned + encoded dataset for Members B & C) |
| Output | Updated `activity1/1. Data Preprocessing.R` and `.Rmd` (Task 01 chunks + narrative) |
| Output | Data dictionary + decision log (feeds report "Data collection & cleaning" section) |

---

## 3. Data Audit Results (verified 2026-08-14)

| Check | Result | Action |
|---|---|---|
| Missing values (NA) | 0 | None needed — document |
| Empty strings | 0 | None needed — document |
| Duplicate rows | **42** | Remove (keep first occurrence) → 565 rows |
| Outliers in `salary_in_usd` (IQR rule) | **10** above upper bound 280,911 USD | **Keep** (see §4.4) |

Key statistics of `salary_in_usd`: min 2,859 · Q1 62,726 · median 101,570 · Q3 150,000 · max 600,000 · mean 112,298 · IQR 87,274 · lower bound −68,185 · upper bound 280,911.

Categorical cardinality (before cleaning):

| Variable | Levels (count) |
|---|---|
| `experience_level` | EN 88 · MI 213 · SE 280 · EX 26 |
| `employment_type` | FT 588 · PT 10 · CT 5 · FL 4 |
| `job_title` | 52 distinct values |
| `company_size` | S 83 · M 326 · L 198 |
| `remote_ratio` | 0 · 50 · 100 (numeric) |
| `work_year` | 2020 (72) · 2021 (217) · 2022 (318) |
| `company_location` | 53 countries (US 355 · GB 47 · CA 30 · DE 28 · IN 24 · FR 15 · ES 14 · GR 11 · …) |
| `salary_currency` | 17 currencies (USD 398 · EUR 95 · GBP 44 · …) — **not used in analysis**, `salary_in_usd` is the response |

---

## 4. Steps

### 4.1 Load data & remove ID column

- `read.csv("dataset/ds_salaries.csv")`, drop `X` (row id, no information value).
- Verify structure with `str()` / `summary()`; check all types are as expected (`salary_in_usd`, `remote_ratio` numeric; rest character).
- Already present in source files (lines 4–13).

### 4.2 Check missing values & empty strings

- `colSums(is.na(data))` and `colSums(data == "")` → both all-zero.
- Keep both checks in the reproducible script; report result in text (no action needed).

### 4.3 Handle duplicate records

- `data[duplicated(data), ]` → 42 rows (full-row duplicates, same salary/year/role/etc.).
- Remove with `distinct()`; **607 → 565** rows.
- Justification: duplicates add no information and would double-count observations in every later statistic (means, ANOVA group sizes, model fitting).
- After removal, re-run outlier detection (counts may shift slightly — record actual numbers in code output).

### 4.4 Handle outliers in `salary_in_usd` — **DECISION: KEEP + log-transform**

- Detection: IQR rule (`Q1 − 1.5·IQR`, `Q3 + 1.5·IQR`) → 10 rows above 280,911 USD; none below lower bound.
- **Chosen strategy:** keep all rows. The 10 flagged values are legitimate executive/director salaries (EX/SE level, mostly US employers), not data-entry errors. Removing ~1.6% of an already small sample (565) would bias group means and group sizes; winsorization would fabricate values.
- Skew handling instead happens at the *model* level: add `log_salary = log10(salary_in_usd)` column now; Tasks 3–5 use the transformed variable where needed (also reduces outlier leverage in regression).
- Document in report: alternative approaches considered (removal, winsorization) and why rejected.

### 4.5 Group `job_title` into major categories

- Mapping via ordered `case_when()` / `grepl()`, matching **in priority order** (management titles contain words like "Data Science", so they must be matched first):

| Priority | Category | Matching keywords (grepl, case-insensitive) |
|---|---|---|
| 1 | Management/Lead | Director · Head · Manager · Lead |
| 2 | ML/AI Engineer | Machine Learning · ML Engineer · ML Scientist · AI · Computer Vision · NLP · Deep Learning · Researcher (3D/Applied ML) |
| 3 | Data Engineer | Data Engineer · Big Data · ETL · Cloud Data · Data Architect · Data Specialist · Data Science Engineer |
| 4 | Data Scientist | Data Scientist · Scientist |
| 5 | Data Analyst | Data Analyst · Analytics |
| 6 | Research | Research Scientist |
| 7 | Other | catch-all (e.g., Data Science Consultant, Analytics Engineer) |

- Expected rough sizes (re-verify exact counts in R after dedup): Data Analyst ≈ 124 · Data Scientist ≈ 159 · Data Engineer ≈ 160 · ML/AI Engineer ≈ 90 · Management/Lead ≈ 52 · Research ≈ 16 · Other ≈ 6.
- **Validation:** no leftover/unmapped titles (assert `sum(is.na(job_category)) == 0`); print count table per category; eyeball a sample of titles per category to confirm grouping sanity (Member B reviews this).
- Result column: `job_category` (factor).

### 4.6 Encode categorical variables

Keep the raw factor columns alongside encoded ones (raw columns stay available for ANOVA in Task 3 and for interpretable regression).

| Variable | Encoding | Detail |
|---|---|---|
| `experience_level` | **Ordinal** | EN < MI < SE < EX → 1, 2, 3, 4 (`exp_level_ord`) |
| `company_size` | **Ordinal** | S < M < L → 1, 2, 3 (`company_size_ord`) |
| `job_category` | **One-hot** (drop-first) | 7 categories → 6 dummies (`job_cat_*`) |
| `employment_type` | **One-hot** (drop-first) | **DECISION: keep 4 levels as-is** (FT 588 / PT 10 / CT 5 / FL 4) → 3 dummies; imbalance noted in report |
| `company_location` | **One-hot** (drop-first) | **DECISION: Top 7 + Other** — US, GB, CA, DE, IN, FR, ES kept; remaining 46 countries → `Other`; 7 dummies |
| `employee_residence` | Same Top-7 + Other treatment | For EDA use; low priority for models |
| `remote_ratio` | Already numeric (0/50/100) | Keep numeric |
| `work_year` | Integer / factor | Keep numeric for trend; factor if ANOVA needs it |

Location rationale: 53 countries with 36 of them having ≤ 3 rows would create ~52 near-empty dummies and unstable estimates; Top-7 keeps meaningful variance (US alone = 63% of sample). Region grouping rejected as less informative for the research questions.

### 4.7 Scale numerical features

- `scale()` (z-score) numeric predictors → `_scaled` columns: `salary_in_usd` / `log_salary`, `remote_ratio`, `exp_level_ord`, `company_size_ord`.
- Raw columns are preserved for interpretable models (MLR, ANOVA); scaled copies are required for penalized models (Ridge/LASSO, Task 4) where scale-invariance matters.
- Justify in report: standardization does not change model fit for OLS but is mandatory for regularization.

### 4.8 Deliverables & verification

- Write `dataset/ds_salaries_clean.csv` (encoded + raw columns).
- Data dictionary table: variable, type, levels, meaning, encoding — for the report appendix.
- Re-run full verification: 0 NA, factor levels correct, no unmapped job titles, row count = 565, duplicate check = 0.
- Diagnostic outputs feeding Task 2 (EDA): histogram of `salary_in_usd` vs `log_salary`, boxplots by `job_category` / `experience_level` / `company_size`, bar counts of categories — produced here, interpreted in Task 2.

---

## 5. Decisions Log (confirmed by group, 2026-08-14)

| # | Decision | Choice |
|---|---|---|
| D1 | 10 IQR outliers in salary | **Keep** all rows; add `log10(salary_in_usd)` for modeling |
| D2 | 42 duplicate rows | **Remove** (607 → 565) |
| D3 | `company_location` (53 countries) | **Top 7 + Other** one-hot |
| D4 | `employment_type` imbalance | **Keep 4 levels** (one-hot), note imbalance in report |
| D5 | Job-title grouping | 7 categories via priority-ordered keyword matching |

---

## 6. QA & Hand-off

- **Member B review (checkpoint Aug 17):** are outlier/missing/duplicate decisions justified? Does the job-title grouping make sense? Any data issue that would break ANOVA/regression downstream? (per `work_division.md` reviewer matrix)
- **Task 2 overlap:** EDA visuals partly generated in §4.8 — coordinate so Member A produces one coherent EDA section (Tasks 1 & 2 both owned by Member A).
- **Log decisions** in the shared "decisions log" (work_division.md) so Members B & C use the same cleaned file and encodings — never re-derive separately.
- **Time-series note (note.md):** for any later 80:20 split (Task 4), the 80% must be the *older* data (2020–2021) and 20% the newer (2022) — preprocessing must keep `work_year` intact (no aggregation) to enable this.

---

## 7. Dependencies & Risks

| Risk | Mitigation |
|---|---|
| Small sample after dedup (565) | Keep all rows, use log-transform instead of deleting outliers |
| Sparse levels (PT/CT/FL, rare countries) | D4/D3 decisions; report imbalance; ANOVA uses Type III SS if unbalanced (note.md) |
| Grouping misclassification | Priority-ordered matching + validation table + Member B review |
| Hand-off inconsistency | Single source of truth: `ds_salaries_clean.csv` + decisions log |