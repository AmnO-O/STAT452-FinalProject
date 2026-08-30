import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import StratifiedKFold
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (accuracy_score, precision_score, recall_score,
                             roc_auc_score, f1_score)

# Set random seed cho tính lặp lại (reproducibility)
SEED = 2026
np.random.seed(SEED)
torch.manual_seed(SEED)

# ========================================================================
# 1. LOAD DATASET
# ========================================================================
train = pd.read_csv("train_data.csv")
test  = pd.read_csv("test_data.csv")
print(f"Train rows = {train.shape[0]}, Test rows = {test.shape[0]}")

# Biến Target: 1 = Yes (sought treatment), 0 = No
y_train = (train["Treatment_Cat"] == "Yes").astype(int).values
y_test  = (test["Treatment_Cat"]  == "Yes").astype(int).values
print(f"Treatment rate: Train = {y_train.mean():.3f} | Test = {y_test.mean():.3f}")

# ========================================================================
# 2. FEATURE ENGINEERING (DESIGN MATRIX)
# ========================================================================
# Bao gồm toàn bộ biến định lượng (đã bổ sung Industry_Support_Rating)
cont_cols = [
    "Age", 
    "Employer_Mental_Importance", 
    "Employer_Phys_Importance", 
    "Coworker_Reaction_Score",
    "Industry_Support_Rating"
]

# Các biến định tính (Drop nhóm base)
cat_cols  = {
    "Gender_Category":  ["Female", "Other"],          # Base: Male
    "Family_History":   ["I don't know", "Yes"],      # Base: No
    "Tech_Company_Cat": ["Yes"],                      # Base: No
}

def design_matrix(df):
    parts = [np.asarray(df[c], dtype=float) for c in cont_cols]
    for col, levels in cat_cols.items():
        for lv in levels:
            parts.append((df[col] == lv).astype(float).values)
    return np.column_stack(parts)

X_train_raw = design_matrix(train)
X_test_raw  = design_matrix(test)
print(f"Total features extracted = {X_train_raw.shape[1]}")

# Fit Scaler CHỈ TRÊN TRAIN SET để chống Data Leakage
scaler = StandardScaler().fit(X_train_raw)
X_train = scaler.transform(X_train_raw)
X_test  = scaler.transform(X_test_raw)

# ========================================================================
# 3. BASELINE MODEL: LOGISTIC REGRESSION
# ========================================================================
lr = LogisticRegression(penalty=None, max_iter=5000, random_state=SEED)
lr.fit(X_train, y_train)

p_lr = lr.predict_proba(X_test)[:, 1]
yhat_lr = (p_lr >= 0.5).astype(int)

print("\n" + "="*40)
print("=== LOGISTIC REGRESSION BASELINE ===")
print("="*40)
print(f"Accuracy  : {accuracy_score(y_test, yhat_lr):.3f}")
print(f"Precision : {precision_score(y_test, yhat_lr):.3f}")
print(f"Recall    : {recall_score(y_test, yhat_lr):.3f}")
print(f"F1-Score  : {f1_score(y_test, yhat_lr):.3f}")
print(f"ROC-AUC   : {roc_auc_score(y_test, p_lr):.3f}")

# ========================================================================
# 4. RANDOM FOREST CLASSIFIER (tree-based baseline)
# ========================================================================
# Trees are invariant to monotone scaling, so we use the RAW features.
# Hyperparameters are tuned by 5-fold stratified CV on the training set,
# choosing the config with the best mean validation ROC-AUC.
rf_params = [
    (100,  None),   # n_estimators, max_depth
    (200,  None),
    (100,  5),
    (200,  10),
]
best_rf = None
best_rf_cv = -1
for n_est, depth in rf_params:
    cv_aucs = []
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
    for tr_idx, val_idx in skf.split(X_train_raw, y_train):
        rf = RandomForestClassifier(
            n_estimators=n_est, max_depth=depth, random_state=SEED,
            class_weight="balanced", n_jobs=-1)
        rf.fit(X_train_raw[tr_idx], y_train[tr_idx])
        p_rf = rf.predict_proba(X_train_raw[val_idx])[:, 1]
        cv_aucs.append(roc_auc_score(y_train[val_idx], p_rf))
    mean_auc = np.mean(cv_aucs)
    label = f"RF(n={n_est}, depth={depth})"
    print(f"{label:<24} -> Mean 5-Fold Validation AUC = {mean_auc:.4f}")
    if mean_auc > best_rf_cv:
        best_rf_cv = mean_auc
        best_rf = (n_est, depth)

rf_final = RandomForestClassifier(
    n_estimators=best_rf[0], max_depth=best_rf[1], random_state=SEED,
    class_weight="balanced", n_jobs=-1)
rf_final.fit(X_train_raw, y_train)
p_rf = rf_final.predict_proba(X_test_raw)[:, 1]
yhat_rf = (p_rf >= 0.5).astype(int)

print("\n" + "="*40)
print("=== RANDOM FOREST CLASSIFIER ===")
print("="*40)
print(f"Best Config via CV      : n_estimators={best_rf[0]}, max_depth={best_rf[1]} (CV AUC: {best_rf_cv:.4f})")
print(f"Accuracy  : {accuracy_score(y_test, yhat_rf):.3f}")
print(f"Precision : {precision_score(y_test, yhat_rf):.3f}")
print(f"Recall    : {recall_score(y_test, yhat_rf):.3f}")
print(f"F1-Score  : {f1_score(y_test, yhat_rf):.3f}")
print(f"ROC-AUC   : {roc_auc_score(y_test, p_rf):.3f}")

