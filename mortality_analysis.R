# =========================================================
# Mortality Experience Analysis and Statistical Modeling in R
# Project: Mortality Analysis with HMD Data (Canada, 1990-2020)
# Author: Jeff Xie
# =========================================================

# ----------------------------
# 1. Load Libraries
# ----------------------------
library(tidyverse)
library(viridis)

# ----------------------------
# 2. Set Working Directory
# Note: Change this path to your own project folder
# ----------------------------
setwd("C:/Users/user/OneDrive/Desktop/project/mortality_analysis_r")

# ----------------------------
# 3. Import Raw Data
# ----------------------------
# Exposure data (person-years)
exposure_raw <- read.table(
  "data/raw/Canada.Exposures_1x1.txt",
  skip = 2,
  header = TRUE
)

# Mortality rate data (mx)
mx_raw <- read.table(
  "data/raw/Canada.Mx_1x1.txt",
  skip = 2,
  header = TRUE
)

# ----------------------------
# 4. Data Cleaning
# ----------------------------
# Convert Age from character to numeric (some non-numeric values become NA)
exposure_raw <- exposure_raw %>%
  mutate(Age = as.numeric(Age))

mx_raw <- mx_raw %>%
  mutate(
    Age = as.numeric(Age),
    Female = as.numeric(Female),
    Male = as.numeric(Male),
    Total = as.numeric(Total)
  )

# ----------------------------
# 5. Reshape from Wide to Long Format
# ----------------------------
# Mortality rates: one row per (Year, Age, Sex) combination
mx_long <- mx_raw %>%
  pivot_longer(
    cols = c(Female, Male, Total),
    names_to = "sex",
    values_to = "mortality_rate"
  )

# Exposure data: one row per (Year, Age, Sex) combination
exposure_long <- exposure_raw %>%
  pivot_longer(
    cols = c(Female, Male, Total),
    names_to = "sex",
    values_to = "exposure"
  )

# ----------------------------
# 6. Merge Mortality and Exposure Data
# ----------------------------
mortality_data <- mx_long %>%
  inner_join(exposure_long, by = c("Year", "Age", "sex"))

# ----------------------------
# 7. Filter and Clean
# ----------------------------
mortality_data_clean <- mortality_data %>%
  # Exclude "Total" sex (keep only Male and Female)
  filter(sex != "Total") %>%
  # Focus on recent years with good data quality
  filter(Year >= 1990, Year <= 2020) %>%
  # Restrict to ages 0-100
  filter(Age >= 0, Age <= 100) %>%
  # Remove rows with missing values
  filter(!is.na(mortality_rate), !is.na(exposure), exposure > 0) %>%
  # Calculate deaths = mortality_rate * exposure
  mutate(deaths = mortality_rate * exposure) %>%
  # Rename columns to lowercase for consistency
  rename(year = Year, age = Age) %>%
  # Reorder columns
  select(year, age, sex, exposure, deaths, mortality_rate)

# ----------------------------
# 8. Create Age Group Variable (for aggregated plots)
# ----------------------------
mortality_data_clean <- mortality_data_clean %>%
  mutate(
    age_group = case_when(
      age < 1         ~ "0",
      age < 5         ~ "1-4",
      age < 15        ~ "5-14",
      age < 25        ~ "15-24",
      age < 35        ~ "25-34",
      age < 45        ~ "35-44",
      age < 55        ~ "45-54",
      age < 65        ~ "55-64",
      age < 75        ~ "65-74",
      age < 85        ~ "75-84",
      TRUE            ~ "85+"
    ),
    # Convert to ordered factor to ensure correct plotting order
    age_group = factor(
      age_group,
      levels = c("0", "1-4", "5-14", "15-24", "25-34", 
                 "35-44", "45-54", "55-64", "65-74", "75-84", "85+")
    )
  )

# ----------------------------
# 9. Save Cleaned Data
# ----------------------------
write_csv(mortality_data_clean, "data/mortality_data_clean.csv")
saveRDS(mortality_data_clean, "data/mortality_data_clean.rds")

# ----------------------------
# 10. Prepare 2010 Data for Visualization
# ----------------------------
# Aggregated by age (both sexes combined)
mortality_2010 <- mortality_data_clean %>%
  filter(year == 2010) %>%
  group_by(age) %>%
  summarise(
    deaths = sum(deaths),
    exposure = sum(exposure),
    mortality_rate = deaths / exposure
  )

# Aggregated by age and sex
mortality_2010_sex <- mortality_data_clean %>%
  filter(year == 2010) %>%
  group_by(age, sex) %>%
  summarise(
    deaths = sum(deaths),
    exposure = sum(exposure),
    mortality_rate = deaths / exposure
  )

# ----------------------------
# 11. Visualization: Plot 1-7
# ----------------------------

