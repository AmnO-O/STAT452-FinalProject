library(tidyverse)
library(randomForest)
library(caret)

data <- read.csv("dataset/ds_salaries_clean.csv")

set.seed(2026)
used_cols <- c("log_salary", "salary_in_usd", "experience_level", "employment_type",
               "company_size", "job_category", "location_group", "remote_ratio",
               "is_local", "work_year", "exp_level_ord", "company_size_ord",
               "remote_ratio", "work_year")
stopifnot(nrow(data) == 565, sum(is.na(data[, intersect(used_cols, names(data))])) == 0)

data$experience_level <- factor(data$experience_level, levels = c("EN", "MI", "SE", "EX"))
data$company_size     <- factor(data$company_size,     levels = c("S", "M", "L"))
data$employment_type  <- relevel(factor(data$employment_type), ref = "FT")
data$job_category     <- relevel(factor(data$job_category),   ref = "Data_Analyst")
data$location_group   <- relevel(factor(data$location_group), ref = "Other")

data <- data %>% mutate(row_id = row_number())

check_vars <- c("employment_type", "job_category", "location_group",
                 "experience_level", "company_size")

repeat {
  idx <- sample(nrow(data), floor(0.8 * nrow(data)))
  tr  <- data[idx, ]
  te  <- data[-idx, ]
  ok  <- all(vapply(check_vars,
                      function(v) all(unique(te[[v]]) %in% unique(tr[[v]])), logical(1)))
  if (ok) break
}
train <- tr
test  <- te

stopifnot(nrow(train) == 452, nrow(test) == 113,
          all(!test$row_id %in% train$row_id))

rf_model <- randomForest(
  log_salary ~ experience_level + job_category + employment_type +
    company_size + location_group + remote_ratio + work_year + is_local,
  data = train,
  ntree = 500,
  importance = TRUE,
  seed = 2026
)

print(rf_model)
print(paste("Number of trees:", rf_model$ntree))
print(paste("MSE:", round(rf_model$mse[rf_model$ntree], 6)))
print(paste("R-squared (in-sample):", round(1 - rf_model$mse[rf_model$ntree] / var(train$log_salary), 4)))

pred_train <- predict(rf_model, newdata = train)
pred_test  <- predict(rf_model, newdata = test)

rmse_log <- sqrt(mean((test$log_salary - pred_test)^2))
mae_log  <- mean(abs(test$log_salary - pred_test))
r2_log   <- 1 - sum((test$log_salary - pred_test)^2) / sum((test$log_salary - mean(test$log_salary))^2)

rmse_usd <- sqrt(mean((test$salary_in_usd - exp(pred_test))^2))
mae_usd  <- mean(abs(test$salary_in_usd - exp(pred_test)))
r2_usd   <- 1 - sum((test$salary_in_usd - exp(pred_test))^2) / sum((test$salary_in_usd - mean(test$salary_in_usd))^2)

cat("\n=== Random Forest Test Set Performance ===\n")
cat("RMSE (log):", round(rmse_log, 6), "\n")
cat("MAE  (log):", round(mae_log, 6), "\n")
cat("R2   (log):", round(r2_log, 4), "\n")
cat("RMSE (USD):", round(rmse_usd, 2), "\n")
cat("MAE  (USD):", round(mae_usd, 2), "\n")
cat("R2   (USD):", round(r2_usd, 4), "\n")

importance_df <- importance(rf_model) %>%
  as.data.frame() %>%
  rownames_to_column("Variable") %>%
  arrange(desc(`%IncMSE`)) %>%
  select(Variable, `%IncMSE`, `IncNodePurity`)

print(importance_df)

par(mfrow = c(1, 2))

png("task08_rf_variable_importance.png", width = 800, height = 600)
varImpPlot(rf_model, main = "Random Forest - Variable Importance (% IncMSE)",
           col = "steelblue", cex = 0.8)
dev.off()

png("task08_rf_actual_vs_predicted.png", width = 800, height = 600)
plot(test$salary_in_usd, exp(pred_test),
     col = "steelblue", pch = 19, alpha = 0.6,
     xlab = "Actual Salary (USD)", ylab = "Predicted Salary (USD)",
     main = "Random Forest: Actual vs Predicted Salary (USD)")
abline(0, 1, col = "red", lty = "dashed")
dev.off()

par(mfrow = c(1, 1))

comparison <- read.csv("task04_model_comparison.csv")

rf_row <- tibble(
  model = "Random Forest regression",
  RMSE_log = rmse_log,
  MAE_log = mae_log,
  R2_log = r2_log,
  RMSE_usd = rmse_usd,
  MAE_usd = mae_usd,
  R2_usd = r2_usd
)

comparison <- bind_rows(comparison, rf_row) %>% arrange(RMSE_usd)

write.csv(comparison, "task04_model_comparison.csv", row.names = FALSE)

cat("\n=== Updated Model Comparison (ranked by USD RMSE) ===\n")
print(comparison %>% mutate(across(c(RMSE_usd, MAE_usd), ~ round(.x, 2))))
