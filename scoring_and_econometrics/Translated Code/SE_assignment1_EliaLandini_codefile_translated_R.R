# Requirements.txt file installation
# (Skipped pip install - not needed in R)

# ---- New Cell ----

# Variables dictionary (from acronyms to full names)
variables <- {"yd": "Financial Distress", 
             "tdta":"Debt/Assets", 
             "reta":"Retained Earnings",
             "opita":"Income/Assets", 
             "ebita":"Pre-Tax Earnings/Assets", 
             "lsls":"Log Sales",
             "lta":"Log Assets" , 
             "gempl":"Employment Growth", 
             "invsls":"Inventory/Sales",
             "nwcta":"Net Working Capital/Assets", 
             "cacl":"Current Assets/Liabilities", 
             "qacl":"Quick Assets/Liabilities", 
             "fata":"Fixed Assets/Total Assets", 
             "ltdta":"Long-Term Debt/Total Assets", 
             "mveltd":"Market Value Equity/Long-Term Debt"}

# ---- New Cell ----

# Inverted Variables dictionary (from full names to acronyms)
inverted_variables <- {v: k for k, v in variables.items()}

# ---- New Cell ----

# Statistical Significance labelling 

# Function significance_stars <- function(p) {
    if p < 0.001:
        # return "***"  
    elif p < 0.01:
        # return "**"    
    elif p < 0.05:
        # return "*"   
    else:
        # return ""

# ---- New Cell ----

# We supress potential warnings with this command
warnings.filterwarnings("ignore")

# ---- New Cell ----

# Data Retrieval (original course dataset: defaut2000.csv)
raw_data <- read.csv("raw_data.csv", sep <- ";")

# Variable renaming (variables dictionary)
raw_data.rename(columns <- variables, inplace <- True)

# Convert objects (string) to numeric (float/int), as the dataset presents figures by adopting the European notation (comma as decimal separator)
for col in raw_data.columns:
    if raw_data[col].dtype <- = "object":
        raw_data[col] = pd.to_numeric(raw_data[col].str.replace(",", "."), errors <- "coerce")

data.frame(raw_data)

# ---- New Cell ----

# Raw dataset descriptive statistics 
data.frame(raw_data).describe()

# ---- New Cell ----

# Replace infinite values (-99.99) with NaN (missing values, ".")
raw_data.replace(-99.990000, np.nan, inplace <- True)
raw_data.isna().sum()
# We observe a total of 3 NaN observations (2 for Fixed Assets/Total Assets, 1 for Long-Term Debt/Total Assets)

# ---- New Cell ----

# Sorting by "Financial Distress" & "Income/Assets"
# Sorting first by "Financial Distress" identifies 2 groups "Default (1)" and "non-Default (1)", as the dependent variable is binary. Then, within each group a new sorting is carried on in ascending order by "Income/Assets" ratio.
# Since a lower income to total assets ratio is assumed by hypothesis to increase the probability of default, it is logic to order values in ascending order (greater to smaller)
# !!!!!!!!! (Jesse's code WRONG here, as it only sorts by target x) !!!!!!!!!! 

# Training Sample (OPITA, even rows)
# Since we have only one column for y, iloc operates only on one variable, hence, no need to specify the range of columns. Different case for the matrix X of explanatory variables, where instead, iloc must apply the filtering on each variable column (.iloc[::2, :]). As the df is still merged, we keep the most general assumption, i.e., iloc filtering of X.
df_train <- raw_data.sort_values(by <- ["Financial Distress", "Income/Assets"], ascending <- True).iloc[::2, :]

# Testing Sample (OPITA, odd rows)
# To get odd rows, .iloc must be shifted of one unit (filtering starting from line 1, instead of 0) 
df_test <- raw_data.sort_values(by <- ["Financial Distress", "Income/Assets"], ascending <- True).iloc[1::2, :]

# ---- New Cell ----

# Dataframe structure control for Training Sample (OPITA)
data.frame(df_train).head(20)

# ---- New Cell ----

# Dataframe structure control for Testing Sample (OPITA)
data.frame(df_test).head(20)

# ---- New Cell ----

# Datasets partitioning (dependent y & independent variables X)
y_train <- df_train["Financial Distress"].copy()
y_test <- df_test["Financial Distress"].copy()

X_train <- df_train.drop(columns <- ["Financial Distress"]).copy()
X_test <- df_test.drop(columns <- ["Financial Distress"]).copy()

