# Required Libraries
suppressWarnings({
  suppressPackageStartupMessages({
    library(data.table)
    library(dplyr)
    library(tidyr)
    library(ggplot2)
    library(ggpubr)
    library(GGally)
    library(moments)
    library(car)
    library(tseries)
    library(pROC)
    library(stargazer)
    library(pscl)
    library(reshape2)
    library(stringr)
    library(corrplot)
  })
})

# -----------------------------
# Variables dictionary
variables <- c(
  "yd" = "Financial Distress",
  "tdta" = "Debt/Assets",
  "reta" = "Retained Earnings",
  "opita" = "Income/Assets",
  "ebita" = "Pre-Tax Earnings/Assets",
  "lsls" = "Log Sales",
  "lta" = "Log Assets",
  "gempl" = "Employment Growth",
  "invsls" = "Inventory/Sales",
  "nwcta" = "Net Working Capital/Assets",
  "cacl" = "Current Assets/Liabilities",
  "qacl" = "Quick Assets/Liabilities",
  "fata" = "Fixed Assets/Total Assets",
  "ltdta" = "Long-Term Debt/Total Assets",
  "mveltd" = "Market Value Equity/Long-Term Debt"
)

# Inverted variables dictionary
inverted_variables <- setNames(names(variables), variables)

# Significance stars
significance_stars <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.001) return("***")
  if (p < 0.01) return("**")
  if (p < 0.05) return("*")
  return("")
}

# -----------------------------
# Data Retrieval
raw_data <- fread("raw_data.csv", sep = ";", header = TRUE, data.table = FALSE)

# Variable renaming
raw_data <- raw_data %>% rename(!!!as.list(variables))

# Convert European decimal comma to dot and cast to numeric where needed
for (col in names(raw_data)) {
  if (is.character(raw_data[[col]])) {
    raw_data[[col]] <- suppressWarnings(as.numeric(gsub(",", ".", raw_data[[col]])))
  }
}

# Replace infinite placeholders (-99.99) with NA
raw_data[raw_data == -99.99] <- NA

# -----------------------------
# Sorting and Train/Test split (even/odd rows) by "Financial Distress" and "Income/Assets"
ord <- order(raw_data[["Financial Distress"]], raw_data[["Income/Assets"]], decreasing = FALSE)
sorted <- raw_data[ord, , drop = FALSE]
df_train <- sorted[seq(1, nrow(sorted), by = 2), , drop = FALSE]
df_test  <- sorted[seq(2, nrow(sorted), by = 2), , drop = FALSE]

# -----------------------------
# Datasets partitioning (dependent y & independent X)
y_train <- df_train[["Financial Distress"]]
y_test  <- df_test[["Financial Distress"]]

X_train <- df_train %>% select(-`Financial Distress`)
X_test  <- df_test %>% select(-`Financial Distress`)

cat(sprintf("Training sample of X: (%d,%d), Testing sample of X: (%d,%d), Training sample of y: (%d), Testing sample of y: (%d)\n",
            nrow(X_train), ncol(X_train), nrow(X_test), ncol(X_test), length(y_train), length(y_test)))

# -----------------------------
# Descriptive statistics for X_train with skewness and kurtosis
desc_stats <- function(df) {
  out <- data.frame(
    count = sapply(df, function(x) sum(!is.na(x))),
    mean = sapply(df, function(x) mean(x, na.rm = TRUE)),
    sd   = sapply(df, function(x) sd(x, na.rm = TRUE)),
    min  = sapply(df, function(x) min(x, na.rm = TRUE)),
    `25%`= sapply(df, function(x) quantile(x, 0.25, na.rm = TRUE)),
    `50%`= sapply(df, function(x) quantile(x, 0.50, na.rm = TRUE)),
    `75%`= sapply(df, function(x) quantile(x, 0.75, na.rm = TRUE)),
    max  = sapply(df, function(x) max(x, na.rm = TRUE)),
    skewness = sapply(df, function(x) moments::skewness(x, na.rm = TRUE)),
    kurtosis = sapply(df, function(x) moments::kurtosis(x, na.rm = TRUE))
  )
  out <- out %>% mutate(variable = rownames(.)) %>% select(variable, everything())
  rownames(out) <- NULL
  out
}
X_train_desc <- desc_stats(X_train)

# -----------------------------
# Distribution plots with KDE and Normal PDF overlay
plot_list <- list()
num_vars <- ncol(X_train)
for (i in seq_len(num_vars)) {
  col_name <- names(X_train)[i]
  d <- data.frame(value = X_train[[col_name]])
  d <- d %>% filter(!is.na(value))
  if (nrow(d) == 0) next
  mu <- mean(d$value)
  s  <- sd(d$value)
  if (!is.finite(s) || s == 0) s <- 1e-8
  xseq <- seq(min(d$value), max(d$value), length.out = 200)
  norm_df <- data.frame(x = xseq, d = dnorm(xseq, mean = mu, sd = s))
  p <- ggplot(d, aes(x = value)) +
    geom_histogram(aes(y = after_stat(density)), bins = 30, alpha = 0.5) +
    geom_density() +
    geom_line(data = norm_df, aes(x = x, y = d), linetype = "dashed") +
    labs(title = paste0("Distribution of ", col_name), x = col_name, y = "Density")
  plot_list[[length(plot_list) + 1]] <- p
}
# Arrange in pages to avoid overcrowding
if (length(plot_list) > 0) {
  n_per_page <- 8
  for (start in seq(1, length(plot_list), by = n_per_page)) {
    end <- min(start + n_per_page - 1, length(plot_list))
    print(ggpubr::ggarrange(plotlist = plot_list[start:end], ncol = 2, nrow = ceiling((end - start + 1) / 2), top = "Figure 1"))
  }
}

# -----------------------------
# Extreme observations analysis (>= 90th percentile in >=5 variables)
q90 <- sapply(X_train, function(x) quantile(x, 0.90, na.rm = TRUE))
mask <- mapply(function(col, thr) col >= thr, X_train, q90, SIMPLIFY = FALSE)
mask_df <- as.data.frame(mask)
extreme_count <- rowSums(mask_df, na.rm = TRUE)
X_train_extreme <- X_train[extreme_count >= 5, , drop = FALSE]
if (nrow(X_train_extreme) > 0) {
  X_train_extreme <- cbind(`Number of Critical Variables` = extreme_count[extreme_count >= 5], X_train_extreme)
}

# Non-highly affected firms
X_train_cleaned_extreme <- X_train[extreme_count < 5, , drop = FALSE]
X_train_cleaned_extreme_desc <- desc_stats(X_train_cleaned_extreme)

