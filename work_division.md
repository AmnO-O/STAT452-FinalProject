# Work Division — Statistics Final Project

A balanced three-way split. Each person owns a full "vertical slice" — one statistical specialty carried through both Activity 1 and Activity 2 — rather than just splitting by point value. This keeps everyone's workload and skill-depth roughly equal even though Activity 1 (6 pts) has more sub-tasks than Activity 2 (4 pts).

Task numbers below refer to the numbered tasks in `requirement.md` (Activity 1: tasks 1–7; Activity 2: tasks 1–3).

---

## Overview Table

| Member | Role | Activity 1 (6 pts) — Requirement Tasks | Activity 2 (4 pts) — Requirement Tasks | Report Sections Owned |
|---|---|---|---|---|
| **A** | Data & EDA Lead | Tasks 1 & 2: Data Preprocessing + EDA; salary trend (part of Task 3) | Tasks 1 & 2: describe & clean dataset, descriptive statistics | Data collection & cleaning, Data description, EDA visuals |
| **B** | Inferential Statistics & Regression Lead | Tasks 3 & 4: Factorial ANOVA + continuous regression (MLR/Polynomial/Ridge/LASSO) | Task 3: apply regression/comparative model to the group's research question | Statistical analysis (ANOVA + regression), R code |
| **C** | Classification, Evaluation & Interpretation Lead | Tasks 5, 6 & 7: binary logistic regression, model evaluation, interpretation & recommendations | Task 3: analyze & interpret results, discuss, conclude, recommend; leads report assembly (TOC, cover, references, data sources, contributions) | Classification, model evaluation, interpretation & conclusions |

---

## Member A — Data & EDA Lead

### Activity 1 (6 pts)

- **Task 1 — Data Preprocessing:** missing values, duplicates, outliers, `job-title` regrouping into major categories, encoding (Ordinal/One-Hot), scaling
- **Task 2 — EDA:** descriptive stats + distribution of `salary-in-usd`, salary vs. job category/experience level/employment type/remote ratio/company size/location
- **Salary trend** over time (`work-year`) from Task 3 (supports Member B's ANOVA)

### Activity 2 (4 pts)

- **Task 1** — Describe and clean the dataset (if needed); dataset sourcing/selection (coordinate with group)
- **Task 2** — Perform descriptive statistics on the dataset

### Report Sections Owned

Data collection & cleaning, Data description, EDA visuals

---

## Member B — Inferential Statistics & Regression Lead

### Activity 1 (6 pts)

- **Task 3 — Inferential Statistics & Factorial ANOVA:** main effects + interaction effects (e.g., Experience Level × Company Size, Experience Level × Job Category) on `salary-in-usd`, assumption testing (normality of residuals, homogeneity of variance) + remedies
- **Task 4 — Continuous Salary Regression Modeling:** train/test split, ≥2 models (Multiple Linear, Polynomial, Ridge, or LASSO Regression)

### Activity 2 (4 pts)

- **Task 3** — Apply the regression/comparative model that fits the group's research question

### Report Sections Owned

Statistical analysis (ANOVA + regression), corresponding R code

---

## Member C — Classification, Evaluation & Interpretation Lead

### Activity 1 (6 pts)

- **Task 5 — Binary Logistic Regression Modeling:** build `is-top-tier` (Y = 1 if salary ≥ Q3 top 25%), fit model, interpret coefficients via Odds Ratios (exp(β))
- **Task 6 — Model Evaluation & Comparison:** RMSE/MAE/R² for regression models, Accuracy/Precision/Recall/F1-Score/ROC-AUC for logistic model, select and justify best model per task
- **Task 7 — Interpretation and Recommendations:** feature importance interpretation + propose model improvement avenues

### Activity 2 (4 pts)

- **Task 3** — Analyze and interpret results; discuss, conclude, and propose recommendations based on model findings
- Leads final report assembly: TOC, title, cover image, references, data sources, individual contributions breakdown

### Report Sections Owned

Classification, model evaluation, final interpretation & conclusions

---

## Suggested Timeline (Aug 13 → Aug 30, 17 days)

| Dates | Focus |
|---|---|
| Aug 13–17 | Member A finishes Tasks 1 & 2 (preprocessing + EDA) — everyone else needs this clean dataset to work from |
| Aug 18–23 | Members B & C work in parallel on Tasks 3 & 4 (ANOVA/regression, B) and Tasks 5 & 6 (logistic/evaluation, C); Member A starts Activity 2 Tasks 1 & 2 (dataset + cleaning) |
| Aug 24–27 | Everyone finishes their Activity 2 task; cross-review each other's R code and results |
| Aug 28–29 | Merge into final report, write shared conclusions/recommendations, format per requirements (≤60 pages, all required sections) |
| Aug 30 | Final proofread, zip PDF + R code folder + data folder, submit to Moodle |

---

## Points to Flag for the Group

- **Shared/joint work:** the ANOVA and regression sections (Tasks 3 & 4) both depend on Member A's cleaned dataset and encoded variables — build in a hand-off checkpoint (e.g., Aug 17) rather than working from separate copies.
- **AI policy:** the syllabus explicitly bans submitting AI-generated code/interpretations/text as-is — a zero grade if caught. Whatever each of you drafts (including with my help) should get rewritten into your own words/understanding before it goes in the report.
- **Contribution breakdown section:** since grading is shared equally, it's worth explicitly documenting each person's tasks (this split works well for that) in the report's required "individual contributions" section.

---

## Cross-Review Assignments

Cross-review protects the group: if any one member's section has an error or doesn't hold up under questioning, it gets caught before submission instead of during grading. Reviewing is baked into the roles without changing the core split.

### Reviewer Matrix (rotating — not "review your own buddy")

| Reviewer | Reviews | Checks for |
|---|---|---|
| **Member B** | Member A's preprocessing/EDA | Are outlier/missing-value decisions justified? Does the `job-title` grouping make sense? Any data issues that will break downstream models? |
| **Member C** | Member B's ANOVA & regression | Are assumptions actually tested (not just claimed)? Do interaction effects make substantive sense? Is model selection justified? |
| **Member A** | Member C's logistic regression & evaluation | Is the top-25% cutoff calculated correctly? Do odds ratios get interpreted correctly in plain language? Do metrics match the model outputs? |

This creates a full loop (A→B, B→C, C→A) instead of pairs reviewing each other, so everyone has to understand a part of the project they didn't build — which also means everyone can actually explain the whole report if the teacher asks about it, not just their own third.

### Review Checkpoints in the Timeline

| Dates | Addition |
|---|---|
| Aug 17 | **Checkpoint 1:** Member A shares cleaned dataset + EDA; Member B reviews before starting ANOVA/regression (catches data problems early, before two people build on bad data) |
| Aug 23 | **Checkpoint 2:** Members B and C swap completed sections for review; short call/chat to flag anything unclear or wrong |
| Aug 27 | **Checkpoint 3:** Full group read-through of the merged report — everyone reads everyone's section once, not just their reviewer |
| Aug 29 | Final check: does the narrative agree across sections? (e.g., if EDA says experience level matters most, does the regression section's feature importance agree or explain why not?) |

### Communication Habits

- A shared channel (Zalo/Messenger group or a Google Doc comment thread) for quick questions — cheaper than waiting for a call
- Each person posts a 2–3 line update after finishing a task: what they did, what they're unsure about, what the next person needs to know
- Keep a running "decisions log" (e.g., "we're using Q3 cutoff from full dataset, not per-year" or "we dropped negative salaries as outliers") so nobody re-derives something differently — this also becomes handy content for the report's methods section

