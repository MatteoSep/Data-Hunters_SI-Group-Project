dati_raw <- get_acs(
  geography = "state",
  variables = c(
    median_income = "B19013_001",
    poverty_rate   = "DP03_0128PE",
    insurance_rate = "DP03_0096PE",
    median_age = "B01002_001E"
  ),
  year   = anno_studio,
  survey = "acs1",
  output = "wide"
)

dataset_census <- dati_raw %>%
  select(
    GEOID,
    NAME,
    median_income = median_incomeE,
    poverty_rate,
    insurance_rate,
    median_age
  ) %>%
  mutate(
    poverty_per_100k   = poverty_rate * 1000,
    insurance_per_100k = insurance_rate * 1000
  ) %>%
  select(-poverty_rate, -insurance_rate)