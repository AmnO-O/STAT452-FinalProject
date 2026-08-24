# Code Decisions — Activity 1, Tasks 01 & 04

**Owner:** Member A · **Source:** `src/activity1_salary_analysis.R`, `activity1/4. Continuous Regression.Rmd` · **Last updated:** 2026-08-24

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

---

## Task 04 Decisions — Continuous Regression (added 2026-08-24)

Decisions made while building `activity1/4. Continuous Regression.Rmd`. Numbering continues from the Task 01 log; Members B & C must treat these as fixed inputs to Tasks 5–7.

| # | Decision | Choice | Rationale (in our own words) |
|---|---|---|---|
| D14 | Train/test split design | **Year-aware seeded split**: all 287 records from 2020–2021 + 165 random 2022 records → train (452); remaining 113 2022 records → test; `set.seed(2026)` before the draw | Evaluation always targets the newest period, but a pure chronological holdout would leave a 49% test set — too far from the intended 80:20. Keeping ~3 of 5 2022 salaries in training preserves the ratio (refines D10: *year-aware* rather than strictly time-ordered). Rare categories (CT n=5, FL n=4) are verified present in training; the seed makes the partition exactly reproducible. |
| D15 | Response scale for modeling | **ln(salary)** as working response, despite Box–Cox preferring λ̂ ≈ 0.30 (95% CI [0.26, 0.38] excludes both λ = 1 and λ = 0) | ln gives directly interpretable percentage coefficients. The likelihood's verdict is respected empirically: the power-transformed model gets the identical assumption battery and competes head-to-head out-of-sample in §4.5 — and it wins there, closing the loop with data rather than preference. |
| D16 | Standardization boundary (amends D9) | **Train-only z-scores**: `_ts` columns computed from training means/SDs of raw codes, applied unchanged to test records | Penalized models require standardized inputs, but scaling on the full sample lets test information leak into fitting. The new `_ts` columns supersede the preprocessing `*_scaled` ones inside Task 4 only; results are numerically unchanged (glmnet standardizes internally anyway), but the procedure is now leakage-free. |
| D17 | Model roster | **Seven candidates**: raw-response OLS, AIC-stepwise OLS, polynomial (quadratic experience) OLS, Ridge, LASSO, Elastic-net (CV-chosen α = 0.1), power-transform OLS | Covers interpretability (OLS/stepwise), flexibility (polynomial), regularization (penalty family), and the response-scale question (power). All seven score the same held-out set once — nothing measured on test records feeds back into fitting or tuning. |
| D18 | Variable selection route | **Backward AIC stepwise** from the full 23-slope model (AIC 740 → 738; drops `remote_ratio` + `work_year`) plus a polynomial check (ANOVA F = 3.60, p = 0.028; RESET p = 0.12) | Stepwise gives a leaner interpretable model; the polynomial/RESET tests confirm mild curvature that the quadratic variant carries explicitly. df-adjusted GVIFs 1.03–1.21 confirm no collinearity obstacle after using single-location dummies (per reviewer note 5 / `is_local` advice). |
| D19 | Inference under violated assumptions | **HC1 robust standard errors** alongside ordinary ones, computed on the final stepwise model | Breusch–Pagan rejects constant variance on every response scale tested, so plain SEs are untrustworthy. Robust errors leave conclusions essentially unchanged except medium company size (+16%, p = 0.052 ordinary → p = 0.125 robust) — reported as suggestive, not established. |
| D20 | Ordinal vs dummy encoding | **Keep ordinal** encodings for experience/company size in penalized models | Re-encoding as full dummies changes CV RMSE by < 0.5% (0.5491 vs 0.5514), judged entirely by cross-validation **on the training data** — the comparison never touches the test set. Simpler encoding retained at no predictive cost. |
| D21 | Retransformation to dollars | **Duan smearing factor** (mean of exponentiated *training* residuals) for all dollar predictions | Exponentiating log predictions returns medians, understating means. Smearing assumes homoskedastic residuals — an assumption we know fails — so dollar figures are documented approximations, valid for ranking models rather than exact forecasts. |
| D22 | Task 4 output contract | `activity1/task04_model_comparison.csv` (7 rows: RMSE/R² in log points, MAE/RMSE in USD) is the **single source of truth** for model ranking | Member C's Task 6 must read this CSV instead of re-running models — same principle as D10. Winner recorded: power-transform OLS (test RMSE 0.416, MAE ≈ $43k); Ridge statistically indistinguishable behind it. |

### Verification Summary (Task 04, printed by the Rmd)

- Split sizes: train 452 · test 113 (all-2022 holdout), rare levels present in train
- Full-model F = 29.11 on 23 and 428 df (adj R² = 0.589)
- Box–Cox λ̂ = 0.30; best CV-RMSE scale ranking: power ≤ ridge < LASSO/enet < stepwise
- glmnet matrices 452×20 / 113×20; LASSO retains 20 of 20 columns at λmin
- CSV written with 7 model rows; rendered report embeds 7 figures