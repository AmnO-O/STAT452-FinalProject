# Code Decisions — Activity 1, Task 01 (Data Preprocessing)

**Owner:** Member A · **Source:** `src/activity1_salary_analysis.R` · **Last updated:** 2026-08-16

Every decision below is written into the code itself as a comment, so the script stays self-documenting. This file is the running "decisions log" (per `work_division.md`) that Members B & C must follow — never re-derive a decision separately.

---

## Decisions Log

| # | Decision | Choice | Rationale (in our own words) |
|---|---|---|---|
| D1 | Outliers in `salary_in_usd` (IQR rule: 10 rows above 280,911 USD) | **Keep all rows**, add `log_salary = ln(salary_in_usd)` | The 10 flagged values are legitimate executive/director salaries (EX/SE level, mostly US employers), not data-entry errors. Removing ~1.6% of an already small sample (565) would bias group means and sizes; winsorization would fabricate values. Skewness is handled at the model level (Tasks 3–5) using the log response instead. |
| D2 | Duplicate rows | **Remove** (keep first occurrence; 607 → 565) | Duplicates add no information and would double-count observations in every later statistic (means, ANOVA group sizes, model fitting). |
| D3 | `company_location` (53 countries) | **Top 7 + Other** (US, GB, CA, DE, IN, FR, ES kept; the rest → `Other`) | 36 of the 53 countries have ≤ 3 rows; keeping all would create ~52 near-empty dummies and unstable estimates. US alone is ~63% of the sample. Region grouping rejected as less informative for our research questions. |
| D4 | `employment_type` imbalance (FT 588 / PT 10 / CT 5 / FL 4) | **Keep 4 levels** as-is, one-hot encode | Dropping PT/CT/FL would lose real information (they exist in the data); the imbalance is documented in the report. ANOVA (Task 3) uses Type III SS because group sizes are unbalanced. |
| D5 | Job-title grouping | **7 categories** via priority-ordered keyword matching | 52 granular titles are too sparse for modeling. Priority order matters: management titles contain words like "Data Science", so `Director/Head/Manager/Lead` must be matched first; `Research Scientist` must be matched before the generic `Scientist` pattern. Validated with `stopifnot(sum(is.na(job_category)) == 0)`. |
| D6 | Log transform base | **Natural log (ln)**, not `log10` | ln is the standard base in statistics and makes coefficient interpretation cleaner. The base does not change the normality conclusion (any log base is a monotonic transform). Variable is named `log_salary`. |
| D7 | One-hot reference levels | **Explicit** via `relevel()`: `job_category` → `Data_Analyst`; `employment_type` → `FT`; `location_group`/`residence_group` → `Other` | Bug fix from Member B's review: `factor()`'s default alphabetical order previously picked `CT` as employment reference and `CA` as location reference by accident of spelling. Explicit references are chosen for interpretability: FT is the dominant category; each top country is compared vs "everywhere else" (`Other`); Data_Analyst is a common, well-understood baseline. |
| D8 | Categorical encoding | Ordinal for `experience_level` (EN<MI<SE<EX → 1–4) and `company_size` (S<M<L → 1–3); one-hot for `job_category`, `employment_type`, `location_group`, `residence_group` | Ordinal variables have a natural order; nominal variables do not. Raw factor/character columns are kept alongside encoded ones so interpretable models (MLR, ANOVA) can still use factors. |
| D9 | Scaling | z-score (`scale()`) → `*_scaled` columns for `salary_in_usd`, `log_salary`, `remote_ratio`, `exp_level_ord`, `company_size_ord` | Standardization does not change OLS fit but is mandatory for penalized models (Ridge/LASSO, Task 4) where scale-invariance matters. Raw columns preserved for interpretable models. |
| D10 | Output file | `dataset/ds_salaries_clean.csv` = **single source of truth** (565 rows × 45 cols) | All downstream tasks (EDA, ANOVA, regression, logistic) must read this one file with the same encodings — no re-derivation. `work_year` is kept intact (no aggregation) so the 80:20 split in Task 4 can be time-ordered (older 80% = 2020–2021, newer 20% = 2022) per `note.md`. |
| D11 | Diagnostic plots | Bare `ggplot()` calls (shown in RStudio plot pane), **no file saving** | Keeps the script simple; plots are re-generated on demand and exported later for the report. |
| D12 | `is_local` indicator | Added binary column: `1` if `company_location == employee_residence`, else `0` | Reviewer note 5: for non-remote employees the two locations coincide, so `loc_*` and `res_*` dummy sets are highly correlated. `is_local` gives Task 4 a single low-collinearity alternative to carrying both full dummy sets. |
| D13 | Per-group IQR cross-check | Computed IQR **within each experience level** to verify D1 | Reviewer note 1: a single global IQR ignores the fact that salary naturally varies by experience level. The per-group table confirms the flags come from EX/SE-level high earners. Report must explain why the global IQR was used and that per-group detection is the better method. |

---

## Verification Summary (printed by the script)

- Missing values after cleaning: **0**
- Empty strings: **0**
- Duplicates after cleaning: **0**
- Rows after cleaning: **565**
- IQR outliers detected (after de-duplication): **10** — kept (D1)
- Unmapped job titles: **0** (`stopifnot` assertion passes)
- job_category sizes: Data_Analyst 101 · Data_Engineer 151 · Data_Scientist 143 · Management_Lead 58 · ML_AI_Engineer 81 · Research 16 · Other 15

---

## Notes for Members B & C

- Regression response candidates: `log_salary` (preferred) or `salary_in_usd`; both have `_scaled` copies.
- Dummy columns and their references (see D7): `job_cat_*` (ref Data_Analyst), `empl_*` (ref FT), `loc_*` / `res_*` (ref Other).
- ANOVA (Task 3): unbalanced groups → use Type III SS (`car::Anova`).
- **ANOVA factors (reviewer note 2):** build the factorial model with `as.factor(experience_level)` / `as.factor(company_size)` — **never** the `_ord` integers. Numeric ordinals in `aov()` fit a linear trend instead of separate group means, which is the wrong model for this task.
- **Sparse interaction cells (reviewer note 3):** the script prints `table(job_category, experience_level)` — Other (n=15) and Research (n=16) crossed with 4 experience levels can give 0–2 obs per cell, which destabilizes the interaction. If cells are too sparse, lead with Experience × Company Size (3×4 = 12 cells) as the safer interaction.
- **Multicollinearity (reviewer note 5):** the script prints `table(location_group, residence_group)` and the `is_local` share. If both dummy sets go into MLR/Ridge, expect inflated VIFs — consider dropping one set or using `is_local` instead.
- Any change to this file must be agreed by the group and mirrored in `dataset/ds_salaries_clean.csv`.