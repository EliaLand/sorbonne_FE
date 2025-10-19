<p align="center">
  <img src="Images/sorbonne_logo.png" alt="Logo" width="300"/>
</p>

# **SCORING & ECONOMETRICS - Assignment 1**

**Author**: Elia Landini  
**Student ID**: 12310239  
**Course**: EESM2 – Financial Economics  
**Class**: Scoring and Econometrics  
**Supervisor**: Jean-Bernard Chatelain  

---

## 🧭 **METHODOLOGY & EMPIRICAL APPROACH**

### **1) Preface**
- Reference to training–test sample split and sorting.  
- Criteria: `yd` & `OPITA`.  

---

### **2) Requirements Set-up**
- Python environment initialization.  
- Random seeds and environment variable paths for reproducibility.  

---

### **3) Helper Functions & General Variables**
- Custom helper functions for data manipulation and plotting.  
- Variable naming dictionary (from acronym to full name and inverted).  

---

### **4) Data Retrieval & Manipulation**
- Data retrieval from local dataset (`raw_data.csv`).  
- Descriptive statistics for raw data.  
- Infinite value handling (`-99.99` → `NaN` via NumPy).  
- Data sorting based on `yd` and `OPITA`.  
- Data partitioning into training and testing samples.  

---

## **5) Stage 1 – Econometric Scoring Analysis (Document C, Part 1)**

### **5.1–5.4: Data Exploration & Cleaning**
- Labeling in SAS/STATA and Python equivalents (via attributes).  
- Data handling and descriptive statistics:
  - Handling of missing data using `NaN` substitution and imputation strategies.  
  - Descriptive statistics and skewness–kurtosis diagnosis of normality.  
  - Explanatory variable distribution plotting (with normal PDF overlay).  
  - Outlier detection and adjustment.  
- Distribution analysis:
  - In-sample differential by firm cluster (FD vs NFD).  
  - Group comparison via boxplots, violin plots, and Altman Z-score framework.  
- Correlation diagnosis:
  - Scatter plots and diagonal KDEs.  
  - Pearson correlation matrix (heatmap).  
  - Discussion of statistical significance via p-values and t-stats.  
- Normality and variance tests:
  - Jarque–Bera, Kolmogorov–Smirnov, and Levene tests.  
  - Analysis of distributional equivalence.  
- t-stat equivalence for binary `y`:
  - Pearson correlation, two-sample t-tests, ANOVA, and LPM-based comparisons.  

---

### **5.5–5.9: Correlation & Multicollinearity**
- Computation and ranking of explanatory variables by t-statistics and correlations.  
- Identification of top correlated predictors with `yd`.  
- Multicollinearity diagnosis and discussion of overfitting issues.  

---

### **5.10–5.16: Regression Modeling and Diagnostic Tests**
- **Regression setup:**
  - Scatter plots and KDEs for correlated variables.  
  - Partitioning of `y` (dependent) and `X` (independent) variables.  
- **Model estimation:**
  - Linear Probability Model (LPM), Logit, and Probit.  
  - Comparison of coefficients, t-stats, and fit metrics.  
  - Stargazer HTML summary table generation.  
- **Model validation:**
  - ROC curves and AUC computation for performance evaluation.  
  - Residual analysis (standardized Pearson residuals and outlier detection).  
  - Computation of concordant/discordant pairs.  
- **In-sample and out-of-sample prediction:**
  - Probability predictions with continuous and binary outputs (0.5 threshold).  
  - Comparison of AUCs and ROC curves across models.  
  - Variable selection optimization based on predictive performance.  

---

### **5.17–5.20: Model Evaluation & Conceptual Extensions**
- Type I and Type II error trade-offs and loss function analysis.  
- Sensitivity/specificity assessment by probability cutoff.  
- Threshold optimization based on ROC curves.  
- Empirical applications:
  - Private banker decision simulation.  
  - Credit decision interpretation using model scores.  
  - Estimation of financial metric weights in default prediction.  
- Dummy trap analysis:
  - Theoretical overview and empirical test with multiple regression setups.  
- Summary of adaptations to provided SAS/STATA/Python code.  

---

## **6) Stage 2 – Machine Learning Model (Document C, Part 2)**

### **6.1–6.4: Data Preparation**
- Neural network framework introduction.  
- Literature review on credit scoring models.  
- Stratified train–test splitting for class balance.  
- Feature scaling and preprocessing pipelines.  
- Handling class imbalance using SMOTE, class weights, or sampling.  

---

### **6.5–6.7: Model Design & Training**
- Baseline logistic regression model.  
- Design of a Keras neural network architecture:
  - Dense layers, activation functions, and dropout regularization.  
- Implementation of callbacks:
  - Early stopping, learning rate reduction, and model checkpointing.  

---

### **6.8–6.11: Evaluation & Optimization**
- Out-of-sample validation and scoring.  
- ROC and AUC analysis for performance measurement.  
- Confusion matrix visualization (threshold = 0.5).  
- Hyperparameter tuning and probability calibration.  
- Final threshold selection based on validation metrics.  

---

### **6.12: Model Explainability**
- SHAP (Shapley) values for interpretability of neural networks.  
- Visualization of variable importance and sensitivity to input ratios.  
- Comparison of explainability between econometric and deep learning models.  

---

## **7) Bibliography**
- *Greene* — *Econometric Analysis*  
- *Hosmer & Lemeshow* — *Applied Logistic Regression*  
- *Géron* — *Hands-On Machine Learning with Scikit-Learn, Keras, and TensorFlow*  
- Course slides and official documentation for SAS/STATA equivalents.  

---

