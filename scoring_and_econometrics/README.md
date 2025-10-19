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

## **METHODOLOGY & EMPIRICAL APPROACH**

### **1) Preface**
- Reference to training-test sample split and sorting 
- Criteria: yd & OPITA

---

### **2) Requirements Set-up**
- Python environment initialization  
- Random seeds and env variables paths for reproducibility  

---

### **3) Helper Functions & General Variables**
- Custom helper function for data manipulation and plotting 
- Variables naming dictionary (from acronym to full name, and inverted) 

---

### **4) Data Retrieval & Manipulation**
- Data retrieval from local dataset (raw_data.csv) 
- Descriptive statistics for raw data
- Infinite values handling (-99.99) and replacement with NaN (numpy) 
- Data sorting based on yd and OPITA  
- Data partitioning (training and testing sample)

---

### **5) Stage 1 – Econometric Scoring Analysis (Document C, Part 1)**

#### **5.1–5.4: Data Exploration & Cleaning**
- Labeling in SAS/STATA and Python equivalent (attributes)
- Data handling and descriptive statistics:
  - Handling of missing data using NaN substitution and imputation strategies
  - Training dataset descriptive statistics and Skewness-Kurtosis diagnosis of normality
  - Explanatory variables distribution plotting with respect to normal PDF
  - Extreme observations analysis (highly affected firms)
  - Outliers handling (adjusted data plotting to potential outliers)
- Data distribution and plotting:
  - In-sample differential in distributions per firms cluster (FD & NFD firms)
  - Between sub-groups descriptive statistics comparison
  - Global Box-plot (sub-group discrimination) and std-adjusted box-plot
  - Altman Z-score framework for default prediction
  - Violin-plot excluding high-variability variables
- Correlation Diagnosis:
  - Scatter-plot & diagonal KDE (for target variables)
  - Bivariate Correlation Heatmap
  - Correlation Analysis and Implications (Pearson-R & t-statistic for testing significance)
  - p-value and t-stat asymmetries 
- Normality test:
  - Skewness-Kurtosis similarity 
  - Jarque-Bera test of normality (Aggregate data, NFD firms, FD firms)
  - Kolomogorv-Smirnov test of distributional equivalence with the Normal PDF
- Equality of variance: 
  - Levene test of equality of variance
- Distributional Equivalence 
  - Kolomogorv-Smirnov test of distributional equivalence 
- t-stat equivalence for binary y:
  - Linear correlation test (Pearson r test)
  - Simple difference of means test (Independent 2 Sample t-test)
  - One-way ANOVA for binary dependent as regressor (ANOVA-derived t-stat)
  - Linear Probability Model (LPM-derived t-stat)

#### **5.5–5.9: Correlation & Multicollinearity**
- Computation and ranking of explanatory variables by t-statistics and correlation coefficients 
- Top correlated predictors with yd and bivariate correlation
- Multicollinearity and overfitting issues 

#### **5.10–5.16: Regression Modeling and Diagnostic Tests**
- Regression-oriented data handling:
  - Data Plotting (Scatter-plot & diagonal KDE) for highly correlated variables per subgroup
  - Datasets partitioning (dependent y & independent variables X) for regressions
- Regression models implementation:
  - Estimation of Linear Probability Model (LPM), Logit, and Probit models 
  - Comparison of coefficients, t-stats, and goodness-of-fit measures  
  - Stargazer HTML summary table plotting
- Model performance assessment:
  - ROC curves and AUC values for model validation and predictive accuracy  
  - Analysis of standardized Pearson residuals and identification of outliers  
  - Computation of concordant/discordant pairs 
- Model prediction and in-sample testing:
  - In-sample data prediction
  - Plot of probability of financial distress with varying Income/Assets with model curves
  - In-sample model performance comparison
  - Preferred variable selection based on bivariate correlation and explanatory power
  - Variables combinations optimization given k number of regressors per specification (AUC maximization)
- Model prediction and in-sample testing:
  - Out-of-sample testing with pre-trained coefficients
  - Continuous and deafult-threshold-derived binary output (0.5 threshold)
  - Out-of-sample model performance comparison
  - AUC and ROC curves plotting for testing sample
- Stardardized Pearson residuals diagnosis: 
  - Stardardized Pearson Residuals computation per model (training sample)
  - Distribution of standardized Pearson residuals by firm cluster (NFD & FD) for each model
  - Stardized Pearson residuals outlier and optimal threshold identification


#### **5.17–5.20: Model Evaluation & Conceptual Extensions**
- Evaluation of Type I and Type II error trade-offs and loss functions
- Sensitivity and Specificity with respect to Probability Cutoff per model
- Threshold optimization for classification decisions based on ROC analysis
- Empirical apllication:
  - Model preferences simulation (ROC curve): private banker profile  
  - Interpreting credit decisions using model scores
  - Estimation of financial metrics weights in predicting financial default 
- Dummy trap diagnosis:
  - Theoretical framework
  - Model fit and default probability prediction for 4 specification scenarios
- Summary of adjustments to provided SAS/STATA/Python code for model equivalence

---

### **6) Stage 2 – Machine Learning Model (Document C, Part 2)**

#### **6.1–6.4: Data Preparation**
- Neural networks functional framework preface
- Literature review
- Stratified train-test splitting for balanced class representation 
- Feature scaling and preprocessing pipelines 
- Techniques for handling imbalanced data (SMOTE, class weights, or sampling) 

#### **6.5–6.7: Model Design & Training**
- Construction of baseline logistic regression for comparison 
- Design of a Keras neural network architecture (dense layers, activation functions, dropout) 
- Implementation of callbacks: early stopping, learning rate reduction, and model checkpointing  

#### **6.8–6.11: Evaluation & Optimization**
- Out-of-sample testing and validation set scoring 
- ROC curve analysis and threshold optimization for best classification performance 
- Confusion matrix plotting (with 0.5 threshold) 
- Hyperparameter tuning and calibration of probabilities
- Final threshold selection using validation performance metrics  

#### **6.12: Model Explainability**
- SHAP (Shapley) value analysis to interpret neural network predictions.  
- Visualization of variable importance and sensitivity of predictions to input ratios  
- Comparison of explainability between econometric and neural approaches  

---

### **7) Bibliography**