# Improvement metrics
X_average_stats_improvement <- data.frame(
  `Train Sample Abs Skewness Differential` = abs(sapply(X_train, function(x) moments::skewness(x, na.rm = TRUE)) - 0),
  `Cleaned Train Sample Abs Skewness Differential` = abs(sapply(X_train_cleaned_extreme, function(x) moments::skewness(x, na.rm = TRUE)) - 0),
  `Train Sample Abs Kurtosis Differential` = abs(sapply(X_train, function(x) moments::kurtosis(x, na.rm = TRUE)) - 3),
  `Cleaned Train Sample Abs Kurtosis Differential` = abs(sapply(X_train_cleaned_extreme, function(x) moments::kurtosis(x, na.rm = TRUE)) - 3)
)
cat(sprintf("Average Train Sample Abs Skewness Differential: %.6f, Average Cleaned Train Sample Abs Skewness Differential: %.6f\nAverage Train Sample Abs Kurtosis Differential: %.6f, Average Cleaned Train Sample Abs Kurtosis Differential: %.6f\nAverage Skewness Change (%%): %.2f\nAverage Kurtosis Change (%%): %.2f\n",
            mean(X_average_stats_improvement$`Train Sample Abs Skewness Differential`, na.rm = TRUE),
            mean(X_average_stats_improvement$`Cleaned Train Sample Abs Skewness Differential`, na.rm = TRUE),
            mean(X_average_stats_improvement$`Train Sample Abs Kurtosis Differential`, na.rm = TRUE),
            mean(X_average_stats_improvement$`Cleaned Train Sample Abs Kurtosis Differential`, na.rm = TRUE),
            (mean(X_average_stats_improvement$`Train Sample Abs Skewness Differential`, na.rm = TRUE) - mean(X_average_stats_improvement$`Cleaned Train Sample Abs Skewness Differential`, na.rm = TRUE)) /
              mean(X_average_stats_improvement$`Train Sample Abs Skewness Differential`, na.rm = TRUE) * 100,
            (mean(X_average_stats_improvement$`Train Sample Abs Kurtosis Differential`, na.rm = TRUE) - mean(X_average_stats_improvement$`Cleaned Train Sample Abs Kurtosis Differential`, na.rm = TRUE)) /
              mean(X_average_stats_improvement$`Train Sample Abs Kurtosis Differential`, na.rm = TRUE) * 100))

# -----------------------------
# Adjusted distributions (10th-90th percentiles)
adj_X_train <- X_train
for (var in names(X_train)) {
  lower <- quantile(X_train[[var]], 0.10, na.rm = TRUE)
  upper <- quantile(X_train[[var]], 0.90, na.rm = TRUE)
  adj_X_train[[var]][adj_X_train[[var]] < lower | adj_X_train[[var]] > upper] <- NA
}

plot_list2 <- list()
for (i in seq_len(ncol(adj_X_train))) {
  col_name <- names(adj_X_train)[i]
  d <- data.frame(value = adj_X_train[[col_name]])
  d <- d %>% filter(!is.na(value))
  if (nrow(d) == 0) next
  mu <- mean(d$value)
  s  <- sd(d$value)
  if (!is.finite(s) || s == 0) s <- 1e-8
  xseq <- seq(min(d$value), max(d$value), length.out = 200)
  norm_df <- data.frame(x = xseq, d = dnorm(xseq, mean = mu, sd = s))
  p <- ggplot(d, aes(x = value)) +
    geom_density(alpha = 0.7) +
    geom_line(data = norm_df, aes(x = x, y = d), linetype = "dashed") +
    labs(title = paste0("Distribution of Adjusted ", col_name), x = col_name, y = "Density")
  plot_list2[[length(plot_list2) + 1]] <- p
}
if (length(plot_list2) > 0) {
  n_per_page <- 8
  for (start in seq(1, length(plot_list2), by = n_per_page)) {
    end <- min(start + n_per_page - 1, length(plot_list2))
    print(ggpubr::ggarrange(plotlist = plot_list2[start:end], ncol = 2, nrow = ceiling((end - start + 1) / 2), top = "Figure 2"))
  }
}

# -----------------------------
# Distress vs Non-Distress distributions
df_train_distress <- df_train %>% filter(`Financial Distress` == 1)
df_train_nondistress <- df_train %>% filter(`Financial Distress` == 0)

plot_list3 <- list()
for (col_name in names(X_train)) {
  d1 <- data.frame(value = df_train_distress[[col_name]])
  d2 <- data.frame(value = df_train_nondistress[[col_name]])
  d1 <- d1 %>% filter(!is.na(value)); d2 <- d2 %>% filter(!is.na(value))
  if (nrow(d1) == 0 && nrow(d2) == 0) next
  p <- ggplot() +
    geom_density(data = d1, aes(x = value), alpha = 0.4, fill = "red") +
    geom_density(data = d2, aes(x = value), alpha = 0.4, fill = "green") +
    labs(title = paste0("Distribution of ", col_name), x = col_name, y = "Density")
  plot_list3[[length(plot_list3) + 1]] <- p
}
if (length(plot_list3) > 0) {
  n_per_page <- 8
  for (start in seq(1, length(plot_list3), by = n_per_page)) {
    end <- min(start + n_per_page - 1, length(plot_list3))
    print(ggpubr::ggarrange(plotlist = plot_list3[start:end], ncol = 2, nrow = ceiling((end - start + 1) / 2), top = "Figure 3"))
  }
}

# -----------------------------
# Boxplots (all X)
std_values <- sapply(df_train, function(x) sd(x, na.rm = TRUE))
sorted_vars <- names(sort(std_values, decreasing = FALSE))
X_names_all <- setdiff(sorted_vars, "Financial Distress")

p_box_nfd <- ggplot(melt(df_train_nondistress[, X_names_all, drop = FALSE]), aes(x = variable, y = value)) +
  geom_boxplot() + labs(title = "Box Plot for X, No Financial Distress") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
p_box_fd <- ggplot(melt(df_train_distress[, X_names_all, drop = FALSE]), aes(x = variable, y = value)) +
  geom_boxplot() + labs(title = "Box Plot for X, Financial Distress") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
print(ggpubr::ggarrange(p_box_nfd, p_box_fd, ncol = 1, nrow = 2, top = "Figure 4"))

