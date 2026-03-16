import os
import json
from datetime import datetime, UTC

import joblib
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.multioutput import MultiOutputClassifier
from sklearn.metrics import classification_report

from synthetic_data import generate_dataset, FEATURE_COLUMNS, LABEL_COLUMNS

MODEL_DIR = "models"
MODEL_PATH = os.path.join(MODEL_DIR, "dt_alerts.joblib")
META_PATH = os.path.join(MODEL_DIR, "dt_alerts_meta.json")


def main():
    os.makedirs(MODEL_DIR, exist_ok=True)

    # 1) Data
    X, Y = generate_dataset(n_profiles=80, windows_per_profile=120)

    X_train, X_test, Y_train, Y_test = train_test_split(
        X, Y, test_size=0.2, random_state=7
    )

    # 2) Model
    base = DecisionTreeClassifier(
        max_depth=5,
        min_samples_leaf=50,
        random_state=7
    )
    model = MultiOutputClassifier(base)
    model.fit(X_train, Y_train)

    # 3) Evaluate
    Y_pred = model.predict(X_test)

    print("=== Evaluation (each label) ===")
    for i, label in enumerate(LABEL_COLUMNS):
        print(f"\n--- {label} ---")
        print(classification_report(Y_test[label], Y_pred[:, i]))

    # 4) Save model
    joblib.dump(model, MODEL_PATH)

    meta = {
        "feature_columns": FEATURE_COLUMNS,
        "label_columns": LABEL_COLUMNS,
        "trained_at": datetime.now(UTC).isoformat(),   # ✅ fixed (timezone-aware)
        "model_type": "DecisionTree(MultiOutput)"
    }
    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)

    print(f"\nSaved model to: {MODEL_PATH}")
    print(f"Saved meta to:  {META_PATH}")


if __name__ == "__main__":
    main()