# Feature importance (from the tuned RF, most important predictor first)
feat_names = (list(cont_cols)
              + [f"{col}{lv}" for col, levels in cat_cols.items() for lv in levels])
imp = sorted(zip(feat_names, rf_final.feature_importances_),
             key=lambda t: -t[1])
print("\nTop feature importances (Random Forest):")
for name, v in imp:
    print(f"  {name:<30} {v:.3f}")

# ========================================================================
# 5. NEURAL NETWORK ARCHITECTURE & CROSS-VALIDATION
# ========================================================================
class SmallMLP(nn.Module):
    def __init__(self, in_dim, hidden, drop):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_dim, hidden),
            nn.ReLU(),
            nn.Dropout(drop),
            nn.Linear(hidden, 1)
        )
    def forward(self, x):
        return self.net(x).squeeze(-1)

def train_single_epoch(model, opt, loss_fn, X_batch, y_batch):
    model.train()
    opt.zero_grad()
    loss = loss_fn(model(X_batch), y_batch)
    loss.backward()
    opt.step()
    return loss.item()

def evaluate_nn(model, X_eval):
    model.eval()
    with torch.no_grad():
        logits = model(X_eval).numpy()
    return 1.0 / (1.0 + np.exp(-logits))

# 5-Fold Cross-Validation trên tập Train để chọn Hyperparameters
def cross_validate_mlp(hidden, drop, decay, epochs=300, lr=1e-2):
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
    val_aucs = []
    
    for tr_idx, val_idx in skf.split(X_train, y_train):
        X_tr_f, y_tr_f = torch.tensor(X_train[tr_idx], dtype=torch.float32), torch.tensor(y_train[tr_idx], dtype=torch.float32)
        X_va_f, y_va_f = torch.tensor(X_train[val_idx], dtype=torch.float32), y_train[val_idx]
        
        model = SmallMLP(X_train.shape[1], hidden, drop)
        opt = torch.optim.Adam(model.parameters(), lr=lr, weight_decay=decay)
        loss_fn = nn.BCEWithLogitsLoss()
        
        for ep in range(epochs):
            train_single_epoch(model, opt, loss_fn, X_tr_f, y_tr_f)
            
        p_val = evaluate_nn(model, X_va_f)
        val_aucs.append(roc_auc_score(y_va_f, p_val))
        
    return np.mean(val_aucs)

# Grid Search các cấu hình
configs = [
    (2, 0.00, 0.0), 
    (2, 0.20, 1e-3), 
    (3, 0.20, 1e-3),
    (3, 0.30, 1e-2), 
    (5, 0.20, 1e-3), 
    (8, 0.30, 1e-2)
]

print("\n" + "="*40)
print("=== 5-FOLD CROSS-VALIDATION HYPERPARAMETER TUNING ===")
print("="*40)

best_cfg = None
best_cv_auc = -1

for h, d, dec in configs:
    cv_auc = cross_validate_mlp(h, d, dec)
    print(f"MLP (h={h:2d}, drop={d:.1f}, L2={dec:<5}) -> Mean 5-Fold Validation AUC = {cv_auc:.4f}")
    if cv_auc > best_cv_auc:
        best_cv_auc = cv_auc
        best_cfg = (h, d, dec)

print(f"\nBest Config selected via CV: Hidden={best_cfg[0]}, Dropout={best_cfg[1]}, L2={best_cfg[2]} (CV AUC: {best_cv_auc:.4f})")

# ========================================================================
# 5. RETRAIN BEST MLP ON FULL TRAIN SET & EVALUATE ON TEST SET
# ========================================================================
X_tr_tensor = torch.tensor(X_train, dtype=torch.float32)
y_tr_tensor = torch.tensor(y_train, dtype=torch.float32)
X_te_tensor = torch.tensor(X_test,  dtype=torch.float32)

best_h, best_d, best_dec = best_cfg
final_model = SmallMLP(X_train.shape[1], best_h, best_d)
opt = torch.optim.Adam(final_model.parameters(), lr=1e-2, weight_decay=best_dec)
loss_fn = nn.BCEWithLogitsLoss()

# Retrain toàn bộ trên Train set
for ep in range(300):
    train_single_epoch(final_model, opt, loss_fn, X_tr_tensor, y_tr_tensor)

p_nn = evaluate_nn(final_model, X_te_tensor)
yhat_nn = (p_nn >= 0.5).astype(int)

print("\n" + "="*40)
print("=== FINAL TEST SET PERFORMANCE COMPARISON ===")
print("="*40)
print(f"Logistic Regression Baseline -> Acc: {accuracy_score(y_test, yhat_lr):.3f} | ROC-AUC: {roc_auc_score(y_test, p_lr):.3f}")
print(f"Best Neural Network (MLP)   -> Acc: {accuracy_score(y_test, yhat_nn):.3f} | ROC-AUC: {roc_auc_score(y_test, p_nn):.3f}")
print("="*40)
