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
