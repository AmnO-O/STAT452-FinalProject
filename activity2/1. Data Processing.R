library(tidyverse)
library(scales)

# 0 Data Integration (Combining 5 Datasets)

## Define a robust function to load and extract target columns using regex
## Justification: Column names and positions change across survey years.
load_osmi <- function(file_path, year) {
  df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
  
  # Helper function to grab the first matching column name
  get_col <- function(pattern) {
    matched <- grep(pattern, names(df), value = TRUE, ignore.case = TRUE)
    if (length(matched) == 0) return(NULL)
    matched[1] # Take the first match (current employer, not previous)
  }
  
  col_age       <- get_col("^what is your age|\\bage\\b")
  col_gender    <- get_col("what is your gender|^gender")
  col_treat     <- get_col("sought treatment for a mental health")
  col_tech      <- get_col("primarily a tech company")
  col_phys      <- get_col("importance does your employer place on physical")
  col_mental    <- get_col("importance does your employer place on mental")
  col_coworker  <- get_col("team members/co-workers would react|co-workers would react")
  col_industry  <- get_col("tech industry supports employees")
  col_family    <- get_col("family history of mental")
  
  df_clean <- tibble(
    Age                        = as.numeric(df[[col_age]]),
    Gender                     = as.character(df[[col_gender]]),
    Treatment                  = df[[col_treat]],
    Tech_Company               = df[[col_tech]],
    Employer_Phys_Importance   = as.numeric(df[[col_phys]]),
    Employer_Mental_Importance = as.numeric(df[[col_mental]]),
    Coworker_Reaction_Score    = as.numeric(df[[col_coworker]]),
    Industry_Support_Rating    = as.numeric(df[[col_industry]]),
    Family_History             = as.character(df[[col_family]]),
    Year                       = as.integer(year)
  )
  
  return(df_clean)
}

## Load and merge the datasets
df_2018 <- load_osmi("dataset/OSMI_Mental_Health_In_Teach_Industry_2018.csv", 2018)
df_2019 <- load_osmi("dataset/OSMI_Mental_Health_In_Teach_Industry_2019.csv", 2019)
df_2020 <- load_osmi("dataset/OSMI_Mental_Health_In_Teach_Industry_2020.csv", 2020)
df_2021 <- load_osmi("dataset/OSMI_Mental_Health_In_Teach_Industry_2021.csv", 2021)
df_2022 <- load_osmi("dataset/OSMI_Mental_Health_In_Teach_Industry_2022.csv", 2022)

data <- bind_rows(df_2018, df_2019, df_2020, df_2021, df_2022)
cat("Initial combined rows:", nrow(data), "\n")


# 1 Data Preprocessing

## Check for missing values
missing_values <- colSums(is.na(data))
print(missing_values)

## Drop NAs from crucial numerical predictors
## Justification: Freelancers/self-employed individuals skipped company-specific 
## questions, generating legitimate NAs. We drop them to focus purely on corporate employees.
data <- data %>% drop_na(Employer_Mental_Importance, Employer_Phys_Importance, Tech_Company)
cat("Rows after NA removal:", nrow(data), "\n")

## Check for duplicate rows
duplicate_rows <- data[duplicated(data), ]
print(nrow(duplicate_rows))

## Remove duplicate records (keep the first occurrence)
data <- data %>% distinct()
cat("Rows after removing duplicates:", nrow(data), "\n")