# Boxplots excluding high-range variables
exclude_vars <- c("Financial Distress", "Log Sales", "Log Assets", "Long-Term Debt/Total Assets", "Current Assets/Liabilities", "Quick Assets/Liabilities")
X_names_sel <- setdiff(sorted_vars, exclude_vars)
p_box_nfd2 <- ggplot(melt(df_train_nondistress[, X_names_sel, drop = FALSE]), aes(x = variable, y = value)) +
  geom_boxplot() + labs(title = "Box Plot (Selected X), No Financial Distress") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
p_box_fd2 <- ggplot(melt(df_train_distress[, X_names_sel, drop = FALSE]), aes(x = variable, y = value)) +
  geom_boxplot() + labs(title = "Box Plot (Selected X), Financial Distress") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
print(ggpubr::ggarrange(p_box_nfd2, p_box_fd2, ncol = 1, nrow = 2, top = "Figure 5"))

# Violin plots (selected)
p_violin_nfd <- ggplot(melt(df_train_nondistress[, X_names_sel, drop = FALSE]), aes(x = variable, y = value)) +
  geom_violin() + labs(title = "Violin Plot (Selected X), No Financial Distress") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
p_violin_fd <- ggplot(melt(df_train_distress[, X_names_sel, drop = FALSE]), aes(x = variable, y = value)) +
  geom_violin() + labs(title = "Violin Plot (Selected X), Financial Distress") + theme(axis.text.x = element_text(angle = 90, hjust = 1))
print(ggpubr::ggarrange(p_violin_nfd, p_violin_fd, ncol = 1, nrow = 2, top = "Figure 6"))

# -----------------------------
# Pairplot-like (selected variables)
Xy <- names(df_train)[!(names(df_train) %in% c("Inventory/Sales","Net Working Capital/Assets","Long-Term Debt/Total Assets","Log Sales","Log Assets","Fixed Assets/Total Assets","Quick Assets/Liabilities","Employment Growth"))]
if (length(Xy) > 1) {
  print(GGally::ggpairs(df_train[, Xy, drop = FALSE], columns = seq_along(Xy), title = "Figure 7 Scatter Plot for Selected Variables"))
}

# -----------------------------
# Correlation heatmap with t-stats (lower triangle)
df_train_short <- df_train
names(df_train_short) <- ifelse(names(df_train_short) %in% names(inverted_variables),
                                inverted_variables[names(df_train_short)],
                                names(df_train_short))
corr_matrix <- cor(df_train_short, use = "pairwise.complete.obs")
n <- nrow(df_train_short)
t_stat_matrix <- corr_matrix * sqrt((n - 2) / (1 - corr_matrix^2))
diag_idx <- upper.tri(corr_matrix)
annot_matrix <- matrix("", nrow = ncol(corr_matrix), ncol = ncol(corr_matrix))
for (i in seq_len(ncol(corr_matrix))) {
  for (j in seq_len(ncol(corr_matrix))) {
    if (i >= j) {
      annot_matrix[i, j] <- sprintf("%.2f\n(%.2f)", corr_matrix[i, j], t_stat_matrix[i, j])
    }
  }
}
corrplot::corrplot(corr_matrix, method = "color", type = "lower", tl.col = "black", tl.srt = 45, addCoef.col = NA,
                   title = "Figure 8 Variables Correlation Matrix - Heatmap\n(r-value with t-statistics in parentheses)")

# -----------------------------
# Normality Test (Jarque Bera) for Aggregate, No Distress, Distress
target_variables <- setdiff(names(df_train), "Financial Distress")
df_train_jarque_bera <- data.frame()
for (v in target_variables) {
  x_all <- df_train[[v]]
  x_nfd <- df_train_nondistress[[v]]
  x_fd  <- df_train_distress[[v]]
  jb_all <- tryCatch(tseries::jarque.bera.test(x_all), error = function(e) list(statistic = NA, p.value = NA))
  jb_nfd <- tryCatch(tseries::jarque.bera.test(x_nfd), error = function(e) list(statistic = NA, p.value = NA))
  jb_fd  <- tryCatch(tseries::jarque.bera.test(x_fd),  error = function(e) list(statistic = NA, p.value = NA))
  df_train_jarque_bera <- rbind(df_train_jarque_bera, data.frame(
    variable = v,
    `AGGREGATE - Jarque Bera Stat` = as.numeric(jb_all$statistic),
    `AGGREGATE - p-value` = as.numeric(jb_all$p.value),
    `AGGREGATE - Statistical Significance` = significance_stars(as.numeric(jb_all$p.value)),
    `NO DISTRESS - Jarque Bera Stat` = as.numeric(jb_nfd$statistic),
    `NO DISTRESS - p-value` = as.numeric(jb_nfd$p.value),
    `NO DISTRESS - Statistical Significance` = significance_stars(as.numeric(jb_nfd$p.value)),
    `DISTRESS - Jarque Bera Stat` = as.numeric(jb_fd$statistic),
    `DISTRESS - p-value` = as.numeric(jb_fd$p.value),
    `DISTRESS - Statistical Significance` = significance_stars(as.numeric(jb_fd$p.value))
  ))
}
row.names(df_train_jarque_bera) <- df_train_jarque_bera$variable
df_train_jarque_bera$variable <- NULL
cat("Train Dataset - Jarque Bera Test of Normality for Aggregate and Sub-Cluster Data\n")
print(head(df_train_jarque_bera))

# -----------------------------
# Levene Test (variance equality): ALL (3 groups) and NFD-FD (2 groups)
df_train_levene <- data.frame()
for (v in target_variables) {
  # ALL groups
  df_tmp <- rbind(
    data.frame(value = df_train[[v]], group = "ALL"),
    data.frame(value = df_train_nondistress[[v]], group = "NFD"),
    data.frame(value = df_train_distress[[v]], group = "FD")
  )
  df_tmp <- df_tmp %>% filter(!is.na(value) & !is.na(group))
  all_test <- tryCatch(car::leveneTest(value ~ group, data = df_tmp, center = median), error = function(e) NULL)
  all_stat <- if (!is.null(all_test)) all_test$`F value`[1] else NA
  all_p    <- if (!is.null(all_test)) all_test$`Pr(>F)`[1] else NA
  # NFD-FD only
  df_nfdfd <- rbind(
    data.frame(value = df_train_nondistress[[v]], group = "NFD"),
    data.frame(value = df_train_distress[[v]], group = "FD")
  ) %>% filter(!is.na(value))
  nfdfd_test <- tryCatch(car::leveneTest(value ~ group, data = df_nfdfd, center = median), error = function(e) NULL)
  nfdfd_stat <- if (!is.null(nfdfd_test)) nfdfd_test$`F value`[1] else NA
  nfdfd_p    <- if (!is.null(nfdfd_test)) nfdfd_test$`Pr(>F)`[1] else NA

  df_train_levene <- rbind(df_train_levene, data.frame(
    variable = v,
    `ALL Levene Stat (groups = Aggregate, NO Financial Distress, Financial Distress)` = all_stat,
    `ALL p-value` = all_p,
    `ALL Statistical Significance` = significance_stars(all_p),
    `NFD-FD Levene Stat (groups =  NO Financial Distress, Financial Distress)` = nfdfd_stat,
    `NFD-FD p-value` = nfdfd_p,
    `NFD-FD Statistical Significance` = significance_stars(nfdfd_p)
  ))
}
row.names(df_train_levene) <- df_train_levene$variable
df_train_levene$variable <- NULL
cat("Train Dataset - Levene Test of Equality of Variance (Aggregate, NO Financial Distress, Financial Distress clusters)\n")
print(head(df_train_levene))

