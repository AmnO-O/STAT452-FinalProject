library(tidyverse)
library(caret)
library(pROC)
library(randomForest)

data <- read.csv("dataset/osmi_clean_combined.csv")

# Ensure reference levels are set logically for interpretation
data <- data %>%
  mutate(
    Treatment_Cat = factor(Treatment_Cat, levels = c("No", "Yes")),
    Gender_Category = relevel(factor(Gender_Category), ref = "Male"),
    Family_History = relevel(factor(Family_History), ref = "No"),
    Tech_Company_Cat = relevel(factor(Tech_Company_Cat), ref = "No")
  )

set.seed(2026)
train_idx <- sample(nrow(data), floor(0.8 * nrow(data)))
train <- data[train_idx, ]
test  <- data[-train_idx, ]

cat("Training cases:", nrow(train), "| Test cases:", nrow(test), "\n")

# Random Forest needs its own package
library(randomForest)

# Numeric design matrix (same predictors as the logistic model) for x/y interface
rf_X <- model.matrix(
  ~ Age + Gender_Category + Family_History + Employer_Mental_Importance +
    Employer_Phys_Importance + Coworker_Reaction_Score + Tech_Company_Cat,
  data = train
)[, -1]
rf_y <- train$Treatment_Cat

# Fit Random Forest on full training set with importance=TRUE
set.seed(123)
rf_model <- randomForest(
  x = rf_X, y = rf_y,
  mtry = 3, maxnodes = 16, ntree = 300,
  importance = TRUE
)

# Predict on the held-out test set
rf_X_test <- model.matrix(
  ~ Age + Gender_Category + Family_History + Employer_Mental_Importance +
    Employer_Phys_Importance + Coworker_Reaction_Score + Tech_Company_Cat,
  data = test
)[, -1]
rf_probs <- predict(rf_model, rf_X_test, type = "prob")[, "Yes"]

# ROC curve
rf_curve <- roc(test$Treatment_Cat, rf_probs)
rf_auc <- as.numeric(auc(rf_curve))

# Variable importance: aggregate dummy-level rows back to their original predictors
raw_imp <- importance(rf_model)[, "MeanDecreaseAccuracy", drop = FALSE]
base_names <- sub('(Gender_Category|Family_History|Tech_Company_Cat).*', '\\1',
                  rownames(raw_imp))
imp_by_predictor <- rowsum(raw_imp[, 1], base_names, reorder = FALSE)
rf_imp <- imp_by_predictor[, 1]
names(rf_imp) <- rownames(imp_by_predictor)

rf_imp_df <- data.frame(
  Predictor = names(rf_imp),
  MeanDecreaseAccuracy = round(rf_imp, 2)
) %>%
  arrange(desc(MeanDecreaseAccuracy))

# Set up plotting area: 1 row, 2 columns
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))

# Plot 1: ROC Curve
plot(rf_curve, col = "darkgreen", lwd = 2,
     main = paste("Random Forest ROC Curve (AUC =", round(rf_auc, 3), ")"),
     xlab = "1 - Specificity", ylab = "Sensitivity")
abline(a = 0, b = 1, lty = 2, col = "gray")
legend("bottomright", legend = paste("AUC =", round(rf_auc, 3)),
       col = "darkgreen", lwd = 2, bty = "n")

# Plot 2: Variable Importance
barplot(rf_imp_df$MeanDecreaseAccuracy,
        names.arg = rf_imp_df$Predictor,
        col = "steelblue",
        main = "Random Forest Variable Importance\n(Mean Decrease in Accuracy)",
        xlab = "Predictor", ylab = "Mean Decrease in Accuracy",
        las = 2, cex.names = 0.7)

# Reset plotting parameters
par(mfrow = c(1, 1))

cat("\nRandom Forest ROC-AUC:", round(rf_auc, 3), "\n")
cat("Variable importance ranked:\n")
print(rf_imp_df)