## Detect outliers in Age (IQR rule) AFTER de-duplication
### Boxplot to visualize extreme inputs
ggplot(data, aes(x = "", y = Age)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red", outlier.shape = 16) +
  theme_minimal() +
  labs(title = "Detecting Outliers in Age", x = "", y = "Age")

### Calculate IQR parameters
Q1 <- quantile(data$Age, 0.25, na.rm = TRUE)
Q3 <- quantile(data$Age, 0.75, na.rm = TRUE)
IQR_value <- Q3 - Q1
lower_bound <- Q1 - 1.5 * IQR_value
upper_bound <- Q3 + 1.5 * IQR_value

outlier_rows <- data %>% filter(Age < lower_bound | Age > upper_bound)
cat("Total IQR Outliers Detected in Age:", nrow(outlier_rows), "\n")

## Outlier decision (D1): FILTER working-age individuals
## Justification: Unlike salary where extreme highs are valid, an age of 2 or 329
## is a definitive data-entry error. We hard-cap to the valid working age (18-65).
data <- data %>% filter(Age >= 18 & Age <= 65)

## Group granular text variables (Gender normalization)
data <- data %>%
  mutate(
    Gender = str_trim(tolower(Gender)),
    Gender_Category = case_when(
      str_detect(Gender, "^f|female|woman|cis female|femmina") ~ "Female",
      
      str_detect(Gender, "^m$|\\bmale\\b|\\bman\\b|cis male|dude|masculin") ~ "Male",
      
      TRUE ~ "Other"
    )
  )

### Validation: no gender left unmapped
stopifnot(sum(is.na(data$Gender_Category)) == 0)

## Encode binary categorical variables
data <- data %>%
  mutate(
    Treatment_Cat = ifelse(Treatment == 1 | str_detect(tolower(Treatment), "yes"), "Yes", "No"),
    Tech_Company_Cat = ifelse(Tech_Company == 1 | str_detect(tolower(Tech_Company), "yes"), "Yes", "No")
  )

## One-hot encoding helper with an EXPLICIT reference level
one_hot <- function(df, col, prefix, ref_level) {
  f <- relevel(factor(df[[col]]), ref = ref_level)
  mm <- as.data.frame(model.matrix(~ f - 1, data = df)[, -1, drop = FALSE])
  colnames(mm) <- paste0(prefix, gsub("[^[:alnum:]]", "_", levels(f)[-1]))
  mm
}

## One-hot: Gender_Category, Family_History
## Reference levels are explicit: Male (dominant), No (clear baseline).
data <- bind_cols(
  data,
  one_hot(data, "Gender_Category", "gender_", ref_level = "Male"),
  one_hot(data, "Family_History", "fam_hist_", ref_level = "No")
)

## Convert targets and time variable to explicit factors
data$Treatment_Cat <- relevel(factor(data$Treatment_Cat), ref = "No")
data$Tech_Company_Cat <- relevel(factor(data$Tech_Company_Cat), ref = "No")
data$Year <- factor(data$Year)

## Scale numerical features (z-score) for penalized models
## Raw columns are preserved for interpretable models (MLR).
data$Age_scaled <- as.numeric(scale(data$Age))
data$Employer_Phys_scaled <- as.numeric(scale(data$Employer_Phys_Importance))
data$Employer_Mental_scaled <- as.numeric(scale(data$Employer_Mental_Importance))
data$Coworker_Reaction_scaled <- as.numeric(scale(data$Coworker_Reaction_Score))


## Final verification
cat("Rows after cleaning:", nrow(data), "\n") 
cat("Missing values after cleaning:", sum(is.na(data)), "\n") 

## Contingency tables for downstream planning
print(table(data$Gender_Category, data$Treatment_Cat))


## Data dictionary (for report appendix)
data_dictionary <- data.frame(
  Variable = c("Age", "Employer_Phys_Importance", "Employer_Mental_Importance", 
               "Coworker_Reaction_Score", "Industry_Support_Rating",
               "Treatment_Cat", "Tech_Company_Cat", "Family_History", 
               "Gender_Category", "Year", "gender_*", "fam_hist_*", "*_scaled"),
  Type = c("numeric", "numeric", "numeric", "numeric", "numeric",
           "factor", "factor", "factor", "factor", "factor", 
           "one-hot", "one-hot", "z-score"),
  Meaning = c("Age of respondent", "Importance of physical health (0-10)", 
              "Importance of mental health (0-10)", "Coworker reaction score (0-10)",
              "Tech industry support rating", "Sought professional treatment?", 
              "Is employer a tech company?", "Family history of mental illness", 
              "Normalized gender groups", "Survey year", 
              "Dummies of Gender (ref: Male)", "Dummies of Family History (ref: No)", 
              "Standardized numeric features")
)
print(data_dictionary)


## Save cleaned dataset (single source of truth for downstream models)
write.csv(data, "dataset/osmi_clean_combined.csv", row.names = FALSE)


## Diagnostic outputs feeding Task 2 (EDA)
### Treatment Distribution
ggplot(data, aes(x = Treatment_Cat)) +
  geom_bar(fill = "skyblue", color = "black") +
  theme_minimal() +
  labs(title = "Distribution of Treatment Status", x = "Sought Treatment?", y = "Count")

### Mental Health Importance by Year
ggplot(data, aes(x = Year, y = Employer_Mental_Importance)) +
  geom_boxplot(fill = "skyblue", outlier.color = "red") +
  theme_minimal() +
  labs(title = "Employer Mental Health Importance Over Time", x = "Survey Year", y = "Score")

### Physical vs Mental Importance Scatter Plot
ggplot(data, aes(x = Employer_Phys_Importance, y = Employer_Mental_Importance)) +
  geom_jitter(alpha = 0.5, color = "darkblue", width = 0.2, height = 0.2) +
  geom_smooth(method = "lm", color = "red", se = FALSE) +
  theme_minimal() +
  labs(title = "Correlation: Physical vs Mental Health Importance", 
       x = "Physical Health Importance", y = "Mental Health Importance")