# -----------------------------
# Kolmogorov-Smirnov Tests (NFD vs FD) and (Aggregate vs Normal)
df_train_ks <- data.frame()
for (v in target_variables) {
  x_nfd <- df_train_nondistress[[v]]
  x_fd  <- df_train_distress[[v]]
  x_all <- df_train[[v]]
  x_nfd <- x_nfd[!is.na(x_nfd)]
  x_fd  <- x_fd[!is.na(x_fd)]
  x_all <- x_all[!is.na(x_all)]
  nfdfd <- tryCatch(ks.test(x_nfd, x_fd), error = function(e) list(statistic = NA, p.value = NA))
  mu <- mean(x_all, na.rm = TRUE); s <- sd(x_all, na.rm = TRUE); if (!is.finite(s) || s == 0) s <- 1e-8
  aggnorm <- tryCatch(ks.test(x_all, "pnorm", mean = mu, sd = s), error = function(e) list(statistic = NA, p.value = NA))
  df_train_ks <- rbind(df_train_ks, data.frame(
    variable = v,
    `NFD-FD KS Stat (groups =  NO Financial Distress, Financial Distress)` = as.numeric(nfdfd$statistic),
    `NFD-FD p-value` = as.numeric(nfdfd$p.value),
    `NFD-FD Statistical Significance` = significance_stars(as.numeric(nfdfd$p.value)),
    `AGG-NORM KS Stat (groups =  Aggregate, Normal PDF)` = as.numeric(aggnorm$statistic),
    `AGG-NORM p-value` = as.numeric(aggnorm$p.value),
    `AGG-NORM Statistical Significance` = significance_stars(as.numeric(aggnorm$p.value))
  ))
}
row.names(df_train_ks) <- df_train_ks$variable
df_train_ks$variable <- NULL
cat("Train Dataset - Kolmogorov-Smirnov Tests\n")
print(head(df_train_ks))

# -----------------------------
# Pearson r (between each X and y)
df_train_no_nan <- df_train %>% drop_na()
df_train_r <- data.frame()
for (v in target_variables) {
  test <- tryCatch(cor.test(df_train_no_nan[[v]], df_train_no_nan$`Financial Distress`), error = function(e) NULL)
  r <- if (!is.null(test)) unname(test$estimate) else NA
  p <- if (!is.null(test)) test$p.value else NA
  df_train_r <- rbind(df_train_r, data.frame(
    variable = v,
    `Pearson r coefficient` = r,
    `p-value` = p,
    `Statistical Significance` = significance_stars(p)
  ))
}
row.names(df_train_r) <- df_train_r$variable
df_train_r$variable <- NULL
cat("Train Dataset - Pearson r Test (X vs Financial Distress)\n")
print(head(df_train_r))

# -----------------------------
# Two-sample t-test (NFD vs FD) for each variable
df_train_ttest <- data.frame()
for (v in target_variables) {
  x_nfd <- df_train_nondistress[[v]]
  x_fd  <- df_train_distress[[v]]
  tt <- tryCatch(t.test(x_nfd, x_fd, var.equal = FALSE), error = function(e) NULL)
  stat <- if (!is.null(tt)) unname(tt$statistic) else NA
  p    <- if (!is.null(tt)) tt$p.value else NA
  df_train_ttest <- rbind(df_train_ttest, data.frame(
    variable = v,
    `NFD-FD t-Stat (groups =  NO Financial Distress, Financial Distress)` = stat,
    `NFD-FD p-value` = p,
    `NFD-FD Statistical Significance` = significance_stars(p)
  ))
}
row.names(df_train_ttest) <- df_train_ttest$variable
df_train_ttest$variable <- NULL
cat("Train Dataset - Independent 2 Sample t-test\n")
print(head(df_train_ttest))

# -----------------------------
# One-way ANOVA via inverted regression (Xi ~ y)
df_train_ANOVA <- data.frame()
for (v in target_variables) {
  fit <- tryCatch(lm(df_train[[v]] ~ df_train$`Financial Distress`), error = function(e) NULL)
  if (!is.null(fit)) {
    s <- summary(fit)
    tstat <- s$coefficients[2, "t value"]
    pval  <- s$coefficients[2, "Pr(>|t|)"]
  } else {
    tstat <- NA; pval <- NA
  }
  df_train_ANOVA <- rbind(df_train_ANOVA, data.frame(
    variable = v,
    `ANOVA-derived t-Stat` = tstat,
    `p-value` = pval,
    `Statistical Significance` = significance_stars(pval)
  ))
}
row.names(df_train_ANOVA) <- df_train_ANOVA$variable
df_train_ANOVA$variable <- NULL
cat("Train Dataset - One-way ANOVA (ANOVA-derived t-stat, binary y)\n")
print(head(df_train_ANOVA))

# -----------------------------
# LPM, Logit, Probit (univariate: Debt/Assets)
df_train_reg1 <- df_train %>% drop_na()
y_reg1 <- df_train_reg1$`Financial Distress`
X1 <- df_train_reg1 %>% select(`Debt/Assets`)

lpm_model1 <- lm(y_reg1 ~ `Debt/Assets`, data = X1)
logit_model1 <- glm(y_reg1 ~ `Debt/Assets`, data = X1, family = binomial(link = "logit"))
probit_model1 <- glm(y_reg1 ~ `Debt/Assets`, data = X1, family = binomial(link = "probit"))