# --- Plot 1: Mortality Rate by Age (Line Chart) ---
# Question: How does mortality vary with age?
p1 <- ggplot(mortality_2010, aes(x = age, y = mortality_rate)) +
  geom_line(linewidth = 1.2, color = "steelblue") +
  scale_y_log10(labels = scales::label_number()) +
  labs(
    title = "Mortality Rate by Age (Canada, 2010)",
    x = "Age",
    y = "Mortality Rate (log scale)"
  ) +
  theme_minimal()
  print(p1)
ggsave("output/01_mortality_by_age.png", p1, width = 8, height = 5)

# --- Plot 2: Male vs Female Mortality (Grouped Line Chart) ---
# Question: How does mortality differ between males and females?
p2 <- ggplot(mortality_2010_sex, aes(x = age, y = mortality_rate, color = sex)) +
  geom_line(linewidth = 1.2) +
  scale_y_log10(labels = scales::label_number()) +
  scale_color_manual(values = c("Female" = "darkred", "Male" = "steelblue")) +
  labs(
    title = "Male vs Female Mortality Rate by Age (Canada, 2010)",
    x = "Age",
    y = "Mortality Rate (log scale)",
    color = "Sex"
  ) +
  theme_minimal()
  print(p2)
ggsave("output/02_male_vs_female.png", p2, width = 8, height = 5)

# --- Plot 3: Male-to-Female Mortality Ratio by Age Group (Bar Chart) ---
# Question: Which age groups show the largest gender gap?
mortality_ratio <- mortality_data_clean %>%
  filter(year == 2010) %>%
  group_by(age_group, sex) %>%
  summarise(
    mortality_rate = sum(deaths) / sum(exposure),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = sex, values_from = mortality_rate) %>%
  mutate(ratio = Male / Female)

p3 <- ggplot(mortality_ratio, aes(x = age_group, y = ratio)) +
  geom_col(fill = "darkgreen", alpha = 0.8) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  labs(
    title = "Male-to-Female Mortality Rate Ratio by Age Group (Canada, 2010)",
    x = "Age Group",
    y = "Male / Female Mortality Ratio"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
  print(p3)
ggsave("output/03_male_female_ratio.png", p3, width = 8, height = 5)

# --- Plot 4: Mortality Heatmap (Age × Year) ---
# Question: How do age and time interact to affect mortality?
mortality_heatmap <- mortality_data_clean %>%
  group_by(year, age) %>%
  summarise(
    mortality_rate = sum(deaths) / sum(exposure),
    .groups = "drop"
  ) %>%
  mutate(log_mortality = log(mortality_rate))

p4 <- ggplot(mortality_heatmap, aes(x = year, y = age, fill = log_mortality)) +
  geom_tile() +
  scale_fill_viridis_c(option = "plasma", name = "Log Mortality") +
  labs(
    title = "Mortality Rate Heatmap: Age × Year (Canada, 1990-2020)",
    x = "Year",
    y = "Age"
  ) +
  theme_minimal()
  print(p4)
ggsave("output/04_mortality_heatmap.png", p4, width = 10, height = 6)

# --- Plot 5: Annual Mortality Improvement Rate (Lollipop Chart) ---
# Question: Which age groups have seen the most mortality improvement?
mortality_improvement <- mortality_data_clean %>%
  group_by(age, year) %>%
  summarise(
    mortality_rate = sum(deaths) / sum(exposure),
    .groups = "drop"
  ) %>%
  group_by(age) %>%
  summarise(
    rate_1990 = mortality_rate[year == 1990],
    rate_2020 = mortality_rate[year == 2020],
    improvement_rate = (rate_1990 / rate_2020)^(1/30) - 1,
    .groups = "drop"
  ) %>%
  filter(!is.na(improvement_rate), is.finite(improvement_rate))

p5 <- ggplot(mortality_improvement, aes(x = age, y = improvement_rate)) +
  geom_segment(aes(xend = age, yend = 0), color = "grey70") +
  geom_point(size = 3, color = "steelblue") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Annual Mortality Improvement Rate by Age (Canada, 1990-2020)",
    x = "Age",
    y = "Annual Improvement Rate"
  ) +
  theme_minimal()
  print(p5)
ggsave("output/05_mortality_improvement.png", p5, width = 8, height = 5)

# --- Plot 6: Mortality Rate Distribution by Age Group (Boxplot) ---
# Question: How much does mortality vary across years within each age group?
mortality_box <- mortality_data_clean %>%
  group_by(age, year) %>%
  summarise(
    mortality_rate = sum(deaths) / sum(exposure),
    .groups = "drop"
  ) %>%
  mutate(
    age_group = case_when(
      age < 1 ~ "0",
      age < 5 ~ "1-4",
      age < 15 ~ "5-14",
      age < 25 ~ "15-24",
      age < 35 ~ "25-34",
      age < 45 ~ "35-44",
      age < 55 ~ "45-54",
      age < 65 ~ "55-64",
      age < 75 ~ "65-74",
      age < 85 ~ "75-84",
      TRUE ~ "85+"
    ),
    age_group = factor(age_group, levels = c("0", "1-4", "5-14", "15-24", "25-34", 
                                             "35-44", "45-54", "55-64", "65-74", "75-84", "85+"))
  )

