suppressPackageStartupMessages({library(tidyverse); library(MASS); library(glmnet)})
data <- read.csv("activity1/dataset/ds_salaries_clean.csv")
set.seed(2026)
data$experience_level <- factor(data$experience_level, levels = c("EN", "MI", "SE", "EX"))
data$company_size     <- factor(data$company_size,     levels = c("S", "M", "L"))
data$employment_type  <- relevel(factor(data$employment_type), ref = "FT")
data$job_category     <- relevel(factor(data$job_category),   ref = "Data_Analyst")
data$location_group   <- relevel(factor(data$location_group), ref = "Other")

# Plain random 80:20 split (seed 2026)
data <- data %>% mutate(row_id = row_number())
idx <- sample(nrow(data), floor(0.8 * nrow(data)))
train <- data[idx, ]
test  <- data[-idx, ]
check_vars <- c("employment_type", "job_category", "location_group", "experience_level", "company_size")
if (!all(vapply(check_vars, function(v) all(unique(test[[v]]) %in% unique(train[[v]])), logical(1)))) {
  stop("Random split failed to cover all factor levels in train; re-run with different seed")
}
stopifnot(nrow(train) == 452, nrow(test) == 113, all(!test$row_id %in% train$row_id))
rhs <- "experience_level + job_category + employment_type + company_size + location_group + remote_ratio + work_year + is_local"
rhs_raw <- "experience_level + job_category + employment_type + company_size + location_group + remote_ratio + work_year"

ols_raw  <- lm(paste("salary_in_usd ~", rhs_raw), data = train)

img_dir <- "plan/REPORT/img/activity1"
dir.create(img_dir, recursive = TRUE, showWarnings = FALSE)

# Use fine lambda grid (matching Rmd's plotit = TRUE behavior)
lambda_seq <- seq(-2, 2, length = 100)
png(file.path(img_dir, "06_boxcox.png"), width = 8, height = 6, units = "in", res = 220)
bc <- MASS::boxcox(ols_raw, lambda = lambda_seq)
dev.off()
lambda_hat <- bc$x[which.max(bc$y)]
cut_off  <- max(bc$y) - qchisq(0.95, 1) / 2
lambda_ci <- range(bc$x[bc$y >= cut_off])
cat("wrote", file.path(img_dir, "06_boxcox.png"), "| lambda_hat =", round(lambda_hat, 3), "\n")
cat("95% CI: [", round(lambda_ci[1], 3), ",", round(lambda_ci[2], 3), "]\n")

ols_full  <- lm(paste("log_salary ~", rhs), data = train)
ols_step  <- step(ols_full, direction = "both", trace = FALSE)
z_train   <- train$salary_in_usd^lambda_hat
ols_power <- lm(paste("z_train ~", rhs), data = train)
base_terms <- setdiff(attr(terms(ols_step), "term.labels"), c("remote_ratio", "work_year"))
bf <- paste("log_salary ~", paste(base_terms, collapse = " + "))
fit_poly <- function(degree) lm(paste0(bf, " + poly(remote_ratio, ", degree, ") + poly(work_year, ", degree, ")"), data = train)
poly_linear    <- fit_poly(1)
poly_quadratic <- fit_poly(2)
anova_poly <- anova(poly_linear, poly_quadratic)
poly_model <- if (anova_poly$`Pr(>F)`[2] < 0.05) poly_quadratic else poly_linear

tr_scale <- function(col) {
  m <- mean(train[[col]]); s <- sd(train[[col]])
  list(train = (train[[col]] - m) / s, test = (test[[col]] - m) / s)
}
for (col in c("exp_level_ord", "company_size_ord", "remote_ratio", "work_year")) {
  sc <- tr_scale(col); train[[paste0(col, "_ts")]] <- sc$train; test[[paste0(col, "_ts")]] <- sc$test
}
build_matrix <- function(df) model.matrix(~ exp_level_ord_ts + company_size_ord_ts + remote_ratio_ts + work_year_ts + job_category + employment_type + location_group + is_local, data = df)[, -1]
x_train <- build_matrix(train); x_test <- build_matrix(test)
y_train <- train$log_salary; y_test <- test$log_salary
set.seed(2026); cv_ridge   <- cv.glmnet(x_train, y_train, alpha = 0, nfolds = 10)
set.seed(2026); cv_lasso   <- cv.glmnet(x_train, y_train, alpha = 1, nfolds = 10)
set.seed(2026); cv_elastic <- cv.glmnet(x_train, y_train, alpha = 0.1, nfolds = 10)