# Stargazer comparison
suppressWarnings(stargazer(lpm_model1, logit_model1, probit_model1, type = "text",
                           title = "Financial Distress - Univariate Models Comparison (Debt/Assets)",
                           column.labels = c("LPM", "Logit", "Probit"),
                           dep.var.labels = "Financial Distress",
                           add.lines = list(c("Model Type", "OLS", "Logit", "Probit")),
                           star.cutoffs = c(0.05, 0.01, 0.001),
                           df = FALSE))

# Alternative Single Comparison Table
get_coef <- function(model, name) coef(summary(model))[name, "Estimate"]
get_se   <- function(model, name) coef(summary(model))[name, "Std. Error"]
get_p    <- function(model, name) coef(summary(model))[name, "Pr(>|t|)"]

summary_table1 <- data.frame(
  Model = c("Linear Probability (LPM)", "Logit", "Probit"),
  Intercept = c(coef(lpm_model1)[1], coef(logit_model1)[1], coef(probit_model1)[1]),
  `Coefficient (Debt/Assets)` = c(coef(lpm_model1)["`Debt/Assets`"], coef(logit_model1)["`Debt/Assets`"], coef(probit_model1)["`Debt/Assets`"]),
  `Std. Error` = c(coef(summary(lpm_model1))["`Debt/Assets`", "Std. Error"],
                   coef(summary(logit_model1))["`Debt/Assets`", "Std. Error"],
                   coef(summary(probit_model1))["`Debt/Assets`", "Std. Error"]),
  `p-value` = c(coef(summary(lpm_model1))["`Debt/Assets`", "Pr(>|t|)"],
                coef(summary(logit_model1))["`Debt/Assets`", "Pr(>|z|)"],
                coef(summary(probit_model1))["`Debt/Assets`", "Pr(>|z|)"]),
  `R-squared / Pseudo R2` = c(summary(lpm_model1)$r.squared,
                              pscl::pR2(logit_model1)[["McFadden"]],
                              pscl::pR2(probit_model1)[["McFadden"]]),
  `Number of Observations` = c(nobs(lpm_model1), nobs(logit_model1), nobs(probit_model1))
)
summary_table1[, sapply(summary_table1, is.numeric)] <- lapply(summary_table1[, sapply(summary_table1, is.numeric)], function(x) round(x, 4))
print(tibble::as_tibble(t(summary_table1)))

# -----------------------------
# Concordant / Discordant / Tied pairs based on LPM score for Debt/Assets
df_train_conc <- df_train %>% drop_na()
score <- coef(lpm_model1)[1] + coef(lpm_model1)["`Debt/Assets`"] * df_train_conc$`Debt/Assets`
df_train_conc$score <- score
nfd <- df_train_conc %>% filter(`Financial Distress` == 0) %>% pull(score)
fd  <- df_train_conc %>% filter(`Financial Distress` == 1) %>% pull(score)

# Efficient pair counting
concordant <- sum(outer(fd, nfd, ">"))
discordant <- sum(outer(fd, nfd, "<"))
tied <- sum(outer(fd, nfd, "=="))
total_pairs <- concordant + discordant + tied
percentage_concordant <- ifelse(total_pairs > 0, concordant / total_pairs * 100, NA)
percentage_discordant <- ifelse(total_pairs > 0, discordant / total_pairs * 100, NA)
percentage_tied <- ifelse(total_pairs > 0, tied / total_pairs * 100, NA)

concordants_summary <- data.frame(
  Type = c("Concordant","Discordant","Tied"),
  Number = c(concordant, discordant, tied),
  Percentage = c(percentage_concordant, percentage_discordant, percentage_tied)
)
print(tibble::as_tibble(t(concordants_summary)))

# -----------------------------
# Multivariate models with selected variables
df_train_reg2 <- df_train %>% drop_na()
y_reg2 <- df_train_reg2$`Financial Distress`
X2 <- df_train_reg2 %>% select(`Debt/Assets`, `Income/Assets`, `Current Assets/Liabilities`, `Market Value Equity/Long-Term Debt`, `Inventory/Sales`)

lpm_model2 <- lm(y_reg2 ~ ., data = X2)
logit_model2 <- glm(y_reg2 ~ ., data = X2, family = binomial(link = "logit"))
probit_model2 <- glm(y_reg2 ~ ., data = X2, family = binomial(link = "probit"))

y_pred_lpm2 <- predict(lpm_model2, type = "response")
y_pred_logit2 <- predict(logit_model2, type = "response")
y_pred_probit2 <- predict(probit_model2, type = "response")

auc_lpm_model2 <- as.numeric(pROC::roc(y_reg2, y_pred_lpm2)$auc)
auc_logit_model2 <- as.numeric(pROC::roc(y_reg2, y_pred_logit2)$auc)
auc_probit_model2 <- as.numeric(pROC::roc(y_reg2, y_pred_probit2)$auc)

# Stargazer comparison
suppressWarnings(stargazer(lpm_model2, logit_model2, probit_model2, type = "text",
                           title = "Financial Distress - Model Comparison with Selected Target Variables",
                           column.labels = c("LPM", "Logit", "Probit"),
                           dep.var.labels = "Financial Distress",
                           add.lines = list(c("Model Type", "OLS", "Logit", "Probit")),
                           star.cutoffs = c(0.05, 0.01, 0.001),
                           df = FALSE))

# -----------------------------
# Actual vs Predicted plotting for Income/Assets (x-axis)
x_comp <- X2$`Income/Assets`
y_comp <- y_reg2
preds <- data.frame(
  model = rep(c("LPM","Logit","Probit"), each = length(y_comp)),
  x = rep(x_comp, 3),
  y = c(y_comp, y_comp, y_comp),
  yhat = c(y_pred_lpm2, y_pred_logit2, y_pred_probit2)
)
preds$model <- factor(preds$model, levels = c("LPM","Logit","Probit"))
p_scatter <- ggplot(preds, aes(x = x, y = y)) +
  geom_point(alpha = 0.5) +
  geom_point(aes(y = yhat), shape = 4) +
  facet_wrap(~ model) +
  labs(title = sprintf("Figure 10 - Model Predictions (training sample)\nAUC: LPM=%.3f, Logit=%.3f, Probit=%.3f",
                       auc_lpm_model2, auc_logit_model2, auc_probit_model2),
       x = "Income/Assets", y = "y (Binary)") +
  ylim(-0.1, 1.3) + theme_minimal()
print(p_scatter)

# Probability curves vs Income/Assets
x_range <- seq(min(X2$`Income/Assets`, na.rm = TRUE), max(X2$`Income/Assets`, na.rm = TRUE), length.out = 200)
X_pred <- as.data.frame(lapply(X2, function(col) rep(mean(col, na.rm = TRUE), length(x_range))))
X_pred$`Income/Assets` <- x_range

