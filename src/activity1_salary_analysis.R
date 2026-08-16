library(tidyverse)

## Load the dataset ds_salaries
data <- read.csv("dataset/ds_salaries.csv")
head(data)
summary(data)


#1 Data Preprocessing

## get rid of ID column
data$X <- NULL
head(data)


## Check for missing values
missing_values <- colSums(is.na(data))
print(missing_values) ### The dataset has no Na values


## Check for empty strings
empty_strings <- colSums(data == "")
print(empty_strings) ### The dataset has no empty strings


## Check for duplicate rows
duplicate_rows <- data[duplicated(data), ]
print(nrow(duplicate_rows)) ### 42 dupplicated rows


## Remove duplicate records (keep the first occurrence)
## Justification: duplicates add no information and would double-count
## observations in every later statistic (means, ANOVA group sizes, model fitting).
data <- data %>% distinct()
cat("Rows after removing duplicates:", nrow(data), "\n") ### 607 -> 565


## Detect outliers in salary_in_usd (IQR rule) AFTER de-duplication
### Boxplot to visualize extreme high earners
ggplot(data, aes(x = "", y = salary_in_usd)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red", outlier.shape = 16) +
  scale_y_continuous(labels = scales::dollar) +
  theme_minimal() +
  labs(title = "Detecting Outliers in Salary (USD)", x = "", y = "Salary in USD")

### Calculate IQR parameters
Q1 <- quantile(data$salary_in_usd, 0.25)
Q3 <- quantile(data$salary_in_usd, 0.75)
IQR_value <- Q3 - Q1

lower_bound <- Q1 - 1.5 * IQR_value
upper_bound <- Q3 + 1.5 * IQR_value

### Filter outlier rows
outlier_rows <- data %>%
  filter(salary_in_usd < lower_bound | salary_in_usd > upper_bound)

cat("Total IQR Outliers Detected:", nrow(outlier_rows), "\n") # 10 outliers detected


## Outlier decision (D1): KEEP all 10 rows, then log-transform salary
## Justification: the flagged values are legitimate executive/director salaries
## (EX/SE level, mostly US employers), not data-entry errors. Removing ~1.6% of an
## already small sample would bias group means and sizes; winsorization would
## fabricate values. Skewness is handled at the model level instead.
data$log_salary <- log(data$salary_in_usd) ### natural logarithm (ln)

## Cross-check: per-group IQR within experience level (reviewer note 1)
## A single global IQR ignores the fact that salary naturally varies by experience
## level; per-group detection shows which levels actually drive the flags.
group_outliers <- data %>%
  group_by(experience_level) %>%
  mutate(gQ1 = quantile(salary_in_usd, 0.25),
         gQ3 = quantile(salary_in_usd, 0.75),
         gIQR = gQ3 - gQ1,
         is_group_outlier = salary_in_usd < (gQ1 - 1.5 * gIQR) |
                            salary_in_usd > (gQ3 + 1.5 * gIQR)) %>%
  ungroup()
print(table(group_outliers$experience_level, group_outliers$is_group_outlier))


## Group granular job titles into 7 major categories (priority-ordered matching)
## Management titles contain words like "Data Science", so they MUST be matched first.
data <- data %>%
  mutate(job_category = case_when(
    grepl("Director|Head|Manager|Lead", job_title, ignore.case = TRUE) ~ "Management_Lead",
    grepl("Machine Learning|ML Engineer|ML Scientist|AI|Computer Vision|NLP|Deep Learning|Researcher",
          job_title, ignore.case = TRUE) ~ "ML_AI_Engineer",
    grepl("Research Scientist", job_title, ignore.case = TRUE) ~ "Research",
    grepl("Data Engineer|Big Data|ETL|Cloud Data|Data Architect|Data Specialist|Data Science Engineer",
          job_title, ignore.case = TRUE) ~ "Data_Engineer",
    grepl("Data Scientist|Scientist", job_title, ignore.case = TRUE) ~ "Data_Scientist",
    grepl("Data Analyst", job_title, ignore.case = TRUE) ~ "Data_Analyst",
    TRUE ~ "Other"
  ))

### Validation: no title may remain unmapped
stopifnot(sum(is.na(data$job_category)) == 0)

### Count table per category
data$job_category <- factor(data$job_category)
print(table(data$job_category))


## Encode categorical variables
## Ordinal encoding: experience level EN < MI < SE < EX -> 1, 2, 3, 4
data <- data %>%
  mutate(exp_level_ord = case_when(
    experience_level == "EN" ~ 1L,
    experience_level == "MI" ~ 2L,
    experience_level == "SE" ~ 3L,
    experience_level == "EX" ~ 4L
  ))

## Ordinal encoding: company size S < M < L -> 1, 2, 3
data <- data %>%
  mutate(company_size_ord = case_when(
    company_size == "S" ~ 1L,
    company_size == "M" ~ 2L,
    company_size == "L" ~ 3L
  ))

## One-hot encoding helper with an EXPLICIT reference level
## Never let factor()'s alphabetical order silently pick the baseline:
## e.g. without relevel(), employment_type would use CT as reference, and
## location_group would use CA, purely by accident of spelling.
one_hot <- function(df, col, prefix, ref_level) {
  f <- relevel(factor(df[[col]]), ref = ref_level)
  mm <- as.data.frame(model.matrix(~ f - 1, data = df)[, -1, drop = FALSE])
  colnames(mm) <- paste0(prefix, gsub("[^[:alnum:]]", "_", levels(f)[-1]))
  mm
}

## company_location: Top 7 countries + Other (D3)
## Rationale: 53 countries with 36 of them having <= 3 rows would create ~52
## near-empty dummies and unstable estimates; US alone = 63% of the sample.
top_countries <- c("US", "GB", "CA", "DE", "IN", "FR", "ES")
data <- data %>%
  mutate(location_group = ifelse(company_location %in% top_countries,
                                 company_location, "Other"),
         residence_group = ifelse(employee_residence %in% top_countries,
                                  employee_residence, "Other"))

## One-hot: job_category (6 dummies), employment_type (3 dummies, D4),
## location_group (7 dummies), residence_group (7 dummies)
## Reference levels are explicit:
##   - job_category:    Data_Analyst  (common, well-understood baseline)
##   - employment_type: FT            (dominant category, 588/607 rows)
##   - location/residence: Other      (each top country vs. "everywhere else")
data <- bind_cols(
  data,
  one_hot(data, "job_category", "job_cat_", ref_level = "Data_Analyst"),
  one_hot(data, "employment_type", "empl_", ref_level = "FT"),
  one_hot(data, "location_group", "loc_", ref_level = "Other"),
  one_hot(data, "residence_group", "res_", ref_level = "Other")
)

## is_local indicator (reviewer note 5): for non-remote employees the company
## location equals the employee residence, so the two dummy sets are highly
## correlated. is_local = 1 if both countries match, else 0. This gives Task 4
## a single low-collinearity alternative to carrying both full dummy sets.
data$is_local <- as.integer(data$company_location == data$employee_residence)


## Scale numerical features (z-score) for penalized models (Ridge/LASSO)
## Raw columns are preserved for interpretable models (MLR, ANOVA).
data$salary_in_usd_scaled <- as.numeric(scale(data$salary_in_usd))
data$log_salary_scaled <- as.numeric(scale(data$log_salary))
data$remote_ratio_scaled <- as.numeric(scale(data$remote_ratio))
data$exp_level_ord_scaled <- as.numeric(scale(data$exp_level_ord))
data$company_size_ord_scaled <- as.numeric(scale(data$company_size_ord))


## Final verification
cat("Rows after cleaning:", nrow(data), "\n")                 ### 565
cat("Missing values after cleaning:", sum(is.na(data)), "\n") ### 0
cat("Duplicates after cleaning:", sum(duplicated(data)), "\n")### 0

## Contingency tables for downstream planning (reviewer notes 3 & 5)
### Job Category x Experience Level: check for sparse interaction cells
### (Other = 15, Research = 16 -> some cells may be near-empty)
print(table(data$job_category, data$experience_level))

### Location x Residence overlap: quantifies collinearity between the two
### dummy sets (diagonal = employees whose company location matches residence)
print(table(data$location_group, data$residence_group))
cat("is_local = 1 (location == residence):", sum(data$is_local),
    "of", nrow(data), "rows\n")

## Data dictionary (for report appendix)
data_dictionary <- data.frame(
  Variable = c("work_year", "experience_level", "employment_type", "job_title",
               "salary", "salary_currency", "salary_in_usd", "employee_residence",
               "remote_ratio", "company_location", "company_size", "log_salary",
               "job_category", "exp_level_ord", "company_size_ord",
               "location_group", "residence_group", "is_local", "job_cat_*",
               "empl_*", "loc_*", "res_*", "*_scaled"),
  Type = c("numeric", "character", "character", "character", "numeric",
           "character", "numeric", "character", "numeric", "character",
           "character", "numeric", "factor", "ordinal (1-4)", "ordinal (1-3)",
           "factor", "factor", "binary (0/1)", "one-hot (6)", "one-hot (3)",
           "one-hot (7)", "one-hot (7)", "z-score"),
  Meaning = c("Year the salary was paid", "Experience level (EN/MI/SE/EX)",
              "Employment type (PT/FT/CT/FL)", "Original granular job title",
              "Gross salary in original currency", "ISO 4217 currency code",
              "Salary converted to USD (response)", "Employee's country of residence",
              "Remote work ratio (0/50/100)", "Employer's country",
              "Company size (S/M/L)", "ln(salary_in_usd) for modeling",
              "Grouped job category (7 levels)", "Ordinal encoding of experience",
              "Ordinal encoding of company size", "Top-7 countries + Other",
              "Top-7 countries + Other (residence)",
              "1 if company_location == employee_residence",
              "Dummies of job_category (ref: Data_Analyst)",
              "Dummies of employment_type (ref: FT)", "Dummies of location_group (ref: Other)",
              "Dummies of residence_group (ref: Other)", "Standardized numeric features")
)
print(data_dictionary)


## Save cleaned + encoded dataset (single source of truth for Tasks 3-5)
write.csv(data, "dataset/ds_salaries_clean.csv", row.names = FALSE)


## Diagnostic outputs feeding Task 2 (EDA)
### Distribution of salary_in_usd (raw vs log)
ggplot(data, aes(x = salary_in_usd)) +
  geom_histogram(fill = "skyblue", color = "white", bins = 30) +
  scale_x_continuous(labels = scales::dollar) +
  theme_minimal() +
  labs(title = "Distribution of Salary (USD)", x = "Salary in USD", y = "Count")

ggplot(data, aes(x = log_salary)) +
  geom_histogram(fill = "skyblue", color = "white", bins = 30) +
  theme_minimal() +
  labs(title = "Distribution of ln(Salary)", x = "ln(Salary in USD)", y = "Count")

### Salary by job category (log scale for readability)
ggplot(data, aes(x = job_category, y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  coord_flip() +
  theme_minimal() +
  labs(title = "ln(Salary) by Job Category", x = "", y = "ln(Salary in USD)")

### Salary by experience level (log scale for readability)
ggplot(data, aes(x = experience_level, y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  theme_minimal() +
  labs(title = "ln(Salary) by Experience Level", x = "Experience Level", y = "ln(Salary in USD)")

### Salary by company size (log scale for readability)
ggplot(data, aes(x = company_size, y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  theme_minimal() +
  labs(title = "ln(Salary) by Company Size", x = "Company Size", y = "ln(Salary in USD)")

### Salary by employment type (log scale for readability)
ggplot(data, aes(x = employment_type, y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  theme_minimal() +
  labs(title = "ln(Salary) by Employment Type", x = "Employment Type", y = "ln(Salary in USD)")

### Salary by remote work ratio (discrete: 0/50/100, log scale)
ggplot(data, aes(x = factor(remote_ratio), y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  theme_minimal() +
  labs(title = "ln(Salary) by Remote Work Ratio", x = "Remote Ratio (%)", y = "ln(Salary in USD)")

### Salary by company location group (log scale for readability)
ggplot(data, aes(x = location_group, y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  coord_flip() +
  theme_minimal() +
  labs(title = "ln(Salary) by Company Location", x = "", y = "ln(Salary in USD)")

### Salary trend over time (work-year)
ggplot(data, aes(x = factor(work_year), y = log_salary)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  theme_minimal() +
  labs(title = "ln(Salary) by Work Year", x = "Work Year", y = "ln(Salary in USD)")

### Category sizes
ggplot(data, aes(x = job_category)) +
  geom_bar(fill = "skyblue") +
  coord_flip() +
  theme_minimal() +
  labs(title = "Number of Jobs per Category", x = "", y = "Count")