pred_log <- list(
  `Full OLS`             = predict(ols_full, newdata = test),
  `Stepwise-reduced OLS` = predict(ols_step, newdata = test),
  `Polynomial regression`= predict(poly_model, newdata = test),
  `Ridge regression`     = as.numeric(predict(cv_ridge, newx = x_test, s = "lambda.min")),
  `LASSO regression`     = as.numeric(predict(cv_lasso, newx = x_test, s = "lambda.min")),
  `Elastic net regression` = as.numeric(predict(cv_elastic, newx = x_test, s = "lambda.min")))
smear <- c(`Full OLS` = mean(exp(resid(ols_full))),
           `Stepwise-reduced OLS` = mean(exp(resid(ols_step))),
           `Polynomial regression` = mean(exp(resid(poly_model))),
           `Ridge regression` = mean(exp(y_train - as.numeric(predict(cv_ridge, newx = x_train, s = "lambda.min")))),
           `LASSO regression` = mean(exp(y_train - as.numeric(predict(cv_lasso, newx = x_train, s = "lambda.min")))),
           `Elastic net regression` = mean(exp(y_train - as.numeric(predict(cv_elastic, newx = x_train, s = "lambda.min")))))
metrics_row <- function(model_name, pred_log_vals, y_log, smear_val) {
  err_log <- pred_log_vals - y_log
  r2_log  <- 1 - sum(err_log^2) / sum((y_log - mean(y_log))^2)
  pred_usd <- exp(pred_log_vals) * smear_val; y_usd <- exp(y_log); err_usd <- pred_usd - y_usd
  r2_usd  <- 1 - sum(err_usd^2) / sum((y_usd - mean(y_usd))^2)
  tibble(model = model_name, RMSE_log = sqrt(mean(err_log^2)), MAE_log = mean(abs(err_log)),
         R2_log = r2_log, RMSE_usd = sqrt(mean(err_usd^2)), MAE_usd = mean(abs(err_usd)), R2_usd = r2_usd)
}
z_hat <- as.numeric(predict(ols_power, newdata = test)); resid_z <- residuals(ols_power)
pred_power <- vapply(z_hat, function(zj) mean((pmax(zj + resid_z, 1e-6))^(1 / lambda_hat)), numeric(1))
comparison_table <- bind_rows(
  metrics_row("Multiple linear regression - full", pred_log$`Full OLS`, y_test, smear["Full OLS"]),
  metrics_row("Multiple linear regression - stepwise", pred_log$`Stepwise-reduced OLS`, y_test, smear["Stepwise-reduced OLS"]),
  metrics_row("Polynomial regression", pred_log$`Polynomial regression`, y_test, smear["Polynomial regression"]),
  metrics_row("Ridge regression", pred_log$`Ridge regression`, y_test, smear["Ridge regression"]),
  metrics_row("LASSO regression", pred_log$`LASSO regression`, y_test, smear["LASSO regression"]),
  metrics_row("Elastic net regression", pred_log$`Elastic net regression`, y_test, smear["Elastic net regression"]),
  metrics_row(paste0("Power-transformed OLS (salary^", round(lambda_hat, 2), ")"), log(pred_power), y_test, 1))

png(file.path(img_dir, "06_test_rmse_dotplot.png"), width = 8, height = 6, units = "in", res = 220)
op <- par(mar = c(4.5, 14, 2.5, 1))
ord <- order(comparison_table$RMSE_log)
plot(comparison_table$RMSE_log[ord], seq_along(ord), pch = 19,
     xlim = c(0.410, 0.4255), xlab = "Test RMSE, log scale",
     yaxt = "n", ylab = "", main = "Six candidates on one held-out set")
axis(2, at = seq_along(ord), labels = comparison_table$model[ord],
     las = 1, cex.axis = 0.75)
best <- min(comparison_table$RMSE_log)
abline(v = best, lty = 2, col = "grey55")
text(best, length(ord) + 0.4, sprintf("best = %.4f (power OLS)", best),
     pos = 3, offset = 0.2, col = "grey30", cex = 0.85)
par(op)
dev.off()
cat("wrote", file.path(img_dir, "06_test_rmse_dotplot.png"), "\n")

png(file.path(img_dir, "06_ridge_lasso_cv.png"), width = 9, height = 8, units = "in", res = 220)
par(mfrow = c(2, 1))
plot(cv_ridge); title(main = "Ridge cross-validation curve", line = 2.5)
plot(cv_lasso); title(main = "LASSO cross-validation curve", line = 2.5)
par(mfrow = c(1, 1))
dev.off()
cat("wrote", file.path(img_dir, "06_ridge_lasso_cv.png"), "\n")

print(as.data.frame(comparison_table)[, c("model", "RMSE_log", "RMSE_usd")])