lpm_pred <- predict(lpm_model2, newdata = X_pred, type = "response")
logit_pred <- predict(logit_model2, newdata = X_pred, type = "response")
probit_pred <- predict(probit_model2, newdata = X_pred, type = "response")

curve_df <- data.frame(x = x_range, LPM = lpm_pred, Logit = logit_pred, Probit = probit_pred)
curve_long <- pivot_longer(curve_df, cols = c("LPM","Logit","Probit"), names_to = "Model", values_to = "Probability")
p_curves <- ggplot() +
  geom_point(data = data.frame(x = X2$`Income/Assets`, y = y_reg2, g = factor(y_reg2)), aes(x = x, y = y, shape = g), alpha = 0.4) +
  geom_line(data = curve_long, aes(x = x, y = Probability, linetype = Model)) +
  labs(title = "Figure 11 - Probability of Financial Distress with varying Income/Assets",
       x = "Income/Assets", y = "Probability of Financial Distress (yd)")
print(p_curves)

# -----------------------------
# Summary table 2 (coefficients + SE and stars, AUC, counts)
num_train_nfd <- sum(df_train_reg2$`Financial Distress` == 0, na.rm = TRUE)
num_train_fd  <- sum(df_train_reg2$`Financial Distress` == 1, na.rm = TRUE)

fmt_coef <- function(model, name) {
  se_name <- ifelse(inherits(model, "lm"), "Pr(>|t|)", "Pr(>|z|)")
  s <- summary(model)$coefficients
  if (!(name %in% rownames(s))) return(NA)
  est <- s[name, 1]; se <- s[name, 2]; p <- s[name, ncol(s)]
  sprintf("%.4f%s(%.4f)", est, significance_stars(p), se)
}

summary_table2 <- data.frame(
  Model = c("Linear Probability (LPM)", "Logit", "Probit"),
  Intercept = c(fmt_coef(lpm_model2, "(Intercept)"),
                fmt_coef(logit_model2, "(Intercept)"),
                fmt_coef(probit_model2, "(Intercept)")),
  `Debt/Assets` = c(fmt_coef(lpm_model2, "`Debt/Assets`"),
                    fmt_coef(logit_model2, "`Debt/Assets`"),
                    fmt_coef(probit_model2, "`Debt/Assets`")),
  `Income/Assets` = c(fmt_coef(lpm_model2, "`Income/Assets`"),
                      fmt_coef(logit_model2, "`Income/Assets`"),
                      fmt_coef(probit_model2, "`Income/Assets`")),
  `Current Assets/Liabilities` = c(fmt_coef(lpm_model2, "`Current Assets/Liabilities`"),
                                   fmt_coef(logit_model2, "`Current Assets/Liabilities`"),
                                   fmt_coef(probit_model2, "`Current Assets/Liabilities`")),
  `Market Value Equity/Long-Term Debt` = c(fmt_coef(lpm_model2, "`Market Value Equity/Long-Term Debt`"),
                                           fmt_coef(logit_model2, "`Market Value Equity/Long-Term Debt`"),
                                           fmt_coef(probit_model2, "`Market Value Equity/Long-Term Debt`")),
  `Inventory/Sales` = c(fmt_coef(lpm_model2, "`Inventory/Sales`"),
                        fmt_coef(logit_model2, "`Inventory/Sales`"),
                        fmt_coef(probit_model2, "`Inventory/Sales`")),
  `R-squared / Pseudo R2` = c(round(summary(lpm_model2)$r.squared, 4),
                              round(pscl::pR2(logit_model2)[["McFadden"]], 4),
                              round(pscl::pR2(probit_model2)[["McFadden"]], 4)),
  `AUC (training sample)` = c(round(auc_lpm_model2, 4), round(auc_logit_model2, 4), round(auc_probit_model2, 4)),
  `Number of NFD Observations` = c(num_train_nfd, num_train_nfd, num_train_nfd),
  `Number of FD Observations`  = c(num_train_fd, num_train_fd, num_train_fd)
)
print(tibble::as_tibble(t(summary_table2)))

# -----------------------------
# Variables combinations optimization for k in {2,3,4}
all_X_names <- names(X_train)
model_comparison_results <- data.frame()
for (k in c(2,3,4)) {
  cmb <- combn(all_X_names, k, simplify = FALSE)
  for (vars_combo in cmb) {
    X <- df_train_reg2 %>% select(all_of(vars_combo))
    fit <- tryCatch(lm(y_reg2 ~ ., data = X), error = function(e) NULL)
    if (is.null(fit)) next
    yhat <- predict(fit, type = "response")
    auc <- as.numeric(pROC::roc(y_reg2, yhat)$auc)
    r2  <- summary(fit)$r.squared
    model_comparison_results <- rbind(model_comparison_results, data.frame(
      Estimator = "LPM (OLS)",
      variables = paste(vars_combo, collapse = " + "),
      R2 = r2,
      AUC = auc,
      k = k
    ))
  }
}
summary_results_model_comparison <- model_comparison_results %>% group_by(k) %>% arrange(desc(AUC), desc(R2), .by_group = TRUE) %>% slice_head(n = 5) %>% ungroup()
print(summary_results_model_comparison)

# -----------------------------
# Out-of-sample testing
df_test_reg2 <- df_test %>% drop_na()
y_test_reg2 <- df_test_reg2$`Financial Distress`
X2_test <- df_test_reg2 %>% select(`Debt/Assets`, `Income/Assets`, `Current Assets/Liabilities`, `Market Value Equity/Long-Term Debt`, `Inventory/Sales`)

num_test_nfd <- sum(df_test_reg2$`Financial Distress` == 0, na.rm = TRUE)
num_test_fd  <- sum(df_test_reg2$`Financial Distress` == 1, na.rm = TRUE)

y_pred_lpm_model2_test <- predict(lpm_model2, newdata = X2_test, type = "response")
y_pred_logit_model2_test <- predict(logit_model2, newdata = X2_test, type = "response")
y_pred_probit_model2_test <- predict(probit_model2, newdata = X2_test, type = "response")

auc_lpm_model2_test_continuous <- as.numeric(pROC::roc(y_test_reg2, y_pred_lpm_model2_test)$auc)
auc_logit_model2_test_continuous <- as.numeric(pROC::roc(y_test_reg2, y_pred_logit_model2_test)$auc)
auc_probit_model2_test_continuous <- as.numeric(pROC::roc(y_test_reg2, y_pred_probit_model2_test)$auc)