p6 <- ggplot(mortality_box, aes(x = age_group, y = mortality_rate)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6) +
  scale_y_log10(labels = scales::label_number()) +
  labs(
    title = "Mortality Rate Distribution by Age Group (Canada, 1990-2020)",
    x = "Age Group",
    y = "Mortality Rate (log scale)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
  print(p6)
ggsave("output/06_mortality_boxplot.png", p6, width = 8, height = 5)

# --- Plot 7: Mortality Curves Over Time (Multi-Year Overlay) ---
# Question: Is the mortality curve shifting downward or rightward?
selected_years <- c(1990, 2000, 2010, 2020)

mortality_years <- mortality_data_clean %>%
  filter(year %in% selected_years) %>%
  group_by(year, age) %>%
  summarise(
    mortality_rate = sum(deaths) / sum(exposure),
    .groups = "drop"
  )

p7 <- ggplot(mortality_years, aes(x = age, y = mortality_rate, color = as.factor(year))) +
  geom_line(linewidth = 1.2) +
  scale_y_log10(labels = scales::label_number()) +
  scale_color_brewer(palette = "Blues", name = "Year") +
  labs(
    title = "Mortality Rate by Age: 1990 vs 2000 vs 2010 vs 2020",
    x = "Age",
    y = "Mortality Rate (log scale)"
  ) +
  theme_minimal()
  print(p7)
ggsave("output/07_multi_year_overlay.png", p7, width = 8, height = 5)

# ----------------------------
# 12. Statistical Modeling: Poisson GLM
# ----------------------------

# Prepare modeling data (2010 only)
model_data <- mortality_data_clean %>%
  filter(year == 2010) %>%
  group_by(age, sex) %>%
  summarise(
    deaths = sum(deaths),
    exposure = sum(exposure),
    .groups = "drop"
  )

# --- Model 1: Age + Sex (Linear) ---
# Formula: log(mortality) = beta0 + beta1*age + beta2*sex
model_1 <- glm(
  deaths ~ age + sex,
  offset = log(exposure),
  family = poisson(link = "log"),
  data = model_data
)
summary(model_1)

# --- Model 2: Age + Age^2 + Sex (Quadratic) ---
# Formula: log(mortality) = beta0 + beta1*age + beta2*age^2 + beta3*sex
# Age^2 term captures the accelerating mortality increase at older ages
model_2 <- glm(
  deaths ~ age + I(age^2) + sex,
  offset = log(exposure),
  family = poisson(link = "log"),
  data = model_data
)
summary(model_2)

# Compare models using AIC (lower = better)
AIC(model_1, model_2)

# ----------------------------
# 13. Model Evaluation: Plots 8-9
# ----------------------------

# Calculate predicted values and residuals
model_data <- model_data %>%
  mutate(
    predicted_deaths = predict(model_2, newdata = ., type = "response"),
    predicted_rate = predicted_deaths / exposure,
    observed_rate = deaths / exposure,
    residual = observed_rate - predicted_rate,
    error_pct = abs(observed_rate - predicted_rate) / observed_rate * 100
  )

# --- Plot 8: Observed vs Predicted (Model Fit Assessment) ---
# Question: Does the model capture the actual mortality trend?
p8 <- ggplot(model_data, aes(x = age)) +
  geom_line(aes(y = observed_rate, color = "Observed"), linewidth = 1.2) +
  geom_line(aes(y = predicted_rate, color = "Predicted"), linewidth = 1.2, linetype = "dashed") +
  scale_y_log10(labels = scales::label_number()) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("Observed" = "steelblue", "Predicted" = "darkred")) +
  labs(
    title = "Observed vs Predicted Mortality Rate by Age (Canada, 2010)",
    x = "Age",
    y = "Mortality Rate (log scale)",
    color = "Type"
  ) +
  theme_minimal()
  print(p8)
ggsave("output/08_observed_vs_predicted.png", p8, width = 10, height = 5)

# --- Plot 9: Prediction Error Percentage by Age ---
# Question: Which age groups does the model fit poorly?
p9 <- ggplot(model_data, aes(x = age, y = error_pct)) +
  geom_col(fill = "steelblue", alpha = 0.7) +
  facet_wrap(~sex) +
  labs(
    title = "Prediction Error Percentage by Age (Canada, 2010)",
    x = "Age",
    y = "Absolute Prediction Error (%)"
  ) +
  theme_minimal()
  print(p9)
ggsave("output/09_prediction_error.png", p9, width = 10, height = 5)

# ----------------------------
# 14. Done!
# ----------------------------
print("Project completed successfully! All 9 plots saved to output/ folder.")
