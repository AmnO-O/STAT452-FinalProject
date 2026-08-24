# Work Log — Nam (Member A: Data & EDA Lead)

Log of what Nam has completed so far (per `work_division.md`).

## Completed Work

| Date | Task | Deliverable | Status |
|---|---|---|---|
| Aug 14 | Preprocessing audit (missing values, duplicates, outliers) | Verified: 0 NA, 0 empty strings, 42 duplicate rows removed (607 → 565), 10 IQR outliers in `salary_in_usd` | ✅ |
| Aug 14 | Decision log for data handling | D1–D5 recorded in `plan/activity1_task01.md` (keep outliers + log-transform, drop duplicates, Top-7 countries + Other, keep 4 employment types, 7 job categories) | ✅ |
| Aug 16 | Task 1 — Data Preprocessing | `activity1/1. Data Preprocessing.Rmd` + `.R`: ID removal, dedup, outlier handling, `log_salary`, job-title grouping (7 categories), ordinal + one-hot encoding, scaling, verification, data dictionary | ✅ |
| Aug 16 | Task 1 — output dataset | `dataset/ds_salaries_clean.csv` (565 rows, 0 NA, 0 duplicates) — single source of truth for Tasks 3–5 | ✅ |
| Aug 16 | Task 2 — EDA | `activity1/2. EDA.Rmd`: descriptive stats + distribution of salary (raw vs log), boxplots by job category / experience / company size / employment type / remote ratio / location, salary trend by year, category sizes | ✅ |
| Aug 19 | Project restructure | Split old combined Rmd into per-task files; created task skeletons 3–7 and `WorkTracking.md` | ✅ |
| Aug 19 | EDA improvement — dual-scale plots | Every comparison now shown side by side (raw USD + ln-salary) via `cowplot::plot_grid`; added §2.1 abbreviation table (FT/PT/CT/FL, EN/MI/SE/EX, S/M/L, country codes); plots relabeled to full readable names via `label_map`; re-knitted to HTML | ✅ |
| Aug 24 | Task 4 — Continuous regression modeling | `activity1/4. Continuous Regression.Rmd`: seeded year-aware train/test split (452/113, all-2022 holdout); baseline OLS; Box–Cox profile (λ̂ ≈ 0.30) with raw/power/log diagnostic battery (Shapiro–Wilk, Breusch–Pagan, Cook's D); AIC stepwise selection (7 → 5 predictor blocks); polynomial flexibility check; RESET test; HC1-robust inference; Ridge/LASSO/Elastic-net via glmnet with train-only standardization; ordinal-vs-dummy encoding sensitivity (CV on training data only) | ✅ |
| Aug 24 | Task 4 — Model comparison & output | §4.5 head-to-head ranking of all seven candidates on the held-out set (RMSE/R² in log points + Duan-smearing-adjusted US dollars), RMSE dot plot, `activity1/task04_model_comparison.csv` (feeds Member C's Task 6); winner: power-transform OLS (test RMSE 0.416 / MAE $43k); rendered `4.-Continuous-Regression.html` | ✅ |
| Aug 24 | Task 4 — Review fixes & polish | Leakage-proofed scaling (train-only z-scores supersede full-sample ones); sensitivity check confined to cross-validation on training data; robust inference moved onto the final stepwise model; corrected reported statistics (F = 29.11 on 23/428 df, df-adjusted GVIFs 1.03–1.21, Shapiro–Wilk gain ≈ 250-million-fold); rewrote audit-style hedging into confident report prose; committed as `28c4d46`, local `plan/` notes excluded from git | ✅ |

## Pending Work (Activity 1)

- Salary trend over time (`work_year`) — Task 3 support for Member B — ⏳ Not started

## Pending Work (Activity 2)

- Task 1 — Describe and clean the chosen dataset — ⏳ Not started
- Task 2 — Descriptive statistics — ⏳ Not started

## Review Responsibilities

- Reviewer for Member C's logistic regression & evaluation (per reviewer matrix in `work_division.md`) — ⏳

## Key Decisions Made (confirmed by group)

| # | Decision | Choice |
|---|---|---|
| D1 | 10 IQR outliers in salary | Keep all rows; add `log10`/`ln(salary_in_usd)` for modeling |
| D2 | 42 duplicate rows | Remove (607 → 565) |
| D3 | `company_location` (53 countries) | Top 7 + Other one-hot |
| D4 | `employment_type` imbalance | Keep 4 levels, note imbalance in report |
| D5 | Job-title grouping | 7 categories via priority-ordered keyword matching |