auc_lpm_model2_test_binary <- as.numeric(pROC::roc(y_test_reg2, round(y_pred_lpm_model2_test))$auc)
auc_logit_model2_test_binary <- as.numeric(pROC::roc(y_test_reg2, round(y_pred_logit_model2_test))$auc)
auc_probit_model2_test_binary <- as.numeric(pROC::roc(y_test_reg2, round(y_pred_probit_model2_test))$auc)

model2_summary_pred_y <- data.frame(
  `LPM - Continuous` = y_pred_lpm_model2_test,
  `LPM - Binary` = round(y_pred_lpm_model2_test),
  `Logit - Continuous` = y_pred_logit_model2_test,
  `Logit - Binary` = round(y_pred_logit_model2_test),
  `Probit - Continuous` = y_pred_probit_model2_test,
  `Probit - Binary` = round(y_pred_probit_model2_test)
)
print(head(model2_summary_pred_y, 15))

summary_table2_test <- data.frame(
  Model = c("Linear Probability (LPM)", "Logit", "Probit"),
  `AUC (training sample)` = c(round(auc_lpm_model2, 4), round(auc_logit_model2, 4), round(auc_probit_model2, 4)),
  `AUC (testing sample, continuous)` = c(round(auc_lpm_model2_test_continuous, 4), round(auc_logit_model2_test_continuous, 4), round(auc_probit_model2_test_continuous, 4)),
  `AUC (testing sample, binary)` = c(round(auc_lpm_model2_test_binary, 4), round(auc_logit_model2_test_binary, 4), round(auc_probit_model2_test_binary, 4)),
  `Testing Sample Average` = c(round(mean(y_test_reg2), 4), round(mean(y_test_reg2), 4), round(mean(y_test_reg2), 4)),
  `Predicted Average (continuous)` = c(round(mean(y_pred_lpm_model2_test), 4), round(mean(y_pred_logit_model2_test), 4), round(mean(y_pred_probit_model2_test), 4)),
  `Predicted Average (binary)` = c(round(mean(round(y_pred_lpm_model2_test)), 4), round(mean(round(y_pred_logit_model2_test)), 4), round(mean(round(y_pred_probit_model2_test)), 4)),
  `Number of NFD Observations` = c(num_test_nfd, num_test_nfd, num_test_nfd)
)
print(tibble::as_tibble(t(summary_table2_test)))


# ---- Additional Cells: ROC plots, residual diagnostics, thresholds, and dummy trap ----

# ROC plotting for testing sample
roc_lpm_cont <- pROC::roc(y_test_reg2, y_pred_lpm_model2_test, quiet = TRUE)
roc_logit_cont <- pROC::roc(y_test_reg2, y_pred_logit_model2_test, quiet = TRUE)
roc_probit_cont <- pROC::roc(y_test_reg2, y_pred_probit_model2_test, quiet = TRUE)

roc_lpm_bin <- pROC::roc(y_test_reg2, round(y_pred_lpm_model2_test), quiet = TRUE)
roc_logit_bin <- pROC::roc(y_test_reg2, round(y_pred_logit_model2_test), quiet = TRUE)
roc_probit_bin <- pROC::roc(y_test_reg2, round(y_pred_probit_model2_test), quiet = TRUE)

df_roc <- bind_rows(
  data.frame(Model = "LPM", Type = "Continuous",
             FPR = 1 - roc_lpm_cont$specificities, TPR = roc_lpm_cont$sensitivities,
             AUC = as.numeric(auc_lpm_model2_test_continuous)),
  data.frame(Model = "Logit", Type = "Continuous",
             FPR = 1 - roc_logit_cont$specificities, TPR = roc_logit_cont$sensitivities,
             AUC = as.numeric(auc_logit_model2_test_continuous)),
  data.frame(Model = "Probit", Type = "Continuous",
             FPR = 1 - roc_probit_cont$specificities, TPR = roc_probit_cont$sensitivities,
             AUC = as.numeric(auc_probit_model2_test_continuous)),
  data.frame(Model = "LPM", Type = "Binary",
             FPR = 1 - roc_lpm_bin$specificities, TPR = roc_lpm_bin$sensitivities,
             AUC = as.numeric(auc_lpm_model2_test_binary)),
  data.frame(Model = "Logit", Type = "Binary",
             FPR = 1 - roc_logit_bin$specificities, TPR = roc_logit_bin$sensitivities,
             AUC = as.numeric(auc_logit_model2_test_binary)),
  data.frame(Model = "Probit", Type = "Binary",
             FPR = 1 - roc_probit_bin$specificities, TPR = roc_probit_bin$sensitivities,
             AUC = as.numeric(auc_probit_model2_test_binary))
)