# Matrix shape test
cat(f"Training sample of X: {X_train.shape},Testing sample of X: {X_test.shape}, Training sample of y: {y_train.shape}, Testing sample of y: {y_test.shape}", '
')

# ---- New Cell ----

# General outlook on descriptive statistic of X within the training sample
# Count, mean, std, min, max, intra-quartiles (25th, 50th, 75th) + Skewness, Kurtosis
# We also traspose the original dataset to highlight comparability of same-class statistics among variables
X_train_desc <- summary(X_train).T
X_train_desc["skewness"] = X_train.skew()
X_train_desc["kurtosis"] = X_train.kurtosis()

X_train_desc

# ---- New Cell ----

# Data Plotting (variable distribution with respect to the theoretical normal)
# General Layout (column and rows enumeration, figure's size, sub_plot)
num_vars <- len(X_train.columns)
cols <- 4
rows <- (num_vars + cols - 1) // cols
fig, sub_plot <- plt.subplots(rows, cols, figsize <- (5 * cols, 4 * rows))
sub_plot <- sub_plot.flatten()

# Iteration per each variable in X_train (var_i <- location of the variable based on index, col_name <- variable name)
for var_i, col_name in enumerate(X_train.columns):
# Kernel density distribution of i
# We discard the NaN observations we mentioned earlier
    data <- X_train[col_name].dropna()
# sub_plot specs: kde curve, stat for Y sub_plot, color and number of bins (& title)
    sns.histplot(data, kde <- True, ax <- sub_plot[var_i], stat <- "density", color <- "blue", bins <- 30)
    sub_plot[var_i].set_title(f"Distribution of {col_name}")
# Normal distribution curve for comparison
    mu, std <- data.mean(), data.std()
    xmin, xmax <- sub_plot[var_i].get_xlim()
    x <- np.linspace(xmin, xmax, 100)
    p <- norm.pdf(x, mu, std)
    sub_plot[var_i].plot(x, p, "r--", label <- "Normal PDF")
# Maual labelling of KDE curve 
    lines <- sub_plot[var_i].get_lines()
    if len(lines) > 0:
        lines[0].set_label("KDE Curve")
    sub_plot[var_i].legend()
# Deletion of unused subplots (we have less variables than available slots for subplots on the page)
for j in range(var_i + 1, len(sub_plot)):
    fig.delaxes(sub_plot[j])

plt.suptitle("Figure 1", fontsize <- 20)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Extreme observations analysis: highly affected firms
# 90th percentiles mask for each variable 
# The mask is a boolean that turns True when the value falls in the top 90% tier of observations for at least 5 variable
q90 <- X_train.quantile(0.90)
mask <- (X_train >= q90)
extreme_count <- mask.sum(axis <- 1)
X_train_extreme <- X_train[extreme_count >= 5]
X_train_extreme["Number of Critical Variables"] = extreme_count
X_train_extreme <- X_train_extreme[["Number of Critical Variables"] + [col for col in X_train_extreme.columns if col != "Number of Critical Variables"]]
X_train_extreme

# ---- New Cell ----

# Extreme observations analysis: non-highly affected firms descriptive statistics
# below 90th percentiles mask for each variable 
# Here we observe how decriptive statistics and distributions plotting tend to the Normal PDF by removing potential outliers and/or exceptional values derived form highly-affected firms
X_train_cleaned_extreme <- X_train[extreme_count < 5]
X_train_cleaned_extreme_desc <- summary(X_train_cleaned_extreme).T
X_train_cleaned_extreme_desc["skewness"] = X_train_cleaned_extreme.skew()
X_train_cleaned_extreme_desc["kurtosis"] = X_train_cleaned_extreme.kurtosis()

X_train_cleaned_extreme_desc

# ---- New Cell ----

X_average_stats_improvement <- data.frame()
X_average_stats_improvement["Train Sample Abs Skewness Differential"] = (X_train.skew() - 0).abs()
X_average_stats_improvement["Cleaned Train Sample Abs Skewness Differential"]= (X_train_cleaned_extreme.skew() - 0).abs()
X_average_stats_improvement["Train Sample Abs Kurtosis Differential"] = (X_train.kurtosis() - 3).abs()
X_average_stats_improvement["Cleaned Train Sample Abs Kurtosis Differential"] = (X_train_cleaned_extreme.kurtosis() - 3).abs()

X_average_stats_improvement

# ---- New Cell ----

cat(f"Average Train Sample Abs Skewness Differential: {X_average_stats_improvement["Train Sample Abs Skewness Differential"].mean(, '
')}, Average Cleaned Train Sample Abs Skewness Differential: {X_average_stats_improvement["Cleaned Train Sample Abs Skewness Differential"].mean()}\nAverage Train Sample Abs Kurtosis Differential: {X_average_stats_improvement["Train Sample Abs Kurtosis Differential"].mean()}, Average Cleaned Train Sample Abs Kurtosis Differential: {X_average_stats_improvement["Cleaned Train Sample Abs Kurtosis Differential"].mean()}\nAverage Skewness Change (%): {(X_average_stats_improvement["Train Sample Abs Skewness Differential"].mean() - X_average_stats_improvement["Cleaned Train Sample Abs Skewness Differential"].mean()) / X_average_stats_improvement["Train Sample Abs Skewness Differential"].mean() * 100}\nAverage Kurtosis Change (%): {(X_average_stats_improvement["Train Sample Abs Kurtosis Differential"].mean() - X_average_stats_improvement["Cleaned Train Sample Abs Kurtosis Differential"].mean()) / X_average_stats_improvement["Train Sample Abs Kurtosis Differential"].mean() * 100}")

# ---- New Cell ----

# Adjusted Data Plotting to potential outliers (variable distribution cleaned of 10th and 90th exceding percentile observations, outliers cleaning) 
# Cleaned dataset (-outliers outside 10th and 90th percentile)
adj_X_train <- X_train.copy()
for var in X_train.columns:
    lower <- X_train[var].quantile(0.10)
    upper <- X_train[var].quantile(0.90)
    adj_X_train[var] = np.where(
        (adj_X_train[var] < lower) | (adj_X_train[var] > upper),
        np.nan,
        adj_X_train[var]
    )

# General Layout (column and rows enumeration, figure's size, sub_plot)
num_vars <- len(X_train.columns)
cols <- 4
rows <- (num_vars + cols - 1) // cols
fig, sub_plot <- plt.subplots(rows, cols, figsize <- (5 * cols, 4 * rows))
sub_plot <- sub_plot.flatten()

# Iteration per each variable in X_train (var_i <- location of the variable based on index, col_name <- variable name)
for var_i, col_name in enumerate(X_train.columns):
# Kernel density distribution of i
# We discard the NaN observations we mentioned earlier
    data <- adj_X_train[col_name].dropna()
# sub_plot specs: kde curve, stat for Y sub_plot, color and number of bins (& title)
    sns.kdeplot(x <- data, ax <- sub_plot[var_i], fill <- True, alpha <- 0.7, color <- "blue", label <- "Adjusted Train Data")
    sub_plot[var_i].set_title(f"Distribution of Adjusted {col_name}")
# Normal distribution curve for comparison
    mu, std <- data.mean(), data.std()
    xmin, xmax <- sub_plot[var_i].get_xlim()
    x <- np.linspace(xmin, xmax, 100)
    p <- norm.pdf(x, mu, std)
    sub_plot[var_i].plot(x, p, "r--", label <- "Normal PDF")
    sub_plot[var_i].legend()
# Deletion of unused subplots (we have less variables than available slots for subplots on the page)
for j in range(var_i + 1, len(sub_plot)):
    fig.delaxes(sub_plot[j])

plt.suptitle("Figure 2", fontsize <- 20)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Data Plotting (variable distribution with respect to the theoretical normal) comparing firms in financial distress (yd <- 1) with firms out of default risk (yd <- 0)
# We are back at using the full train dataset, but divided in sub-groups based on financial distress performance 
df_train_distress <- df_train[df_train["Financial Distress"] == 1]
df_train_nondistress <- df_train[df_train["Financial Distress"] == 0]

# General Layout (column and rows enumeration, figure's size, sub_plot)
num_vars <- len(df_train.columns)
cols <- 4
rows <- (num_vars + cols - 1) // cols
fig, sub_plot <- plt.subplots(rows, cols, figsize <- (5 * cols, 4 * rows))
sub_plot <- sub_plot.flatten()

# Iteration per each variable in X_train (var_i <- location of the variable based on index, col_name <- variable name)
for var_i, col_name in enumerate(X_train.columns):
    data_distress <- df_train_distress[col_name].dropna()
    data_nondistress <- df_train_nondistress[col_name].dropna()
# KDE for financial distress
    sns.kdeplot(data_distress, ax <- sub_plot[var_i], fill <- True, alpha <- 0.4, color <- "red", label <- "Distress (yd <- 1)")
# KDE for non-distress
    sns.kdeplot(data_nondistress, ax <- sub_plot[var_i], fill <- True, alpha <- 0.4, color <- "green", label <- "No Distress (yd <- 0)")

# Normal distribution curve for comparison
    data <- X_train[col_name].dropna()
    mu, std <- data.mean(), data.std()
    xmin, xmax <- sub_plot[var_i].get_xlim()
    x <- np.linspace(xmin, xmax, 100)
    p <- norm.pdf(x, mu, std)
    sub_plot[var_i].plot(x, p, "b--", label <- "Normal PDF")
    sub_plot[var_i].set_title(f"Distribution of {col_name}")
    sub_plot[var_i].legend()

# Deletion of unused subplots (we have less variables than available slots for subplots on the page)
for j in range(var_i + 1, len(sub_plot)):
    fig.delaxes(sub_plot[j])

plt.suptitle("Figure 3", fontsize <- 20)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Descriptive Statistics for Financial Distress Firms 
summary(df_train_nondistress)

# ---- New Cell ----

# Descriptive Statistics for Financial Distress Firms  
summary(df_train_distress)

# ---- New Cell ----

# Data Plotting (box-plot)

# General Layout (column and rows enumeration, figure's size, sub_plot)
fig, axes <- plt.subplots(nrows <- 2, ncols <- 1, figsize <- (15, 10))

# Sorting variables by std (so that logs variable move to the right-hand side, for better readibility)
std_values <- df_train.std()
sorted_X_var <- list(std_values.sort_values(ascending <- True).index)

# List of explanatory variables to plot from the general train dataset df_train
# We include all independent variables, but we need to rule out yd first
X <- [col for col in sorted_X_var if col != "Financial Distress"]

# Boxplot for non-Financial Distress firms
sns.boxplot(data <- df_train_nondistress[X], ax <- axes[0], palette <- "cool")
axes[0].set_title("Box Plot for Explanatory Variables (X), No Financial Distress Firms", fontsize <- 15)
axes[0].set_xticklabels(X, rotation <- 90, ha <- "right")

# Deactivate the visibility of ticks in the upper sub-plot, so that we can gain more space for the graph 
labels <- axes[0].set_xticklabels(X, rotation <- 90, ha <- "right")
for label in labels:
    label.set_visible(False)

# Boxplot for Financial Distress firms
sns.boxplot(data <- df_train_distress[X], ax <- axes[1], palette <- "coolwarm")
axes[1].set_title("Box Plot for Explanatory Variables (X), Financial Distress Firms", fontsize <- 15)
axes[1].set_xticklabels(X, rotation <- 90, ha <- "right", )

# Add grid and remove the frame (spines) for each plot
for ax in axes:
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.grid(True, linestyle <- "--", linewidth <- 0.7, alpha <- 0.7)

plt.suptitle("Figure 4", fontsize <- 20)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Data Plotting (box-plot) exluding high-range variables (Log Sales, Log Assets, Long-Term Debt/Total Assets)
# General Layout (column and rows enumeration, figure's size, sub_plot)
fig, axes <- plt.subplots(nrows <- 2, ncols <- 1, figsize <- (15, 10))

# Sorting variables by std (so that logs variable move to the right-hand side, for better readibility)
std_values <- df_train.std()
sorted_X_var <- list(std_values.sort_values(ascending <- True).index)

# List of explanatory variables to plot from the general train dataset df_train
# We include all independent variables, but we need to rule out yd first
X <- [col for col in sorted_X_var if col not in ["Financial Distress", "Log Sales", "Log Assets", "Long-Term Debt/Total Assets", "Current Assets/Liabilities", "Quick Assets/Liabilities"]]

# Boxplot for  non-Financial Distress firms
sns.boxplot(data <- df_train_nondistress[X], ax <- axes[0], palette <- "cool")
axes[0].set_title("Box Plot for Selected Explanatory Variables (X), No Financial Distress Firms", fontsize <- 15)
axes[0].set_xticklabels(X, rotation <- 90, ha <- "right")
# Deactivate the visibility of ticks in the upper sub-plot, so that we can gain more space for the graph 
labels <- axes[0].set_xticklabels(X, rotation <- 90, ha <- "right")
for label in labels:
    label.set_visible(False)

# Boxplot for Financial Distress firms
sns.boxplot(data <- df_train_distress[X], ax <- axes[1], palette <- "coolwarm")
axes[1].set_title("Box Plot for Selected Explanatory Variables (X), Financial Distress Firms", fontsize <- 15)
axes[1].set_xticklabels(X, rotation <- 90, ha <- "right", )

# Add grid and remove the frame (spines) for each plot
for ax in axes:
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.grid(True, linestyle <- "--", linewidth <- 0.7, alpha <- 0.7)

plt.suptitle("Figure 5", fontsize <- 20)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Data Plotting (Violin-plot) exluding high-range variables (Log Sales, Log Assets, Long-Term Debt/Total Assets)
# General Layout (column and rows enumeration, figure's size, sub_plot)
fig, axes <- plt.subplots(nrows <- 2, ncols <- 1, figsize <- (15, 10))

# Sorting variables by std (so that logs variable move to the right-hand side, for better readibility)
std_values <- df_train.std()
sorted_X_var <- list(std_values.sort_values(ascending <- True).index)

# List of explanatory variables to plot from the general train dataset df_train
# We include all independent variables, but we need to rule out yd first
X <- [col for col in sorted_X_var if col not in ["Financial Distress", "Log Sales", "Log Assets", "Long-Term Debt/Total Assets", "Current Assets/Liabilities", "Quick Assets/Liabilities"]]

# Violin-plot for No Financial Distress firms
sns.violinplot(data <- df_train_nondistress[X], ax <- axes[0], palette <- "cool")
axes[0].set_title("Violin Plot for Selected Explanatory Variables (X), No Financial Distress Firms", fontsize <- 15)
axes[0].set_xticklabels(X, rotation <- 90, ha <- "right")
# Deactivate the visibility of ticks in the upper sub-plot, so that we can gain more space for the graph 
labels <- axes[0].set_xticklabels(X, rotation <- 90, ha <- "right")
for label in labels:
    label.set_visible(False)

# Violin-plot for Financial Distress firms
sns.violinplot(data <- df_train_distress[X], ax <- axes[1], palette <- "coolwarm")
axes[1].set_title("Violin Plot for Selected Explanatory Variables (X), Financial Distress Firms", fontsize <- 15)
axes[1].set_xticklabels(X, rotation <- 90, ha <- "right", )

# Background grid and frame (spines) removal for each plot
for ax in axes:
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.grid(True, linestyle <- "--", linewidth <- 0.7, alpha <- 0.7)

plt.suptitle("Figure 6", fontsize <- 20)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Data Plotting (Scatter-plot & diagonal KDE), selected variables relative distribution per subgroup (No Financial Distress & Financial Distress firms)
# Filtering of target variables (explanatory + dependent)
Xy <- [col for col in df_train.columns if col not in 
        ["Inventory/Sales", 
         "Net Working Capital/Assets", 
         "Long-Term Debt/Total Assets", 
         "Log Sales", 
         "Log Assets", 
         "Fixed Assets/Total Assets", 
         "Quick Assets/Liabilities", 
         "Employment Growth"]]

# Scatter-plot + Diagonal KDE (g)
# No need to deploy separate datasets for the 2 sub-groups of firms, as sns.pairplot has already an integrated function (hue) to split the sample
# "reg" in kind offers much more insights than only "scatter", by adding the respective trend curves and std range
g <- sns.pairplot(df_train, 
                 hue <- "Financial Distress", 
                 hue_order <- [0, 1], 
                 vars <- Xy, 
                 kind <- "reg", 
                 diag_kind <- "kde", 
                 palette <- "rocket", 
                 corner <- True)

# Deletion of unused subplots (we have less variables than available slots for subplots on the page)
g.fig.axes[0].set_visible(False) 

# Figure elements positioning adjustments
g._legend.set(bbox_to_anchor <- (0.5, 0.8), transform <- g.fig.transFigure)
g._legend._ncol <- 2
g.fig.subplots_adjust(top <- 0.99)

g.fig.suptitle("Figure 7 Scatter Plot for Selected Variables, with diagonal KDE", 
               fontsize <- 20, y <- 0.97, ha <- "center", linespacing <- 1.5)
# plots are shown automatically in R

# ---- New Cell ----

# Data Plotting (Correlation Heatmap)
# Variable renaming (inverted variables dictionary from full names to acronyms)
df_train_short <- df_train.copy()
df_train_short.rename(columns <- inverted_variables, inplace <- True)

# Correlation matrix
corr_matrix <- df_train_short.corr()
# Sample size
n <- df_train.shape[0]

# t-statistics derived from correlation values
with np.errstate(divide <- "ignore", invalid <- "ignore"):
    t_stat_matrix <- corr_matrix * np.sqrt((n - 2) / (1 - corr_matrix**2))
    t_stat_matrix <- t_stat_matrix.round(2)

# For each cell, we want to have both the correlation index, as well as the just computed t-statistics
annot_matrix <- corr_matrix.copy().astype(str)

for i in range(len(corr_matrix)):
    for j in range(len(corr_matrix)):
# We only want to keep the lower triangle and diagonal of the full correlation matrix
        if i >= j: 
            r <- corr_matrix.iloc[i, j]
            t <- t_stat_matrix.iloc[i, j]
            annot_matrix.iloc[i, j] = f"{r:.2f}\n({t:.2f})"
        else:
            annot_matrix.iloc[i, j] = ""

# We manually hide the upper triangle
mask <- np.triu(np.ones_like(corr_matrix, dtype <- bool))

# Heat-map plot
# General Layout (figure's size and style)
plt.figure(figsize <- (12, 10))
sns.set(style <- "white")

sns.heatmap(corr_matrix,
            mask <- mask,
            annot <- annot_matrix,
            fmt <- "",               
            cmap <- "seismic",          
            vmin <- -1, vmax <- 1,       
            square <- True,
            linewidths <- 0.5,
            cbar_kws <- {"shrink": .8})


plt.title("Figure 8  Variables Correlation Matrix - Heatmap\n(r-value with t-statistics in parentheses)", 
          fontsize <- 15)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Normality Test (Jarque Bera Test) for AGGREGATE data, NO FINANCIAL DISTRESS firms data, FINANCIAL DISTRESS firms data
# H0: Data follow a normal distribution 
# The larger the JB stat, the more the distribution deviates from the normal. The smaller the p-value the greater is the confidence of statistically significant results.
# Default empty dataset, with 3 columns per each cluster of observations
df_train_jarque_bera <- data.frame(columns <- ["AGGREGATE - Jarque Bera Stat", "AGGREGATE - p-value", "AGGREGATE - Statistical Significance",
                                             "NO DISTRESS - Jarque Bera Stat", "NO DISTRESS - p-value", "NO DISTRESS - Statistical Significance",
                                             "DISTRESS - Jarque Bera Stat", "DISTRESS - p-value", "DISTRESS - Statistical Significance" ])

# As binary, we exclude the dependent variable from the analysis
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 

# We loop over each variable, for each sub-cluster, to extract its respective JB stat and p-value, to then concatenate each single test results set in an aggregate dataset 
for i in target_variables:

# Aggregate
    jb_stat <- stats.jarque_bera(df_train[i])[0]
    jb_pvalue <- stats.jarque_bera(df_train[i])[1]
# NO Financial Distress
    nondistress_jb_stat <- stats.jarque_bera(df_train_nondistress[i])[0]
    nondistress_jb_pvalue <- stats.jarque_bera(df_train_nondistress[i])[1]
# Financial Distress
    distress_jb_stat <- stats.jarque_bera(df_train_distress[i])[0]
    distress_jb_pvalue <- stats.jarque_bera(df_train_distress[i])[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's JB-stat
    jb_significance <- significance_stars(jb_pvalue)
    nondistress_jb_significance <- significance_stars(nondistress_jb_pvalue)
    distress_jb_significance <- significance_stars(distress_jb_pvalue)

    df_train_jarque_bera <- pd.concat(
        [df_train_jarque_bera, data.frame({"AGGREGATE - Jarque Bera Stat": [jb_stat], "AGGREGATE - p-value": [jb_pvalue], "AGGREGATE - Statistical Significance": [jb_significance],
                                             "NO DISTRESS - Jarque Bera Stat": [nondistress_jb_stat], "NO DISTRESS - p-value": [nondistress_jb_pvalue], "NO DISTRESS - Statistical Significance": [nondistress_jb_significance],
                                             "DISTRESS - Jarque Bera Stat": [distress_jb_stat], "DISTRESS - p-value": [distress_jb_pvalue], "DISTRESS - Statistical Significance": [distress_jb_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_jarque_bera.index <- target_variables

cat("Train Dataset - Jarque Bera Test of Normality for Aggregate and Sub-Cluster Data", '
')
df_train_jarque_bera

# ---- New Cell ----

# Equality of Variance Test (Levene Test) applied on 3 clusters: AGGREGATE data, NO FINANCIAL DISTRESS firms data, FINANCIAL DISTRESS firms data
# H0: All groups have equal variances
# The Levene measures the differences in variance (spread) between groups (the closer to 0 the better, meaning that each group's deviation from the median (center) does not differ a lot from the others. They have more or less the same shift from the center. The bigger the more likely is the rejection of H0, hence the variances are not equal.
# We center the test on the median of aggregate data, in order to be more robust against the outliers we observed earlier for some variables
# Default empty dataset
df_train_levene <- data.frame(columns <- ["ALL Levene Stat (groups <- Aggregate, NO Financial Distress, Financial Distress)", "ALL p-value", "ALL Statistical Significance", 
                                        "NFD-FD Levene Stat (groups <- NO Financial Distress, Financial Distress)", "NFD-FD p-value", "NFD-FD Statistical Significance"])

# As binary, we exclude the dependent variable from the analysis
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 

# We loop over each variable, for each sub-cluster, to extract its respective Levene stat and p-value, to then concatenate each single test results set in an aggregate dataset 
for i in target_variables:

# ALL (groups <- Aggregate, NO Financial Distress, Financial Distress)
    all_levene_stat <- levene(df_train[i], df_train_nondistress[i], df_train_distress[i], center <- "median")[0]
    all_levene_pvalue <- levene(df_train[i], df_train_nondistress[i], df_train_distress[i], center <- "median")[1]

# NFD-FD (groups <- NO Financial Distress, Financial Distress)
    nfdfd_levene_stat <- levene(df_train_nondistress[i], df_train_distress[i], center <- "median")[0]
    nfdfd_levene_pvalue <- levene(df_train_nondistress[i], df_train_distress[i], center <- "median")[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's Levene-stat
    all_levene_significance <- significance_stars(all_levene_pvalue)
    nfdfd_levene_significance <- significance_stars(nfdfd_levene_pvalue)
    
    df_train_levene <- pd.concat(
        [df_train_levene, data.frame({"ALL Levene Stat (groups <- Aggregate, NO Financial Distress, Financial Distress)": [all_levene_stat], "ALL p-value": [all_levene_pvalue], "ALL Statistical Significance": [all_levene_significance],
                                        "NFD-FD Levene Stat (groups <- NO Financial Distress, Financial Distress)": [nfdfd_levene_stat], "NFD-FD p-value": [nfdfd_levene_pvalue], "NFD-FD Statistical Significance": [nfdfd_levene_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_levene.index <- target_variables

cat("Train Dataset - Levene Test of Equality of Variance (Aggregate, NO Financial Distress, Financial Distress clusters, '
')")
df_train_levene

# ---- New Cell ----

# Distributional Equivalence Test (Kolomogorv-Smirnov Test) applied on two pairs: NO Financial Distress - Financial Distress and Aggregate - Normal PDF
# H0: The two samples are drawn from the same distribution
# or in case of comparison with normal PDF -> H0: Sample comes from a normal distribution
# The larger the KS stat, the stronger the evidence that the target samples do not come from the same distributions. Or alternatively, in the case of comparison with the theoretical normal, KS again measure the deviation magnitude pf the sample from the normal PDF. 
# Default empty dataset
df_train_ks <- data.frame(columns <- ["NFD-FD KS Stat (groups <- NO Financial Distress, Financial Distress)", "NFD-FD p-value", "NFD-FD Statistical Significance",
                                    "AGG-NORM KS Stat (groups <- Aggregate, Normal PDF)", "AGG-NORM p-value", "AGG-NORM Statistical Significance"])

# As binary, we exclude the dependent variable from the analysis
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 

# We loop over each variable, for each sub-cluster, to extract its respective KS stat and p-value, to then also compare the distribution with the Normal, as double-check to JB for non-normal distributions
for i in target_variables:

# NFD-FD (groups <- NO Financial Distress, Financial Distress)
    nfdfd_ks_stat <- ks_2samp(df_train_nondistress[i], df_train_distress[i])[0]
    nfdfd_ks_pvalue <- ks_2samp(df_train_nondistress[i], df_train_distress[i])[1]

# AGG-NORM (groups <- Aggregate, Normal PDF)
    aggnorm_ks_stat <- kstest(df_train[i], "norm", args <- (df_train[i].mean(), df_train[i].std()))[0]
    aggnorm_ks_pvalue <- kstest(df_train[i], "norm", args <- (df_train[i].mean(), df_train[i].std()))[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's KS-stat
    nfdfd_ks_significance <- significance_stars(nfdfd_ks_pvalue)
    aggnorm_ks_significance <- significance_stars(aggnorm_ks_pvalue)
    
    df_train_ks <- pd.concat(
        [df_train_ks, data.frame({"NFD-FD KS Stat (groups <- NO Financial Distress, Financial Distress)": [nfdfd_ks_stat], "NFD-FD p-value": [nfdfd_ks_pvalue], "NFD-FD Statistical Significance": [nfdfd_ks_significance],
                                    "AGG-NORM KS Stat (groups <- Aggregate, Normal PDF)": [aggnorm_ks_stat], "AGG-NORM p-value": [aggnorm_ks_pvalue], "AGG-NORM Statistical Significance": [aggnorm_ks_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_ks.index <- target_variables

cat("Train Dataset - Kolomogorv-Smirnov Test of Distributional Equivalence (NO Financial Distress - Financial Distress, Aggregate - Normal PDF, '
')")
df_train_ks

# ---- New Cell ----

# Linear Correlation Test (Pearson r Test) between the dependent variable y ("Financial Distress") and the matrix of explanatory variables X
# H0: no linear correlation between x and y (r <- 0)
# (-1<r<1) where r <- 1 -> perfect positive linear correlation, r <- 0 -> no linear correlation, r <- -1 -> perfect negative linear correlation
# There is no statistical interest in running the test per sub-group as there is no intra-group variability of y that can be use to explain the correlation of this latter with its explanatory variables
# Default empty dataset
# As we want to measure the correlation between the dependent variable y ("Financial Distress") and the matrix X of explanatory variables, here we keep y as well
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 
df_train_r <- data.frame(columns <- ["Pearson r coefficient", "p-value", "Statistical Significance"])

# The test requires no NaN in the dataset to run, so we delete the 3 defected rows containing missing values 
df_train_no_nan <- df_train.dropna()

# We loop over each variable to extract its respective Pearson r (to y) and p-value: 
for i in target_variables:
    pearson_r <- pearsonr(df_train_no_nan[i], df_train_no_nan["Financial Distress"])[0]
    pearson_r_pvalue <- pearsonr(df_train_no_nan[i], df_train_no_nan["Financial Distress"])[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's Pearson r coefficient
    pearson_r_significance <- significance_stars(pearson_r_pvalue)
    
    df_train_r <- pd.concat(
        [df_train_r, data.frame({"Pearson r coefficient": [pearson_r], "p-value": [pearson_r_pvalue], "Statistical Significance": [pearson_r_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_r.index <- target_variables

cat("Train Dataset - Pearson r Test of Linear Correlation (between the dependent variable y ('Financial Distress', '
') and the matrix of explanatory variables X)")
df_train_r

# ---- New Cell ----

# Simple Difference of Means Test (Independent 2 Sample t-test) applied on two pairs: NO Financial Distress - Financial Distress 
# H0: The mean of the differences between paired observations is zero.
# The underlying assumption here is that NO FD firms and FD firms are completely unrelated and independent from variations happening within the sample and from the other cluster. 
# The t-stat informs us on how many standard errors the difference in means is away from 0 between the two samples (No FD and FD firms)
# Default empty dataset
df_train_ttest <- data.frame(columns <- ["NFD-FD t-Stat (groups <- NO Financial Distress, Financial Distress)", "NFD-FD p-value", "NFD-FD Statistical Significance"])

# As binary, we exclude the dependent variable from the analysis
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 

# We loop over each variable to extract its respective  t-statistic and p-value:
for i in target_variables:

# NFD-FD (groups <- NO Financial Distress, Financial Distress)
    nfdfd_ttest_stat <- stats.ttest_ind(df_train_nondistress[i], df_train_distress[i])[0]
    nfdfd_ttest_pvalue <- stats.ttest_ind(df_train_nondistress[i], df_train_distress[i])[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's t-statistic
    nfdfd_ttest_significance <- significance_stars(nfdfd_ttest_pvalue)
    
    df_train_ttest <- pd.concat(
        [df_train_ttest, data.frame({"NFD-FD t-Stat (groups <- NO Financial Distress, Financial Distress)": [nfdfd_ttest_stat], "NFD-FD p-value": [nfdfd_ttest_pvalue], "NFD-FD Statistical Significance": [nfdfd_ttest_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_ttest.index <- target_variables

cat("Train Dataset - Independent 2 Sample t-test of Simple Difference of Means (NO Financial Distress - Financial Distress, '
')")
df_train_ttest

# ---- New Cell ----

# One-way ANOVA 
# H0: β <- 0, but since y is binary ("Financial Distress"), the null hypothesis is equivalent to testing if the means are equal, as the coefficient β is the difference in group means.
# However, to allow the ANOVA test to be equivalent to a 2-sample t-test, the regressor must be binary (not the dependent) and since we have no binary regressors X, but we do have a binary dependent, in the OLS model, we must swap the dependent (y) with the target regressor (i). 
# In conclusion, in the OLS model, we will have the binary dependent y ("Financial Distress") as regressor, while the target explanatory variable Xi as dependent variable.
# Default empty dataset
df_train_ANOVA <- data.frame(columns <- ["ANOVA-derived t-Stat", "p-value", "Statistical Significance"])

# As binary, we exclude the dependent variable from the analysis
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 

# We loop over each variable to extract its respective t-statistic and p-value derived from ANOVA:
for i in target_variables:

# OLS model (y <- target_variables, X <- "Financial Distress")
# Inverted OLS where each explanatory variable is regressed on y 
    ANOVA_model <- sm.OLS(df_train[i], sm.add_constant(df_train["Financial Distress"]), has_const <- True).fit()
    ANOVA_tstat <- ANOVA_model.tvalues[1]
    ANOVA_pvalue <- ANOVA_model.pvalues[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's ANOVA-derived t-statistic
    ANOVA_significance <- significance_stars(ANOVA_pvalue)
    
    df_train_ANOVA <- pd.concat(
        [df_train_ANOVA, data.frame({"ANOVA-derived t-Stat": [ANOVA_tstat], "p-value": [ANOVA_pvalue], "Statistical Significance": [ANOVA_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_ANOVA.index <- target_variables

cat("Train Dataset - One-way ANOVA (ANOVA-derived t-stat, binary y, '
')")
df_train_ANOVA

# ---- New Cell ----

# Linear Probability Model
# With LPM, we apply an OLS regression to a binary dependent variable (in this case y <- "Financial Distress"), where β is equal to the change in probability associated with a one-unit change in Xi (target variables)
# H0: β <- 0, i.e., X has no effect on the probability that y <- 1

# Default empty dataset
df_train_LPM <- data.frame(columns <- ["Linear Probability Model-derived t-Stat", "p-value", "Statistical Significance"])

# OLS requires no NaN in the regressors' dataset to run, so we delete the 3 defected rows containing missing values 
df_train_no_nan <- df_train.dropna()

# As binary, we exclude the dependent variable from the analysis
target_variables <- [col for col in df_train.columns if col not in ["Financial Distress"]] 

# We loop over each variable to extract its respective t-statistic and p-value derived from the linear probability model:
for i in target_variables:

# OLS model (y <- "Financial Distress", X <- target_variables)
    LPM_model <- sm.OLS(df_train_no_nan["Financial Distress"], sm.add_constant(df_train_no_nan[i]), has_const <- True).fit()
    LPM_tstat <- LPM_model.tvalues[1]
    LPM_pvalue <- LPM_model.pvalues[1]

# We add a column ("Statistical Significance") to better visualize the statistical significance confidence thresholds for each variable's linear probability model-derived t-statistic
    LPM_significance <- significance_stars(LPM_pvalue)
    
    df_train_LPM <- pd.concat(
        [df_train_LPM, data.frame({"Linear Probability Model-derived t-Stat": [LPM_tstat], "p-value": [LPM_pvalue], "Statistical Significance": [LPM_significance]})],
        ignore_index <- True
    )

# Index renaiming with variables full name
df_train_LPM.index <- target_variables

cat("Train Dataset - Linear Probability Model-derived t-Stat", '
')
df_train_LPM

# ---- New Cell ----

# Data Plotting (Scatter-plot & diagonal KDE), highly correlated variables relative distribution per subgroup (No Financial Distress & Financial Distress firms)
# Filtering of target variables (explanatory + dependent): Financial Distress, Debt/Assets, Retained Earnings, Income/Assets, Pre-Tax Earnings/Assets, Employment Growth.
Xy <- [col for col in df_train.columns if col in 
        ["Financial Distress", 
         "Debt/Assets", 
         "Retained Earnings",
         "Income/Assets", 
         "Pre-Tax Earnings/Assets",
         "Employment Growth"]]

# Scatter-plot + Diagonal KDE (g)
# "reg" in kind offers much more insights than only "scatter", by adding the respective trend curves and std range
# bivariate clouds of points
g <- sns.pairplot(df_train,  
                 vars <- Xy, 
                 kind <- "reg", 
                 diag_kind <- "kde",
                 plot_kws <- {"line_kws": {"color": "red"}},
                 corner <- True)

# Deletion of unused subplots (we have less variables than available slots for subplots on the page)
g.fig.axes[0].set_visible(False) 

# Figure elements positioning adjustments
g.fig.subplots_adjust(top <- 0.99)
g.fig.suptitle("Figure 9\nScatter Plot for Target Highly-Correlated Variables, with diagonal KDE", 
               fontsize <- 20, y <- 0.97, ha <- "center", linespacing <- 1.5)
# plots are shown automatically in R

# ---- New Cell ----

# Datasets partitioning (dependent y & independent variables X) for regressions
# Linear regressive models accept no NaN values to run, which collides with our raw training sample due to negative infinite values translated into NaN (-99.99)
# Hence, we create a new split without NaN
df_train_reg1 <- df_train.copy().dropna()
y_train_reg1 <- df_train_reg1["Financial Distress"].copy()
X_train_reg1 <- df_train_reg1.drop(columns <- ["Financial Distress"]).copy()

# Set intercept (x1)
X1 <- X_train_reg1["Debt/Assets"] 
X1 <- sm.add_constant(X1)

# ---- New Cell ----

# Linear Probability Model (LPM) 
lpm_model1 <- sm.OLS(y_train_reg1, X1).fit()

# Logit Model 
logit_model1 <- sm.Logit(y_train_reg1, X1).fit()

# Probit Model 
probit_model1 <- sm.Probit(y_train_reg1, X1).fit()

# ---- New Cell ----

# We deploy stargazer and HTML libaries to display custom summary tables
stargazer_all <- Stargazer([lpm_model1, logit_model1, probit_model1])
stargazer_all.title("Financial Distress - Univariate Models Comparison (Debt/Assets)")
stargazer_all.custom_columns(["LPM", "Logit", "Probit"], [1, 1, 1])
stargazer_all.dependent_variable_name("Financial Distress")
stargazer_all.add_line("Model Type", ["OLS", "Logit", "Probit"])
stargazer_all.significance_levels([0.001, 0.01, 0.05])
stargazer_all.add_custom_notes([
    "Standard errors in parentheses."
])
stargazer_all.show_degrees_of_freedom(False)

HTML(stargazer_all.render_html())

# ---- New Cell ----

# Alternative Single Comparison Table
# We plot one column per each model displaying Coefficient beta for Debt/Assets, std.error and p-value
# We also avoid to display the index (drop <- True), which gets automatically assigned to the models when building the table
summary_table1 <- data.frame({
    "Model": ["Linear Probability (LPM)", "Logit", "Probit"],
    "Intercept": [
        lpm_model1.params["const"],
        logit_model1.params["const"],
        probit_model1.params["const"] 
    ],
    "Coefficient (Debt/Assets)": [
        lpm_model1.params["Debt/Assets"],
        logit_model1.params["Debt/Assets"],
        probit_model1.params["Debt/Assets"]
    ],
    "Std. Error": [
        lpm_model1.bse["Debt/Assets"],
        logit_model1.bse["Debt/Assets"],
        probit_model1.bse["Debt/Assets"]
    ],
    "p-value": [
        lpm_model1.pvalues["Debt/Assets"],
        logit_model1.pvalues["Debt/Assets"],
        probit_model1.pvalues["Debt/Assets"]
    ],
    "R-squared / Pseudo R²": [
        lpm_model1.rsquared,              
        logit_model1.prsquared,           
        probit_model1.prsquared            
    ],
    "Number of Observations": [
        int(lpm_model1.nobs),
        int(logit_model1.nobs),
        int(probit_model1.nobs)
    ]
}).reset_index(drop <- True)

# Rounding of numeric columns at 4 decimals
numeric_cols <- ["Intercept", "Coefficient (Debt/Assets)", "Std. Error", "p-value", "R-squared / Pseudo R²"]
summary_table1[numeric_cols] = summary_table1[numeric_cols].round(4)

# We first traspose the dataset to move the models on the columns, to secondly rename the columns and set new headers
summary_table1 <- summary_table1.T
summary_table1.columns <- summary_table1.iloc[0]
summary_table1 <- summary_table1.drop(summary_table1.index[0])

summary_table1

# ---- New Cell ----

# Concordant pairs for target variable (TDTA)
# score-derived from intercept + beta of LPM for single variable TDTA just computed
df_train_concordants <- df_train.copy().dropna()
df_train_concordants["score"] = lpm_model1.params["const"] + lpm_model1.params["Debt/Assets"] * df_train_concordants["Debt/Assets"]

# Train sample split based on dummy yd
# non financially distressed (y <- 0), financially distressed (y <- 1)
df_train_concordants_nfd <- df_train_concordants[df_train_concordants["Financial Distress"] == 0]
df_train_concordants_fd <- df_train_concordants[df_train_concordants["Financial Distress"] == 1]

# Set tie condition
concordant <- discordant <- tied <- 0

# All possible pairs starting from yd <- 1
# We enumerate each case by adding one if true (concordant, discordant, tied)
for _, fd in df_train_concordants_fd.iterrows():
    for _, nfd in df_train_concordants_nfd.iterrows():
        if fd["score"] > nfd["score"]:
            concordant += 1
        elif fd["score"] < nfd["score"]:
            discordant += 1
        else:
            tied += 1

# Percentages for concordant, discordant, tied pairs
total_pairs <- concordant + discordant + tied
percentage_concordant <- concordant / total_pairs * 100
percentage_discordant <- discordant / total_pairs * 100
percentage_tied <- tied / total_pairs * 100

concordants_summary <- data.frame({
    "Type": ["Concordant", "Discordant", "Tied"], 
    "Number": [concordant, discordant, tied],
    "Percentage": [percentage_concordant, percentage_discordant, percentage_tied]
}).reset_index(drop <- True)

# Table Trasposition
concordants_summary <- concordants_summary.T
concordants_summary.columns <- concordants_summary.iloc[0]
concordants_summary <- concordants_summary.drop(concordants_summary.index[0])

concordants_summary

# ---- New Cell ----

# Datasets partitioning (dependent y & independent variables X) for regressions
# Linear regressive models accept no NaN values to run, which collides with our raw training sample due to negative infinite values translated into NaN (-99.99)
# Hence, we create a new split without NaN
df_train_reg2 <- df_train.copy().dropna()
y_train_reg2 <- df_train_reg2["Financial Distress"].copy()
X_train_reg2 <- df_train_reg2.drop(columns <- ["Financial Distress"]).copy()

# Set intercept (x2)
X2 <- X_train_reg2[["Debt/Assets", "Income/Assets", "Current Assets/Liabilities", "Market Value Equity/Long-Term Debt", "Inventory/Sales"]] 
X2 <- sm.add_constant(X2)

# Number of observations per cluster (yd <- (0,1))
num_train_nfd <- (df_train_reg2["Financial Distress"] == 0).sum()
num_train_fd <- (df_train_reg2["Financial Distress"] == 1).sum()

# ---- New Cell ----

# Linear Probability Model (LPM) (fit, predicted probabilities, AUC area)
lpm_model2 <- sm.OLS(y_train_reg2, X2).fit()
y_pred_lpm_model2 <- lpm_model2.predict(X2)
auc_lpm_model2 <- roc_auc_score(y_train_reg2, y_pred_lpm_model2)

# Logit Model (fit, predicted probabilities, AUC area)
logit_model2 <- sm.Logit(y_train_reg2, X2).fit()
y_pred_logit_model2 <- logit_model2.predict(X2)
auc_logit_model2 <- roc_auc_score(y_train_reg2, y_pred_logit_model2)

# Probit Model (fit, predicted probabilities, AUC area)
probit_model2 <- sm.Probit(y_train_reg2, X2).fit()
y_pred_probit_model2 <- probit_model2.predict(X2)
auc_probit_model2 <- roc_auc_score(y_train_reg2, y_pred_probit_model2)

# ---- New Cell ----

# We deploy stargazer and HTML libaries to display custom summary tables
stargazer_all <- Stargazer([lpm_model2, logit_model2, probit_model2])
stargazer_all.title("Financial Distress - Model Comparison with Selected Target Variables")
stargazer_all.custom_columns(["LPM", "Logit", "Probit"], [1, 1, 1])
stargazer_all.dependent_variable_name("Financial Distress")
stargazer_all.add_line("Model Type", ["OLS", "Logit", "Probit"])
stargazer_all.significance_levels([0.001, 0.01, 0.05])
stargazer_all.add_custom_notes([
    "Standard errors in parentheses."
])
stargazer_all.show_degrees_of_freedom(False)

HTML(stargazer_all.render_html())

# ---- New Cell ----

# Actual/Predicted Data Plotting for target variable (OPITA)
# Converting to np arrays
x_comp <- as.array(X2["Income/Assets"])
y_comp <- as.array(y_train_reg2)

# Models and predictions for previous run
models <- [
    ("LPM", y_pred_lpm_model2, auc_lpm_model2),
    ("Logit", y_pred_logit_model2, auc_logit_model2),
    ("Probit", y_pred_probit_model2, auc_probit_model2)
]

# Scatter plot per model
fig, axes <- plt.subplots(1, 3, figsize <- (15, 5), sharey <- True)
for ax, (model_name, predicted_y, auc) in zip(axes, models):

# Real data (training sample)
    ax.scatter(x_comp[y_comp <- = 0], y_comp[y_comp <- = 0], color <- "blue", label <- "Actual y <- 0")
    ax.scatter(x_comp[y_comp <- = 1], y_comp[y_comp <- = 1], color <- "red", label <- "Actual y <- 1")
    
# Predicted points (0.5 threshold for classifying continuous yd in FD or NFD)
    ax.scatter(x_comp[predicted_y < 0.5], predicted_y[predicted_y < 0.5], color <- "slateblue", marker <- "x", label <- "Predicted y <- 0")
    ax.scatter(x_comp[predicted_y >= 0.5], predicted_y[predicted_y >= 0.5], color <- "mediumorchid", marker <- "x", label <- "Predicted y <- 1")
    
    ax.set_title(f"{model_name}\nAUC <- {auc:.3f}")
    ax.set_xlabel("Income/Assets")
    ax.set_ylim(-0.1, 1.3)
    ax.grid(True)

# General settings and layout
axes[0].set_ylabel("y (Binary)")
axes[0].legend(loc <- "upper left")
plt.suptitle("Figure 10 - Model Predictions (training sample)", fontsize <- 15)
plt.tight_layout(rect <- [0, 0, 1, 0.95])
# plots are shown automatically in R

# ---- New Cell ----

# Plot of Probability of Financial Distress with varying Income/Assets with model curves
# Range of x values for Income/Assets
x_min <- X2["Income/Assets"].min()
x_max <- X2["Income/Assets"].max()
x_range <- np.linspace(x_min, x_max, 200)

# Prediction over the new range of x values
X_pred <- data.frame({col: np.full_like(x_range, X2[col].mean()) for col in X2.columns})
X_pred["Income/Assets"] = x_range 

# Predicted probabilities for each model
lpm_pred <- lpm_model2.predict(X_pred)
logit_pred <- logit_model2.predict(X_pred)
probit_pred <- probit_model2.predict(X_pred)

# Scatter plot and model curves
plt.figure(figsize <- (10,6))

# Real data (training sample)
plot(X2["Income/Assets"][y_train_reg2 <- =0], y_train_reg2[y_train_reg2 <- =0], color <- "blue", alpha <- 0.5, label <- "Non-Financial Distres (y <- 0)")
plot(X2["Income/Assets"][y_train_reg2 <- =1], y_train_reg2[y_train_reg2 <- =1], color <- "red", alpha <- 0.5, label <- "Financial Distress (y <- 1)")

# Regression curves for each model based on x linear range of values
plot(x_range, lpm_pred, color <- "red", label <- "LPM", linewidth <- 2, type='l')
plot(x_range, logit_pred, color <- "blue", label <- "Logit", linewidth <- 2, type='l')
plot(x_range, probit_pred, color <- "purple", label <- "Probit", linewidth <- 2, type='l')

# General settings and layout
plt.xlabel("Income/Assets")
plt.ylabel("Probability of Financial Distress (yd)")
plt.title("Figure 11 - Probability of Financial Distress with varying Income/Assets")
plt.legend()
plt.grid(True)
# plots are shown automatically in R

# ---- New Cell ----

# Summary Table
# We plot one column per each model displaying Intercept, coefficient beta for each variable, std.error in parenthesis and p-value in stars notation
# We also avoid to display the index (drop <- True), which gets automatically assigned to the models when building the table
# Unlike the univariate summary table, here we add a row for each regressor rounding at 4 decimals
summary_table2 <- data.frame({
    "Model": ["Linear Probability (LPM)", "Logit", "Probit"
    ],
    "Intercept": [
        f"{lpm_model2.params['const']:.4f}{significance_stars(lpm_model2.pvalues['const'])}({lpm_model2.bse['const']:.4f})",
        f"{logit_model2.params['const']:.4f}{significance_stars(logit_model2.pvalues['const'])}({logit_model2.bse['const']:.4f})",
        f"{probit_model2.params['const']:.4f}{significance_stars(probit_model2.pvalues['const'])}({probit_model2.bse['const']:.4f})"
    ],
    "Debt/Assets": [
        f"{lpm_model2.params['Debt/Assets']:.4f}{significance_stars(lpm_model2.pvalues['Debt/Assets'])}({lpm_model2.bse['Debt/Assets']:.4f})",
        f"{logit_model2.params['Debt/Assets']:.4f}{significance_stars(logit_model2.pvalues['Debt/Assets'])}({logit_model2.bse['Debt/Assets']:.4f})",
        f"{probit_model2.params['Debt/Assets']:.4f}{significance_stars(probit_model2.pvalues['Debt/Assets'])}({probit_model2.bse['Debt/Assets']:.4f})"
    ],
    "Income/Assets": [
        f"{lpm_model2.params['Income/Assets']:.4f}{significance_stars(lpm_model2.pvalues['Income/Assets'])}({lpm_model2.bse['Income/Assets']:.4f})",
        f"{logit_model2.params['Income/Assets']:.4f}{significance_stars(logit_model2.pvalues['Income/Assets'])}({logit_model2.bse['Income/Assets']:.4f})",
        f"{probit_model2.params['Income/Assets']:.4f}{significance_stars(probit_model2.pvalues['Income/Assets'])}({probit_model2.bse['Income/Assets']:.4f})"
    ],
    "Current Assets/Liabilities": [
        f"{lpm_model2.params['Current Assets/Liabilities']:.4f}{significance_stars(lpm_model2.pvalues['Current Assets/Liabilities'])}({lpm_model2.bse['Current Assets/Liabilities']:.4f})",
        f"{logit_model2.params['Current Assets/Liabilities']:.4f}{significance_stars(logit_model2.pvalues['Current Assets/Liabilities'])}({logit_model2.bse['Current Assets/Liabilities']:.4f})",
        f"{probit_model2.params['Current Assets/Liabilities']:.4f}{significance_stars(probit_model2.pvalues['Current Assets/Liabilities'])}({probit_model2.bse['Current Assets/Liabilities']:.4f})"
    ],
    "Market Value Equity/Long-Term Debt": [
        f"{lpm_model2.params['Market Value Equity/Long-Term Debt']:.4f}{significance_stars(lpm_model2.pvalues['Market Value Equity/Long-Term Debt'])}({lpm_model2.bse['Market Value Equity/Long-Term Debt']:.4f})",
        f"{logit_model2.params['Market Value Equity/Long-Term Debt']:.4f}{significance_stars(logit_model2.pvalues['Market Value Equity/Long-Term Debt'])}({logit_model2.bse['Market Value Equity/Long-Term Debt']:.4f})",
        f"{probit_model2.params['Market Value Equity/Long-Term Debt']:.4f}{significance_stars(probit_model2.pvalues['Market Value Equity/Long-Term Debt'])}({probit_model2.bse['Market Value Equity/Long-Term Debt']:.4f})"
    ],
    "Inventory/Sales": [
        f"{lpm_model2.params['Inventory/Sales']:.4f}{significance_stars(lpm_model2.pvalues['Inventory/Sales'])}({lpm_model2.bse['Inventory/Sales']:.4f})",
        f"{logit_model2.params['Inventory/Sales']:.4f}{significance_stars(logit_model2.pvalues['Inventory/Sales'])}({logit_model2.bse['Inventory/Sales']:.4f})",
        f"{probit_model2.params['Inventory/Sales']:.4f}{significance_stars(probit_model2.pvalues['Inventory/Sales'])}({probit_model2.bse['Inventory/Sales']:.4f})"
    ],
    "R-squared / Pseudo R²": [
        round(lpm_model2.rsquared, 4),
        round(logit_model2.prsquared, 4),
        round(probit_model2.prsquared, 4)
    ],
    "AUC (training sample)": [
        round(auc_lpm_model2, 4),
        round(auc_logit_model2, 4),
        round(auc_probit_model2, 4)
    ],
    "Number of NFD Observations": [
        num_train_nfd, num_train_nfd, num_train_nfd
    ], 
    "Number of FD Observations": [
        num_train_fd, num_train_fd, num_train_fd
    ]
}).reset_index(drop <- True)

# We first traspose the dataset to move the models on the columns, to secondly rename the columns and set new headers
summary_table2 <- summary_table2.T
summary_table2.columns <- summary_table2.iloc[0]
summary_table2 <- summary_table2.drop(summary_table2.index[0])

cat("Summary Table - Comparison of Linear Probability, probit, and Logit (in-sample; AUC area, '
')")
summary_table2

# ---- New Cell ----

# Variables combinations optimization (yd explanatory power maximization and bivariate correlation minimization) given k number of regressors in specification
# Empty dataset for results
model_comparison_results <- []

# We want to find the optimal (best fitting model) given a target number of regressors to check whether R-squared or pseusdo-R-squared increases by increasing the number of explanatory variables.
# We assume 2, 3, 4 as number of regressors in 3 different specifications (equals to k)
for k in [2, 3, 4]:
# We set the parameters for the combinations in the loop, combinations of vars for k
# vars_combo is one of the possible combination of k variables between all the possible 14 financial metrics
    for vars_combo in itertools.combinations(X_train.columns, k):
# We re-exexcute the regression for each model, using the same numpy arrays of model 2 regressions
        X <- X_train_reg2[list(vars_combo)]
        X <- sm.add_constant(X)
        model <- sm.OLS(y_train_reg2, X).fit()
# From the fitted model we save, predicted in-sample y, auc and r-squared 
        y_pred <- model.predict(X)
        auc <- roc_auc_score(y_train_reg2, y_pred)
        r2 <- model.rsquared
# Model table a line for results summary 
        model_comparison_results.append({
            "Estimator": "LPM (OLS)", 
            "variables": vars_combo,
            "R2": r2,
            "AUC": auc
        })

model_comparison_results <- data.frame(model_comparison_results)

# We construct a dataframe to display the results of the model comparison based on AUC-derived sorting for the best 5 models for each specification 
summary_results_model_comparison <- data.frame()
for k in [2, 3, 4]:
# Filtering on k
    subset <- model_comparison_results[model_comparison_results["variables"].apply(len) == k]
# Sorting by AUC (descending) and R2 (descending), pick best 5
    best <- subset.sort_values(by <- ["AUC", "R2"], ascending <- [False, False]).head(5)
    best <- best.copy()
    best["k"] = k
    summary_results_model_comparison <- pd.concat([summary_results_model_comparison, best], ignore_index <- True)

# Dataframe structure, displaying first models with a lower number of variables and then sort them by AUC for having the top performers
summary_results_model_comparison <- summary_results_model_comparison[
    ["k", "Estimator", "variables", "R2", "AUC"]
].sort_values(by <- ["k", "AUC"], ascending <- [True, False]).reset_index(drop <- True)

summary_results_model_comparison

# ---- New Cell ----

# From the training sample, we know move to out-of-sample testing
# We want to compute the AUC under the ROC curve 
df_test_reg2 <- df_test.copy().dropna()
y_test_reg2 <- df_test_reg2["Financial Distress"].copy()
X_test_reg2 <- df_test_reg2.drop(columns <- ["Financial Distress"]).copy()

# Set regressors and intercept for test (x2_text)
X2_test <- X_test_reg2[["Debt/Assets", "Income/Assets", "Current Assets/Liabilities", "Market Value Equity/Long-Term Debt", "Inventory/Sales"]] 
X2_test <- sm.add_constant(X2_test)

# Number of observations per cluster in the testing sample (yd <- (0,1))
num_test_nfd <- (df_test_reg2["Financial Distress"] == 0).sum()
num_test_fd <- (df_test_reg2["Financial Distress"] == 1).sum()

# ---- New Cell ----

# Linear Probability Model (LPM) (fit, predicted probabilities, AUC area)
# We don't change the computed model coefficients
y_pred_lpm_model2_test <- lpm_model2.predict(X2_test)
auc_lpm_model2_test_continuous <- roc_auc_score(y_test_reg2, y_pred_lpm_model2_test)
auc_lpm_model2_test_binary <- roc_auc_score(y_test_reg2, np.round(y_pred_lpm_model2_test))

# Logit Model (fit, predicted probabilities, AUC area)
y_pred_logit_model2_test <- logit_model2.predict(X2_test)
auc_logit_model2_test_continuous <- roc_auc_score(y_test_reg2, y_pred_logit_model2_test)
auc_logit_model2_test_binary <- roc_auc_score(y_test_reg2, np.round(y_pred_logit_model2_test))

# Probit Model (fit, predicted probabilities, AUC area)
y_pred_probit_model2_test <- probit_model2.predict(X2_test)
auc_probit_model2_test_continuous <- roc_auc_score(y_test_reg2, y_pred_probit_model2_test)
auc_probit_model2_test_binary <- roc_auc_score(y_test_reg2, np.round(y_pred_probit_model2_test))

# ---- New Cell ----

# Dataset of summary of predicted continuous *yd* for each model 
# The dataset is structured on 3 columns, on for each predictive model based on the estimated coefficients of the training set 
# Since yd is binary we want to round the values of predicted y to the closest value either 0 or 1, to fo so we use the 0.5 threshold to round values to the closest natural approximation

model2_summary_pred_y <- data.frame()
model2_summary_pred_y["LPM - Continuous"] = y_pred_lpm_model2_test.values
model2_summary_pred_y["LPM - Binary"] = np.round(y_pred_lpm_model2_test.values)
model2_summary_pred_y["Logit - Continuous"] = y_pred_logit_model2_test.values
model2_summary_pred_y["Logit - Binary"] = np.round(y_pred_logit_model2_test.values)
model2_summary_pred_y["Probit - Continuous"] = y_pred_probit_model2_test.values
model2_summary_pred_y["Probit - Binary"] = np.round(y_pred_probit_model2_test.values)

model2_summary_pred_y.head(15)

# ---- New Cell ----

# Summary Table AUC and other relevant statistics 
# We comapre the testing sample with the training sample for the AUC by segmentating the testing sample in prediction on yd with continuous and binary outputs
# Predicted average and actual average comparison, enriched with the count of ndf and df observations for each forecast
summary_table2_test <- data.frame({
    "Model": ["Linear Probability (LPM)", "Logit", "Probit"
    ],
    "AUC (training sample)": [
        round(auc_lpm_model2, 4),
        round(auc_logit_model2, 4),
        round(auc_probit_model2, 4)
    ],
    "AUC (testing sample, continuous)": [
        round(auc_lpm_model2_test_continuous, 4),
        round(auc_logit_model2_test_continuous, 4),
        round(auc_probit_model2_test_continuous, 4)
    ],
    "AUC (testing sample, binary)": [
        round(auc_lpm_model2_test_binary, 4),
        round(auc_logit_model2_test_binary, 4),
        round(auc_probit_model2_test_binary, 4)
    ],
    "Testing Sample Average": [
        round(y_test_reg2.mean(), 4), 
        round(y_test_reg2.mean(), 4), 
        round(y_test_reg2.mean(), 4)
    ],
    "Predicted Average (continuous)": [
        round(y_pred_lpm_model2_test.mean(), 4),
        round(y_pred_logit_model2_test.mean(), 4),
        round(y_pred_probit_model2_test.mean(), 4)
    ], 
    "Predicted Average (binary)": [
        round(np.round(y_pred_lpm_model2_test.values).mean(), 4),
        round(np.round(y_pred_logit_model2_test.values).mean(), 4),
        round(np.round(y_pred_probit_model2_test.values).mean(), 4)
    ], 
    "Number of NFD Observations": [
        num_test_nfd, num_test_nfd, num_test_nfd
    ], 
    "Number of predicted NFD Observations": [
       (model2_summary_pred_y["LPM - Binary"] == 1.0).sum(), 
       (model2_summary_pred_y["Logit - Binary"] == 1.0).sum(), 
       (model2_summary_pred_y["Probit - Binary"] == 1.0).sum()
    ],
    "Number of FD Observations": [
        num_test_fd, num_test_fd, num_test_fd
    ],
    "Number of predicted FD Observations": [
        (model2_summary_pred_y["LPM - Binary"] == 0.0).sum(), 
        (model2_summary_pred_y["Logit - Binary"] == 0.0).sum(), 
        (model2_summary_pred_y["Probit - Binary"] == 0.0).sum()
    ]
}).reset_index(drop <- True)

# We first traspose the dataset to move the models on the columns, to secondly rename the columns and set new headers
summary_table2_test <- summary_table2_test.T
summary_table2_test.columns <- summary_table2_test.iloc[0]
summary_table2_test <- summary_table2_test.drop(summary_table2_test.index[0])

cat("Summary Table - Comparison of Linear Probability, probit, and Logit (Testing Sample; AUC area, '
')")
summary_table2_test

# ---- New Cell ----

# ROC plotting for testing sample
# Linear Probability Model (LPM)
FP_lpm_model2_test_continuous, TP_lpm_model2_test_continuous, _ <- roc_curve(y_test_reg2, y_pred_lpm_model2_test)
FP_lpm_model2_test_binary, TP_lpm_model2_test_binary, _ <- roc_curve(y_test_reg2, np.round(y_pred_lpm_model2_test))

# Logit
FP_logit_model2_test_continuous, TP_logit_model2_test_continuous, _ <- roc_curve(y_test_reg2, y_pred_logit_model2_test)
FP_logit_model2_test_binary, TP_logit_model2_test_binary, _ <- roc_curve(y_test_reg2, np.round(y_pred_logit_model2_test))

# Probit
FP_probit_model2_test_continuous, TP_probit_model2_test_continuous, _ <- roc_curve(y_test_reg2, y_pred_probit_model2_test)
FP_probit_model2_test_binary, TP_probit_model2_test_binary, _ <- roc_curve(y_test_reg2, np.round(y_pred_probit_model2_test))

# ROC curves plotting
# We want to compare performances across models but alwo between continuous an binary specifications of each model
plt.figure(figsize <- (9, 7))

# Continuous ROC curves
# ROC curves for each model with staircase shape given the coninuous nature of the output
plot(FP_lpm_model2_test_continuous, TP_lpm_model2_test_continuous, color <- "red", lw <- 2,
         label <- f"LPM (AUC <- {auc_lpm_model2_test_continuous:.3f}, type='l')")
plot(FP_logit_model2_test_continuous, TP_logit_model2_test_continuous, color <- "blue", lw <- 2,
         label <- f"Logit (AUC <- {auc_logit_model2_test_continuous:.3f}, type='l')")
plot(FP_probit_model2_test_continuous, TP_probit_model2_test_continuous, color <- "purple", lw <- 2,
         label <- f"Probit (AUC <- {auc_probit_model2_test_continuous:.3f}, type='l')")

# Binary ROC curves 
# ROC curves for 0.5 threshold conversion from nfd to fd 
plot(FP_lpm_model2_test_binary, TP_lpm_model2_test_binary, "r--", lw <- 1.5,
         label <- f"LPM binary (AUC <- {auc_lpm_model2_test_binary:.3f}, type='l')")
plot(FP_logit_model2_test_binary, TP_logit_model2_test_binary, "b--", lw <- 1.5,
         label <- f"Logit binary (AUC <- {auc_logit_model2_test_binary:.3f}, type='l')")
plot(FP_probit_model2_test_binary, TP_probit_model2_test_binary, "m--", lw <- 1.5,
         label <- f"Probit binary (AUC <- {auc_probit_model2_test_binary:.3f}, type='l')")

# Random baseline
# Baseline for random guess (AUC <- 0.5)
plot([0, 1], [0, 1], color <- "gray", lw <- 1, linestyle <- "--", type='l')

# General setting and graph layout
plt.title("Figure 12 - ROC Curves for LPM, Logit, and Probit Models (out-of-sample)", fontsize <- 15)
plt.xlabel("False Positive Rate")
plt.ylabel("True Positive Rate")
plt.legend(loc <- "lower right", fontsize <- 9)
plt.grid(alpha <- 0.3)
plt.tight_layout()
# plots are shown automatically in R

# ---- New Cell ----

# Stardardized Pearson Residuals computation per model (training sample)
# Linear Probability Model (LPM)
# Predicted y
y_pred_lpm_model2 <- lpm_model2.predict(X2)
# Residuals between actual y and predicted y 
resid_lpm_model2 <- (y_train_reg2 - y_pred_lpm_model2) / np.sqrt(y_pred_lpm_model2 * (1 - y_pred_lpm_model2))
# H matrix
X2_np <- X2.values
h_lpm_model2 <- np.diag(X2_np @ np.linalg.inv(X2_np.T @ X2_np) @ X2_np.T)
# Standardized residuals
std_resid_lpm_model2 <- resid_lpm_model2 / np.sqrt(1 - h_lpm_model2)

# Logit
y_pred_logit_model2 <- logit_model2.predict(X2)
resid_logit_model2 <- (y_train_reg2 - y_pred_logit_model2) / np.sqrt(y_pred_logit_model2 * (1 - y_pred_logit_model2))
# Logit have built in features to fetch hat diagonals and compute standardized residuals
influence_logit_model2 <- logit_model2.get_influence()
h_logit_model2 <- influence_logit_model2.hat_matrix_diag
std_resid_logit_model2 <- resid_logit_model2 / np.sqrt(1 - h_logit_model2)

# Probit
y_pred_probit_model2 <- probit_model2.predict(X2)
resid_probit_model2 <- (y_train_reg2 - y_pred_probit_model2) / np.sqrt(y_pred_probit_model2 * (1 - y_pred_probit_model2))
# Probit have built in features to fetch hat diagonals and compute standardized residuals
influence_probit_model2 <- probit_model2.get_influence()
h_probit_model2 <- influence_probit_model2.hat_matrix_diag
std_resid_probit_model2 <- resid_probit_model2 / np.sqrt(1 - h_probit_model2)

# ---- New Cell ----

# Distribution of standardized Pearson residuals by firm cluster (NFD & FD) for each model
# Figure size and subplots 
fig, axes <- plt.subplots(1, 3, figsize <- (20, 6), sharey <- True)

# Non-financial distress and financial distress firms mask to segmentate the residuals based on firms cluster
mask_fd <- (y_train_reg2 <- = 1)
mask_nfd <- (y_train_reg2 <- = 0)

# Random normal PDF generation
x <- np.linspace(-4, 4, 500)
normal_pdf <- stats.norm.pdf(x)

# Linear probability (LPM)
# kernel density plotting for LPM residuals (line)
sns.kdeplot(std_resid_lpm_model2[mask_fd].dropna(), ax <- axes[0], label <- "Financial Distress (y <- 1)", color <- "darkred", bw_adjust <- 1)
sns.kdeplot(std_resid_lpm_model2[mask_nfd].dropna(), ax <- axes[0], label <- "Non-Financial Distress (y <- 0)", color <- "lightcoral", bw_adjust <- 1)
# Kernel density computation per cluster (NFD & FD)
kde_fd <- stats.gaussian_kde(std_resid_lpm_model2[mask_fd].dropna())
kde_nfd <- stats.gaussian_kde(std_resid_lpm_model2[mask_nfd].dropna())
# Normal PDF plotting
axes[0].plot(x, normal_pdf, color <- "black", linestyle <- "--", label <- "Normal (PDF)")
# Colored area below the curve
axes[0].fill_between(x, kde_fd(x), color <- "darkred", alpha <- 0.3)
axes[0].fill_between(x, kde_nfd(x), color <- "lightcoral", alpha <- 0.3)
# Subplot settings
axes[0].set_title("Linear Probability (LPM)")
axes[0].set_xlabel("Standardized Pearson Residual")
axes[0].set_ylabel("Kernel Density")
axes[0].legend()

# Logit
sns.kdeplot(std_resid_logit_model2[mask_fd].dropna(), ax <- axes[1], label <- "Financial Distress (y <- 1)", color <- "darkblue", bw_adjust <- 1)
sns.kdeplot(std_resid_logit_model2[mask_nfd].dropna(), ax <- axes[1], label <- "Non-Financial Distress (y <- 0)", color <- "lightskyblue", bw_adjust <- 1)
kde_fd <- stats.gaussian_kde(std_resid_logit_model2[mask_fd].dropna())
kde_nfd <- stats.gaussian_kde(std_resid_logit_model2[mask_nfd].dropna())
axes[1].plot(x, normal_pdf, color <- "black", linestyle <- "--", label <- "Normal (PDF)")
axes[1].fill_between(x, kde_fd(x), color <- "darkblue", alpha <- 0.3)
axes[1].fill_between(x, kde_nfd(x), color <- "lightskyblue", alpha <- 0.3)
axes[1].set_title("Logit")
axes[1].set_xlabel("Standardized Pearson Residual")
axes[1].legend()

# Probit
sns.kdeplot(std_resid_probit_model2[mask_fd].dropna(), ax <- axes[2], label <- "Financial Distress (y <- 1)", color <- "indigo", bw_adjust <- 1)
sns.kdeplot(std_resid_probit_model2[mask_nfd].dropna(), ax <- axes[2], label <- "Non-Financial Distress (y <- 0)", color <- "plum", bw_adjust <- 1)
kde_fd <- stats.gaussian_kde(std_resid_probit_model2[mask_fd].dropna())
kde_nfd <- stats.gaussian_kde(std_resid_probit_model2[mask_nfd].dropna())
axes[2].plot(x, normal_pdf, color <- "black", linestyle <- "--", label <- "Normal (PDF)")
axes[2].fill_between(x, kde_fd(x), color <- "indigo", alpha <- 0.3)
axes[2].fill_between(x, kde_nfd(x), color <- "plum", alpha <- 0.3)
axes[2].set_title("Probit")
axes[2].set_xlabel("Standardized Pearson Residual")
axes[2].legend()

# General settings and layout
plt.suptitle("Figure 13 - Distribution of Standardized Pearson Residuals by Firm Cluster (NFD & FD)")
plt.tight_layout(rect <- [0, 0, 1, 0.95])
# plots are shown automatically in R

# ---- New Cell ----

# Outliers threshold
outliers_threshold <- 2

# ---- New Cell ----

# LPM
# We take the index for each residual bigger than the threshold
outliers_idx_lpm_model2 <- np.where(np.abs(std_resid_lpm_model2) > outliers_threshold)[0]
# We use the index of these latter to filter the original dataset, and get only the outliers
outliers_lpm_model2 <- std_resid_lpm_model2.iloc[outliers_idx_lpm_model2]
# The same filter is applied to the predicted y dataset to understand which side gives them (if nfd or fd)
outliers_y_lpm_model2 <- y_train_reg2.iloc[outliers_idx_lpm_model2]

# Build a DataFrame summarizing the outliers
summary_table3_lpm_residuals <- data.frame({
    "Residual": outliers_lpm_model2.values,
    "Side": [
        "Positive extreme" if residual > 0 else "Negative extreme" for residual in outliers_lpm_model2
        ],
    "Firm cluster": [
        "FD (yd <- 1)" if yd <- = 1 else "NFD (yd <- 0)" for yd in outliers_y_lpm_model2
        ],
    "Obs Index": outliers_idx_lpm_model2 
})

# Index reset based on the original firms positioning
summary_table3_lpm_residuals <- summary_table3_lpm_residuals.set_index("Obs Index")
summary_table3_lpm_residuals <- summary_table3_lpm_residuals[["Residual", "Side", "Firm cluster"]]
summary_table3_lpm_residuals

# ---- New Cell ----

# Logit
outliers_idx_logit_model2 <- np.where(np.abs(std_resid_logit_model2) > outliers_threshold)[0]
outliers_logit_model2 <- std_resid_logit_model2.iloc[outliers_idx_logit_model2]
outliers_y_logit_model2 <- y_train_reg2.iloc[outliers_idx_logit_model2]

summary_table3_logit_residuals <- data.frame({
    "Residual": outliers_logit_model2.values,
    "Side": [
        "Positive extreme" if residual > 0 else "Negative extreme" for residual in outliers_logit_model2
        ],
    "Firm cluster": [
        "FD (yd <- 1)" if yd <- = 1 else "NFD (yd <- 0)" for yd in outliers_y_logit_model2
        ],
    "Obs Index": outliers_idx_logit_model2 
})

summary_table3_logit_residuals <- summary_table3_logit_residuals.set_index("Obs Index")
summary_table3_logit_residuals <- summary_table3_logit_residuals[["Residual", "Side", "Firm cluster"]]
summary_table3_logit_residuals

# ---- New Cell ----

# Probit
outliers_idx_probit_model2 <- np.where(np.abs(std_resid_probit_model2) > outliers_threshold)[0]
outliers_probit_model2 <- std_resid_probit_model2.iloc[outliers_idx_probit_model2]
outliers_y_probit_model2 <- y_train_reg2.iloc[outliers_idx_probit_model2]

summary_table3_probit_residuals <- data.frame({
    "Residual": outliers_probit_model2.values,
    "Side": [
        "Positive extreme" if residual > 0 else "Negative extreme" for residual in outliers_probit_model2
        ],
    "Firm cluster": [
        "FD (yd <- 1)" if yd <- = 1 else "NFD (yd <- 0)" for yd in outliers_y_probit_model2
        ],
    "Obs Index": outliers_idx_probit_model2 
})

summary_table3_probit_residuals <- summary_table3_probit_residuals.set_index("Obs Index")
summary_table3_probit_residuals <- summary_table3_probit_residuals[["Residual", "Side", "Firm cluster"]]
summary_table3_probit_residuals

# ---- New Cell ----

# Model preference simulation (ROC curve): private banker profile
# We set the potential loss in case of false positive or false negative
cost_FP <- 0.1
# We suppose that the monetary loss due to predicting a defaulting company as non-defaulting is much more heavier than the opposite  
cost_FN <- 0.2

# Ratio of NFD and FD over the total (testing sample) 
nfd_ratio_test <- num_test_nfd/(num_test_nfd + num_test_fd)
fd_ratio_test <- 1.0 - nfd_ratio_test

# We define an helper function to compute the best threshold based on the expected loss parameters

# Function best_threshold <- function(real_test_y, predicted_test_y, cost_falsepositive, cost_falsenegative, nfd_ratio_test, fd_ratio_test, model_name) {
# The function roc_curve() has already a built-in function to fetch false positive and true positive ratios, as well as thresholds
    fpr, tpr, thresholds <- roc_curve(real_test_y, predicted_test_y)
# EXPECTED LOSS per threshold (vector) 
# PS. DONT CONFUSE NAMES, defaulting is positive in the sense that the firm test positive to being defaulting 
# False positive (non-defaulting firms identified as defaulting) -> cost of false positive * probability of false positives * probability of picking a nfd firm
# False negative (defaulting firms identified as non-defaulting) -> cost of false negative * probability of false negatives (1 - probability of real defaulting) * probability of picking a fd firm
# Conditional probability
    EXPECTED_LOSS <- cost_falsepositive * fpr * nfd_ratio_test + cost_falsenegative * (1 - tpr) * fd_ratio_test
# Minimize expected loss (finds teh index of the thereshold of when expected loss in minimal)
    best_idx <- np.argmin(EXPECTED_LOSS)
    # return {
        "Model": model_name,
        "Best Threshold": float(thresholds[best_idx]),
        "Minimum Expected Loss": float(EXPECTED_LOSS[best_idx]),
        "FPR at best": float(fpr[best_idx]),
        "TPR at best": float(tpr[best_idx])
    }

# Apply the function to each model
threshold_lpm <- best_threshold(y_test_reg2, y_pred_lpm_model2_test, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Linear Probability (LPM)")
threshold_logit <- best_threshold(y_test_reg2, y_pred_logit_model2_test, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Logit")
threshold_probit <- best_threshold(y_test_reg2, y_pred_probit_model2_test, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Probit")

summary_table4_thresholds <- data.frame([threshold_lpm, threshold_logit, threshold_probit]).round(4)
summary_table4_thresholds

# ---- New Cell ----

# Sensitivity and Specificity with respect to Probability Cutoff (LPM)
# Assume y_test_reg2 (actual values) and y_pred_lpm_model2_test (predicted values) are already defined
# sensitivity <- tpr 
# specificity <- tnr
fpr, tpr, thresholds <- roc_curve(y_test_reg2, y_pred_lpm_model2_test)
specificity <- 1 - fpr 

# Smooth plotting and sorting
order <- np.argsort(thresholds)
thresholds <- thresholds[order]
tpr <- tpr[order]
specificity <- specificity[order]

# Plotting the two sensitivity and specificity 
plt.figure(figsize <- (8, 6))
plot(thresholds, tpr, label <- "Sensitivity", marker <- "o", color <- "blue", type='l')
plot(thresholds, specificity, label <- "Specificity", linestyle <- "--", marker <- "D", color <- "cornflowerblue", type='l')

# General settings and layout
plt.xlabel("Probability Cutoff")
plt.ylabel("Sensitivity/Specificity")
plt.title("Figure 14 - Sensitivity and Specificity with respect to Probability Cutoff (LPM)")
plt.legend()
plt.grid(True)
plt.ylim([-0.05, 1.05])
# plots are shown automatically in R

# ---- New Cell ----

# Sensitivity and Specificity with respect to Probability Cutoff (Logit)
# Assume y_test_reg2 (actual values) and y_pred_logit_model2_test (predicted values) are already defined
# sensitivity <- tpr 
# specificity <- tnr
fpr, tpr, thresholds <- roc_curve(y_test_reg2, y_pred_logit_model2_test)
specificity <- 1 - fpr 

# Smooth plotting and sorting
order <- np.argsort(thresholds)
thresholds <- thresholds[order]
tpr <- tpr[order]
specificity <- specificity[order]

# Plotting the two sensitivity and specificity 
plt.figure(figsize <- (8, 6))
plot(thresholds, tpr, label <- "Sensitivity", marker <- "o", color <- "red", type='l')
plot(thresholds, specificity, label <- "Specificity", linestyle <- "--", marker <- "D", color <- "coral", type='l')

# General settings and layout
plt.xlabel("Probability Cutoff")
plt.ylabel("Sensitivity/Specificity")
plt.title("Figure 15 - Sensitivity and Specificity with respect to Probability Cutoff (Logit)")
plt.legend()
plt.grid(True)
plt.ylim([-0.05, 1.05])
# plots are shown automatically in R

# ---- New Cell ----

# Sensitivity and Specificity with respect to Probability Cutoff (Logit)
# Assume y_test_reg2 (actual values) and y_pred_logit_model2_test (predicted values) are already defined
# sensitivity <- tpr 
# specificity <- tnr
fpr, tpr, thresholds <- roc_curve(y_test_reg2, y_pred_probit_model2_test)
specificity <- 1 - fpr 

# Smooth plotting and sorting
order <- np.argsort(thresholds)
thresholds <- thresholds[order]
tpr <- tpr[order]
specificity <- specificity[order]

# Plotting the two sensitivity and specificity 
plt.figure(figsize <- (8, 6))
plot(thresholds, tpr, label <- "Sensitivity", marker <- "o", color <- "purple", type='l')
plot(thresholds, specificity, label <- "Specificity", linestyle <- "--", marker <- "D", color <- "orchid", type='l')

# General settings and layout
plt.xlabel("Probability Cutoff")
plt.ylabel("Sensitivity/Specificity")
plt.title("Figure 16 - Sensitivity and Specificity with respect to Probability Cutoff (Probit)")
plt.legend()
plt.grid(True)
plt.ylim([-0.05, 1.05])
# plots are shown automatically in R

# ---- New Cell ----

# Dummy Trap Analysis (MODEL 1)
# tdta regressed on yd, ynd with common intercept
# From the training sample, we extract the dependent variable (tdta)
tdta <- X_train["Debt/Assets"]
# From the same sample we extract yd (Financial distress), previous dependent, now turned into a dummy
yd <- y_train
# ynd dummy for non-distressed firms
ynd <- 1 - yd

# Combined dataset for OLS on tdta 
# Set intercept (Xtdta1)
Xtdta1 <- data.frame({
    "yd": yd,
    "ynd": ynd
})
Xtdta1 <- sm.add_constant(Xtdta1)

# tdta - MODEL 1
# dependent <- TDTA, regressors <- yd + ynd, intercept <- constant 
# MULTICOLLINEARITY ISSUE: yd and ynd trigger the same event
tdta_model1 <- sm.OLS(tdta, Xtdta1).fit()

# ---- New Cell ----

# Dummy Trap Analysis (MODEL 2)
# Tdta regressed on yd and common intercept 
Xtdta2 <- data.frame({
    "yd": yd
})
Xtdta2 <- sm.add_constant(Xtdta2)

# tdta - MODEL 2
# dependent <- TDTA, regressors <- yd, intercept <- constant 
tdta_model2 <- sm.OLS(tdta, Xtdta2).fit()

# ---- New Cell ----

# Dummy Trap Analysis (MODEL 3)
# Tdta regressed on ynd and common intercept
Xtdta3 <- data.frame({
    "ynd": ynd
})
Xtdta3 <- sm.add_constant(Xtdta3)

# tdta - MODEL 3
# dependent <- TDTA, regressors <- ynd, intercept <- constant 
tdta_model3 <- sm.OLS(tdta, Xtdta3).fit()

# ---- New Cell ----

# Dummy Trap Analysis (MODEL 4)
# Tdta regressed on yd, ynd with common intercept and the restriction that the sum of parameters of yd and ynd are equal to zero
Xtdta4 <- data.frame({
    "yd": yd,
    "ynd": ynd
})
Xtdta4 <- sm.add_constant(Xtdta4)

# tdta - MODEL 4
# dependent <- TDTA, regressors <- yd + ynd, intercept <- constant, constraint
# .fit_constrained() is only available for GLS estimators
tdta_model4_constraint <- "yd + ynd <- 0"
tdta_model4 <- sm.GLM(tdta, Xtdta4)
tdta_model4_constrained <- tdta_model4.fit_constrained(tdta_model4_constraint)

# ---- New Cell ----

# We deploy stargazer and HTML libaries to display custom summary tables
stargazer_all <- Stargazer([tdta_model1, tdta_model2, tdta_model3, tdta_model4_constrained])
stargazer_all.title("Debt-to-Assets Regression Results: Dummy Trap Comparison")
stargazer_all.custom_columns(["Model 1: yd + ynd", "Model 2: yd", "Model 3: ynd", "Model 4: Restricted yd + ynd"], [1, 1, 1, 1])
stargazer_all.dependent_variable_name("Debt/Assets")
stargazer_all.add_line("Model Type", ["OLS", "OLS", "OLS", "GLM (Constraint yd+ynd <- 0)"])
stargazer_all.significance_levels([0.001, 0.01, 0.05])
stargazer_all.add_custom_notes([
    "Standard errors in parentheses."
])
stargazer_all.covariate_order(["const", "yd", "ynd"])
stargazer_all.show_degrees_of_freedom(False)

HTML(stargazer_all.render_html())

# ---- New Cell ----

# 1) Sorting fo variables including yd also (it was done only by one explanatory variable)
# 2) Followed a different order for data split in train and test sample
# 3) X matrix trasposition for better visualization of descriptive statistics 
# 4) outliers cleaning and distribution analysis
# 5) Violin Plot 
# 6) "Reg" instead of "scatter" in scatterplot's kind
# 7) we use both Jarque bera stat as well as its pvalue 
# 8) stargaze

# ---- New Cell ----

# Train/Test partitioning (dependent y & independent variables X)
# For performance comparability, we keep the same train-test samples split, even though it is not optimal 
y_nntrain <- df_train["Financial Distress"].copy()
y_nntest <- df_test["Financial Distress"].copy()

X_nntrain <- df_train.drop(columns <- ["Financial Distress"]).copy()
X_nntest <- df_test.drop(columns <- ["Financial Distress"]).copy()

# ---- New Cell ----

# NaN handling 
# Instead of dropping  missing values, here we fill them by setting the imputer to the "median", hence NaN values will be replaced with observations clustering around the median
# Then for each variable, we subtract its mean and divide by its standard deviation (forced normalization)
imputer <- SimpleImputer(strategy <- "median")
scaler <- StandardScaler()

# We apply scaler and imputer to the train sample
# All variables are now centered at 0 and with unit variance
X_nntrain_imputed <- imputer.fit_transform(X_nntrain)
X_nntrain_scaled <- scaler.fit_transform(X_nntrain_imputed)

# And we rescale the test sample as well to be plugged for forecasting
X_nntest_scaled <- scaler.transform(imputer.transform(X_nntest))

data.frame(X_nntrain_scaled)

# ---- New Cell ----

# We now control for between-classes imbalance 
# In other words, we chacek whether one between FD or NFD is over or under represented 
from collections # (Library import not needed - using Base R only)
cat("Train class distribution:", Counter(y_nntrain, '
'))

# ---- New Cell ----

# Class weights
# Despite the dataset is roughly balanced, we still opt for class weights, by assigning an heavier weight to FD observations (under-represented class), so that the learning algorithm will give them more attention
# One of the alternatives could be to go for SMOTE (Synthetic Minority Oversampling Technique)
# SMOTE simulates new synthetic (artificial) samples derived from the minority class, in which we interpolate two close minority observation to create a synthetic observation in the middle between the two
# It would be optimal for us as we have a considerably small sample, but that would also alter the comparability of in-sample performances with other models we computed

NFD_FD_classes <- np.unique(y_nntrain)
NFD_FD_weights <- compute_class_weight("balanced", classes <- NFD_FD_classes, y <- y_nntrain)
NFD_FD_weight_dict <- dict(zip(NFD_FD_classes, NFD_FD_weights))
cat("Dictionary of class weights (NFD <- 0, FD <- 1, '
') =", NFD_FD_weight_dict)

# ---- New Cell ----

# Baseline Logit
# We now run a Logit regression on our rescaled data to use it as a baseline to control for the performance of newural networks, usually NN shoudl be able to beat Logit
# Logit is train on rebalanced train observations and, despite this might affect the replicability of results, we do not set a random seed for train-test, as once again we want to preserve the comparibility of our results with the models presented in Part 1
base_lr <- LogisticRegression(class_weight <- "balanced")
# Model fit on rescaled train data (obv only for X)
base_lr.fit(X_nntrain_scaled, y_nntrain)
probs_base_lr <- base_lr.predict_proba(X_nntest_scaled)[:,1]

y_base_lr <- data.frame(probs_base_lr)
y_base_lr.head(10)

# ---- New Cell ----

# Baseline Logit - Model Performance Summary Table
summary_base_lr <- data.frame({
    "Model": ["Baseline Logit"], 
    "AUC (balanced training sample)": [round(roc_auc_score(y_nntest, probs_base_lr), 4)],
    "Testing Sample Average": [round(y_nntest.mean(), 4)],
    "Predicted Average": [round(probs_base_lr.mean(), 4)],
}).reset_index(drop <- True)

# We first traspose the dataset to move the models on the columns, to secondly rename the columns and set new headers
summary_base_lr <- summary_base_lr.T
summary_base_lr.columns <- summary_base_lr.iloc[0]
summary_base_lr <- summary_base_lr.drop(summary_base_lr.index[0])

cat("Summary Table - Baseline Logit (re-scaled training sample, '
')")
summary_base_lr

# ---- New Cell ----

# Neural Network Construction
# We set the function to build the model with the parameters: input_dim (number of variables/features), hidden_units (number of neurons for each hidden leayer), dropout_rate (fraction of neurons randomly disabled during training to reduce overfitting), learning_rate (step size for optimizer updates)
def build_model(input_dim,
# First hidden layer at 64 and second layer at 32 neurons 
                 hidden_units <- [64, 32],
# Probability of a neuron of being ignored (temporarily) at each training step, to improve the learning curve (we set it at 30%)
                 dropout_rate <- 0.3,
# Adam's trade-off of speed and stability for the training, it may take a bit longer compared to 1e-2, but the chnaces of over-shooting are less
                 learning_rate <- 1e-3):

# Layer-by-layer building process
    model <- Sequential()
# 64 neurons layer by default 
# We set "relu" for introducing non-linearuty to allow the model to learn more complex patterns
    model.add(Dense(hidden_units[0], input_dim <- input_dim, activation <- "relu"))
# Normalization of activations between layers
    model.add(BatchNormalization())
# Setting drop-out
    model.add(Dropout(dropout_rate))

# If the network has more than one-dimension of hidden layers, it adds another module of normalization and drop-out
    if len(hidden_units) > 1:
        model.add(Dense(hidden_units[1], activation <- "relu"))
        model.add(BatchNormalization())
        model.add(Dropout(dropout_rate))
    
# We set 1 single neuron for the output as our dependent variable to predict is binary (binary output)
# Sigmoid converts the output into a probability between 0 and 1
    model.add(Dense(1, activation <- "sigmoid"))
# We use Adam optimizer as it adapts the learning rate as training progresses
    opt <- Adam(learning_rate <- learning_rate)
# Here in the core function we set the parameters of the model 
# optimizer set Adam as optimizing engine
# We set "binary_crossentropy" as standard loss function for binary classification
# And last we evaluate the model performances based on AUC
    model.compile(optimizer <- opt, loss <- "binary_crossentropy", metrics <- ["AUC"])
    
# The function eventually returns the fully configured Keras model
    # return model

# ---- New Cell ----

# Instantiate
# We specifiy the model dimension (=14)
input_dim <- X_nntrain_scaled.shape[1] 
# And here we see the structure of the model ready for training 
nn_model1 <- build_model(input_dim, hidden_units <- [64,32], dropout_rate <- 0.3, learning_rate <- 1e-3)
# We also set the input shape for plotting
nn_model1.build(input_shape <- (None, X_train.shape[1]))
nn_model1.summary()

# ---- New Cell ----

# Callback and Training 
callbacks <- [
# We set an early stopping in the learning in order to stop training early if the val_loss doesn't improve for 20 consecutive epochs, restoring the best weights obtained during training
# Val loss refers to the deviation from the predicted value and the actual value in the validation sample which works as in-sample testing sample proxy    
    EarlyStopping(monitor <- "val_loss", patience <- 20, restore_best_weights <- True, verbose <- 1),
# Here instead, after 8 non-impoving epochs the model reduces the learning rate by half
    ReduceLROnPlateau(monitor <- "val_loss", factor <- 0.5, patience <- 8, verbose <- 1),
# The checkpoint function saves the model weights to a file named "best_model.h5" whenever the val_loss improves, so we can keep track of the best performing model
    ModelCheckpoint("best_model.h5", monitor <- "val_loss", save_best_only <- True, verbose <- 0)
]

# The loop runs 100 times to allow the model to find tht top-permorming model in terms of AUC maximization, it will save the model only if it beats the already saved best_model.h5
# Average run time <- 7 mins (now set at 2 to speed up the computation)
for i in range(2):
    cat(f"\nRun {i+1}/100", '
')
# We fit the model to the training set by calibrating the learning stage on the earlier computed weights
    history <- nn_model1.fit(
        X_nntrain_scaled, y_train,
# Further split training set for validation (different from testing)
        validation_split <- 0.2,
# We set the max executable epochs at 200  
        epochs <- 200,
# We reduce the batch size to speed up the training 
        batch_size <- 16,         
# We take the earlier computed weights for class imbalance
        class_weight <- NFD_FD_weight_dict,
        callbacks <- callbacks,
        verbose <- 2
    )

# ---- New Cell ----

# Testing
# We plug the best combo of weights saved in best_model.h5 checkpoint into the model memory
nn_model1.load_weights("best_model.h5")
# Predict y and compute AUC
y_pred_nn_model1 <- nn_model1.predict(X_nntest_scaled).ravel()
auc_nn_model1 <- roc_auc_score(y_test, y_pred_nn_model1)

# Default threshold 0.5
y_pred_05_nn_model1 <- (y_pred_nn_model1 >= 0.5).astype(int)
# Accuracy <- ratio of all corrected predictions over all the predictions made
accuracy_nn_model1 <- accuracy_score(y_test, y_pred_05_nn_model1)
# Precision <- ratio of the corrected guessed positive over the total positive predicted
precision_nn_model1 <- precision_score(y_test, y_pred_05_nn_model1)
# Recall <- Sensitivity <- the proportion of true positives out of all actual positives.
recall_nn_model1 <- recall_score(y_test, y_pred_05_nn_model1)
# F1 <- ranges from 0 to 1. 2X (Precision x Recall/(Precision + Recall))
f1_nn_model1 <- f1_score(y_test, y_pred_05_nn_model1)
# Confusion Matrix
conf_matrix <- confusion_matrix(y_test, y_pred_05_nn_model1)

# Create DataFrame with results
results_df_nn_model1 <- data.frame({
    "Testing Sample yd": y_test,
    "Predicted y (prob)": y_pred_nn_model1,
    "Predicted yd (0.5 threshold)": y_pred_05_nn_model1
})

cat("Summary of Results - Neural Network Model 1", '
')
results_df_nn_model1

# ---- New Cell ----

# Metrics Summary
metrics_summary_nn_model1 <- data.frame({
    "NN Model 1 - Metric": ["ROC AUC", "Accuracy", "Precision", "Recall", "F1 Score"],
    "Value": [auc_nn_model1, accuracy_nn_model1, precision_nn_model1, recall_nn_model1, f1_nn_model1]
})

cat("Summary of Metrics - Neural Network Model 1", '
')
metrics_summary_nn_model1

# ---- New Cell ----

# Confusion matrix plotting (with 0.5 threshold)
ConfusionMatrixDisplay.from_predictions(y_test, y_pred_05_nn_model1)
plt.title("Confusion Matrix - Neural Network Model 1")
# plots are shown automatically in R

# ---- New Cell ----

# ROC curve plotting
plt.figure(figsize <- (8, 6))

# Integrated sklearn ROC plotting - ROC for predicted values at best_model.h5 weights
nn_model1_roc_display <- RocCurveDisplay.from_predictions(y_test, y_pred_nn_model1, name <- "Neural Network 1", color <- "blue", lw <- 3)
# Random-Guess Baseline (AUC <- 0.5)
plot([0, 1], [0, 1], linestyle <- '--', color <- "gray", label <- "Random-Guess Baseline (AUC <- 0.5, type='l')")

# General settings and layout
plt.title("ROC Curve - Neural Network Model 1", fontsize <- 15)
plt.xlabel("False Positive Rate")
plt.ylabel("True Positive Rate")
plt.legend(loc <- "lower right")
plt.grid(True)
# plots are shown automatically in R

# ---- New Cell ----

# Optimal Threshold for loss function minimization
# From the earlier computed loss function given the arbitrary chosen costs of False Positive and False Negatives
cost_FP <- 0.1
cost_FN <- 0.2

# Ratio of NFD and FD over the total (testing sample) 
nfd_ratio_test <- num_test_nfd/(num_test_nfd + num_test_fd)
fd_ratio_test <- 1.0 - nfd_ratio_test

# We recall the best_threshold function and apply to NN model 1 and the baseline logit 
threshold_base_lr <- best_threshold(y_test, y_base_lr, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Baseline Logit")
threshold_nn_model1 <- best_threshold(y_test, y_pred_nn_model1, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Neural Networks Model 1")
summary_threshold_nn_model1 <- data.frame([threshold_base_lr, threshold_nn_model1]).round(4)
summary_threshold_nn_model1

# ---- New Cell ----

# Hyperparameters tuning
# In this section we look for the best parameters to be plug in our model to increase its AUC performance
# In the context of hyperparameters, we refer to the last 3 elements of the model function nn_model1 <- build_model(input_dim, hidden_units <- [64,32], dropout_rate <- 0.3, learning_rate <- 1e-3)

# Function build_for_search <- function(hidden_units <- 32, dropout_rate <- 0.2, lr <- 1e-3) {
    # return build_model(
        input_dim,
        hidden_units <- [hidden_units, int(hidden_units / 2)],
        dropout_rate <- dropout_rate,
        learning_rate <- lr
    )

# Model wrap
# We reduce epoch to 2 for displaying results
# We turn our Keras model in something that behaves like a normal scikit-learn classifier
keras_clf <- KerasClassifier(model <- build_for_search, epochs <- 2, verbose <- 0) 

# Parameters grid
# All the possible combinations of hyperparameters to try
param_grid <- {
    "model__hidden_units": [32, 64],      
    "model__dropout_rate": [0.2, 0.4],
    "model__lr": [1e-3, 1e-4],
# Only for speeding up the matching
    "batch_size": [8, 16]                 
}

# Default cv <- 3 in GridSearchCV
# It trains a new model for each combination of parameters, evaluating each model using cross-validation (cv <- 3, splits data into 3 folds)
# It then calculates the AUC (area under ROC) for each, to find the best combination that gives you the highest AUC
grid <- GridSearchCV(keras_clf, param_grid, scoring <- "roc_auc", cv <- 3)
# This runs all models
grid.fit(X_nntrain_scaled, y_nntrain)

cat("Best params:", grid.best_params_, '
')
cat("Best CV AUC:", grid.best_score_, '
')

# ---- New Cell ----

# Model 2 Training 
# Recall the fine-tuned model with improved hyperparameters
nn_model2 <- build_model(input_dim, hidden_units <- [32,16], dropout_rate <- 0.2, learning_rate <- 0.001)

# Model 2 training with 100 epochs with improved hyper-parameters
# Fore results display we reduce the epochs to 2 
history <- nn_model2.fit(
    X_nntrain_scaled, y_nntrain,
    epochs <- 100,              
    batch_size <- 8,
    validation_split <- 0.2,  
    verbose <- 1
)

# ---- New Cell ----

# Out-of-sample testing Model 2
y_pred_nn_model2 <- nn_model2.predict(X_nntest_scaled).ravel()
auc_nn_model2 <- roc_auc_score(y_test, y_pred_nn_model2)

# Default threshold 0.5
y_pred_05_nn_model2 <- (y_pred_nn_model2 >= 0.5).astype(int)
# Accuracy <- ratio of all corrected predictions over all the predictions made
accuracy_nn_model2 <- accuracy_score(y_test, y_pred_05_nn_model2)
# Precision <- ratio of the corrected guessed positive over the total positive predicted
precision_nn_model2 <- precision_score(y_test, y_pred_05_nn_model2)
# Recall <- Sensitivity <- the proportion of true positives out of all actual positives.
recall_nn_model2 <- recall_score(y_test, y_pred_05_nn_model2)
# F1 <- ranges from 0 to 1. 2X (Precision x Recall/(Precision + Recall))
f1_nn_model2 <- f1_score(y_test, y_pred_05_nn_model2)
# Confusion Matrix
conf_matrix <- confusion_matrix(y_test, y_pred_05_nn_model2)

# Create DataFrame with results
results_df_nn_model2 <- data.frame({
    "Testing Sample yd": y_test,
    "Predicted y (prob)": y_pred_nn_model2,
    "Predicted yd (0.5 threshold)": y_pred_05_nn_model2
})

cat("Summary of Results - Neural Network Model 2", '
')
results_df_nn_model2

# ---- New Cell ----

# Metrics Summary
metrics_summary_nn_model2 <- data.frame({
    "NN Model 2 - Metric": ["ROC AUC", "Accuracy", "Precision", "Recall", "F1 Score"],
    "Value": [auc_nn_model2, accuracy_nn_model2, precision_nn_model2, recall_nn_model2, f1_nn_model2]
})

cat("Summary of Metrics - Neural Network Model 2", '
')
metrics_summary_nn_model2

# ---- New Cell ----

# ROC curve plotting
plt.figure(figsize <- (8, 6))  

# Integrated sklearn ROC plotting - ROC for predicted values at best_model.h5 weights
nn_model2_roc_display <- RocCurveDisplay.from_predictions(y_test, y_pred_nn_model2, name <- "Neural Network 2", color <- "red", lw <- 3)
# Random-Guess Baseline (AUC <- 0.5)
plot([0, 1], [0, 1], linestyle <- '--', color <- "gray", label <- "Random-Guess Baseline (AUC <- 0.5, type='l')")

# General settings and layout
plt.title("ROC Curve - Neural Network Model 2", fontsize <- 15)
plt.xlabel("False Positive Rate")
plt.ylabel("True Positive Rate")
plt.legend(loc <- "lower right")
plt.grid(True)
# plots are shown automatically in R

# ---- New Cell ----

# Model Calibration 
# We wrap a model that provides predict_proba — scikit-learn logistic is calibrated by default
# We should use in this step the validation (no testing) partition, but given the size of our dataset, that would be too small, which means we need to reshuffle the training set to have room for a validation sample
X_subtrain, X_calib, y_subtrain, y_calib <- train_test_split(X_nntrain_scaled, y_nntrain, test_size <- 0.2, random_state <- 42)

# Train NN Model 2 on sub-training with Validation Sample
nn_model2.fit(X_subtrain, y_subtrain)
# Continuous probabilities 
probs_calib <- nn_model2.predict(X_calib).ravel()
logistic_calibrator <- LogisticRegression().fit(probs_calib.reshape(-1,1), y_calib)
y_pred_nn_calibrated_model2 <- nn_model2.predict(X_nntest_scaled).ravel()
auc_nn_calibrated_model2 <- roc_auc_score(y_nntest, y_pred_nn_calibrated_model2)

# Metrics Computation (binary y at optimal threshold threshold)
y_binary_pred_nn_calibrated_model2 <- (y_pred_nn_calibrated_model2 >= 0.2616).astype(int)
accuracy_nn_calibrated_model2 <- accuracy_score(y_nntest, y_binary_pred_nn_calibrated_model2)
precision_nn_calibrated_model2 <- precision_score(y_nntest, y_binary_pred_nn_calibrated_model2)
recall_nn_calibrated_model2 <- recall_score(y_nntest, y_binary_pred_nn_calibrated_model2)
f1_nn_calibrated_model2 <- f1_score(y_nntest, y_binary_pred_nn_calibrated_model2)

# Metrics Summary
metrics_summary_nn_calibrated_model2 <- data.frame({
    "NN Calibrated Model 2 - Metric": ["ROC AUC", "Accuracy", "Precision", "Recall", "F1 Score"],
    "Value": [auc_nn_calibrated_model2, accuracy_nn_calibrated_model2, precision_nn_calibrated_model2, recall_nn_calibrated_model2, f1_nn_calibrated_model2]
})

# At every run, the results change as we are retraining the model 2 on a new randomly initialized neural network, and, a new logistic regression calibrator on slightly different predicted probabilities
cat("Summary of Metrics - Neural Network Calibrated Model 2", '
')
metrics_summary_nn_calibrated_model2

# ---- New Cell ----

# Shapley Values (SHapley Additive exPlanations)
# We want to understand how each feature has influenced our model in its decisions
# The SHAP value of each feature is the average contribution of the variable 
# The magnitude tell you how much it changes the probability of yd, while the sign tells you in which direction this impact goes when included in the model (sort of regression coefficient)
# Here we use SHAP (KernelExplainer) to estimate feature attributions (Shapley values) for predictions. KernelExplainer is model-agnostic (it treats the model as a black box and queries predictions).
# We set again the same random seed to ensure that sampling or random operations give the same result every time we rerun teh code
SEED <- 42

# shap.KernelExplainer is used to explain predictions using teh kernel SHAP approach
# the random seed is the same but we take 50 examples of observations from the training (background dataset)
# KernelExplainer uses the background dataset to simulate “missingness” when computing Shapley values and estimates each feature’s contribution by querying
explainer <- shap.KernelExplainer(lambda x: nn_model2.predict(x).ravel(), shap.sample(X_nntrain_scaled, 50, random_state <- SEED))
# The explainer then takes 30 examples from your test set to explain
# Fore each run shap takes one feature out (variable) and tests how the model performs without (perturbation)
# Long run for 30 obs (11 mins)
shap_values <- explainer.shap_values(shap.sample(X_nntest_scaled, 30, random_state <- SEED))

# Summary plot
# For 30 runs how was the impact of each feature on yd
shap.summary_plot(shap_values, shap.sample(X_nntest_scaled, 30, random_state <- SEED), feature_names <- X_nntrain.columns)