p_roc <- ggplot(df_roc, aes(x = FPR, y = TPR, group = interaction(Model, Type))) +
  geom_line(aes(linetype = Type)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", alpha = 0.6) +
  facet_wrap(~ Model) +
  labs(title = "Figure 12 - ROC Curves for LPM, Logit, and Probit Models (out-of-sample)",
       x = "False Positive Rate", y = "True Positive Rate") +
  theme_minimal()
print(p_roc)

# Standardized Pearson Residuals (training sample)
# LPM
y_pred_lpm_tr <- predict(lpm_model2, type = "response")
pearson_lpm <- (y_reg2 - y_pred_lpm_tr) / sqrt(pmax(y_pred_lpm_tr * (1 - y_pred_lpm_tr), 1e-8))
h_lpm <- hatvalues(lpm_model2)
std_resid_lpm <- pearson_lpm / sqrt(pmax(1 - h_lpm, 1e-8))

# Logit
y_pred_logit_tr <- predict(logit_model2, type = "response")
pearson_logit <- residuals(logit_model2, type = "pearson")
h_logit <- hatvalues(logit_model2)
std_resid_logit <- pearson_logit / sqrt(pmax(1 - h_logit, 1e-8))

# Probit
y_pred_probit_tr <- predict(probit_model2, type = "response")
pearson_probit <- residuals(probit_model2, type = "pearson")
h_probit <- hatvalues(probit_model2)
std_resid_probit <- pearson_probit / sqrt(pmax(1 - h_probit, 1e-8))

mask_fd <- y_reg2 == 1
mask_nfd <- y_reg2 == 0

# Helper to plot KDEs with Normal PDF overlay
plot_resid_density <- function(std_resid, title_txt) {
  d <- data.frame(
    resid = std_resid,
    group = ifelse(mask_fd, "FD (y=1)", "NFD (y=0)")
  ) %>% filter(!is.na(resid))
  p <- ggplot(d, aes(x = resid, color = group, fill = group)) +
    geom_density(alpha = 0.3) +
    stat_function(fun = dnorm, linetype = "dashed") +
    labs(title = title_txt, x = "Standardized Pearson Residual", y = "Kernel Density") +
    theme_minimal()
  p
}

p_lpm_res <- plot_resid_density(std_resid_lpm, "Linear Probability (LPM)")
p_logit_res <- plot_resid_density(std_resid_logit, "Logit")
p_probit_res <- plot_resid_density(std_resid_probit, "Probit")
print(ggpubr::ggarrange(p_lpm_res, p_logit_res, p_probit_res, ncol = 3, nrow = 1, top = "Figure 13 - Distribution of Standardized Pearson Residuals by Firm Cluster (NFD & FD)"))

# Outliers threshold
outliers_threshold <- 2

# Outliers summary tables
build_outlier_table <- function(std_resid, y_vec) {
  idx <- which(abs(std_resid) > outliers_threshold)
  if (length(idx) == 0) return(data.frame())
  data.frame(
    `Residual` = std_resid[idx],
    `Side` = ifelse(std_resid[idx] > 0, "Positive extreme", "Negative extreme"),
    `Firm cluster` = ifelse(y_vec[idx] == 1, "FD (yd=1)", "NFD (yd=0)"),
    `Obs Index` = idx
  ) %>% tibble::column_to_rownames("Obs Index")
}

summary_table3_lpm_residuals <- build_outlier_table(std_resid_lpm, y_reg2)
summary_table3_logit_residuals <- build_outlier_table(std_resid_logit, y_reg2)
summary_table3_probit_residuals <- build_outlier_table(std_resid_probit, y_reg2)

print(head(summary_table3_lpm_residuals))
print(head(summary_table3_logit_residuals))
print(head(summary_table3_probit_residuals))

# Model preference simulation: best threshold minimizing expected loss
best_threshold <- function(real_y, pred_y, cost_FP, cost_FN, nfd_ratio, fd_ratio, model_name) {
  r <- pROC::roc(real_y, pred_y, quiet = TRUE)
  fpr <- 1 - r$specificities
  tpr <- r$sensitivities
  thr <- r$thresholds
  expected_loss <- cost_FP * fpr * nfd_ratio + cost_FN * (1 - tpr) * fd_ratio
  best_idx <- which.min(expected_loss)
  data.frame(
    Model = model_name,
    `Best Threshold` = thr[best_idx],
    `Minimum Expected Loss` = expected_loss[best_idx],
    `FPR at best` = fpr[best_idx],
    `TPR at best` = tpr[best_idx]
  )
}

cost_FP <- 0.1
cost_FN <- 0.2
nfd_ratio_test <- num_test_nfd / (num_test_nfd + num_test_fd)
fd_ratio_test <- 1 - nfd_ratio_test

threshold_lpm <- best_threshold(y_test_reg2, y_pred_lpm_model2_test, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Linear Probability (LPM)")
threshold_logit <- best_threshold(y_test_reg2, y_pred_logit_model2_test, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Logit")
threshold_probit <- best_threshold(y_test_reg2, y_pred_probit_model2_test, cost_FP, cost_FN, nfd_ratio_test, fd_ratio_test, "Probit")

summary_table4_thresholds <- bind_rows(threshold_lpm, threshold_logit, threshold_probit) %>% mutate(across(where(is.numeric), ~round(., 4)))
print(summary_table4_thresholds)

# Sensitivity and Specificity vs Probability Cutoff plots
plot_sens_spec <- function(real_y, pred_y, title_txt, line_color1, line_color2) {
  r <- pROC::roc(real_y, pred_y, quiet = TRUE)
  df <- data.frame(
    threshold = r$thresholds,
    sensitivity = r$sensitivities,
    specificity = r$specificities
  ) %>% arrange(threshold)
  ggplot(df, aes(x = threshold)) +
    geom_line(aes(y = sensitivity), linetype = "solid") +
    geom_line(aes(y = specificity), linetype = "dashed") +
    labs(title = title_txt, x = "Probability Cutoff", y = "Sensitivity/Specificity") +
    ylim(-0.05, 1.05) + theme_minimal()
}

print(plot_sens_spec(y_test_reg2, y_pred_lpm_model2_test, "Figure 14 - Sensitivity and Specificity vs Probability Cutoff (LPM)", "blue", "cornflowerblue"))
print(plot_sens_spec(y_test_reg2, y_pred_logit_model2_test, "Figure 15 - Sensitivity and Specificity vs Probability Cutoff (Logit)", "red", "coral"))
print(plot_sens_spec(y_test_reg2, y_pred_probit_model2_test, "Figure 16 - Sensitivity and Specificity vs Probability Cutoff (Probit)", "purple", "orchid"))

# Dummy Trap Analysis
tdta <- X_train$`Debt/Assets`
yd <- y_train
ynd <- 1 - yd

# MODEL 1: tdta ~ yd + ynd + intercept (multicollinearity expected)
Xtdta1 <- data.frame(yd = yd, ynd = ynd)
tdta_model1 <- tryCatch(lm(tdta ~ yd + ynd, data = Xtdta1), error = function(e) NULL)

# MODEL 2: tdta ~ yd + intercept
Xtdta2 <- data.frame(yd = yd)
tdta_model2 <- lm(tdta ~ yd, data = Xtdta2)

# MODEL 3: tdta ~ ynd + intercept
Xtdta3 <- data.frame(ynd = ynd)
tdta_model3 <- lm(tdta ~ ynd, data = Xtdta3)

# MODEL 4 (constrained: yd + ynd = 0) -> reparameterize as tdta ~ I(yd - ynd) with intercept
Xtdta4 <- data.frame(z = yd - ynd)
tdta_model4_constrained <- lm(tdta ~ z, data = Xtdta4)

# Stargazer comparison (text)
suppressWarnings(stargazer(tdta_model1, tdta_model2, tdta_model3, tdta_model4_constrained, type = "text",
                           title = "Debt-to-Assets Regression Results: Dummy Trap Comparison",
                           column.labels = c("Model 1: yd + ynd", "Model 2: yd", "Model 3: ynd", "Model 4: Restricted yd + ynd"),
                           dep.var.labels = "Debt/Assets",
                           add.lines = list(c("Model Type", "OLS", "OLS", "OLS", "OLS (Constraint via reparam)")),
                           star.cutoffs = c(0.05, 0.01, 0.001),
                           df = FALSE))
