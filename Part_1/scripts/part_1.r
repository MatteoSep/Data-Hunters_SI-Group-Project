rm(list=ls())

install.packages("tidycensus")
install.packages("tidyverse")
library(tidycensus)
library(tidyverse)

census_api_key("API_KEY", install=TRUE, overwrite = TRUE)
readRenviron("~/.Renviron")
options(timeout = 300) # Imposta il timeout a 5 minuti

anno_studio <- 2019


dati_raw <- get_acs(
  geography = "state",
  variables = c(median_income = "B19013_001",
                poverty_rate   = "DP03_0128PE",
                insurance_rate = "DP03_0096PE",
                median_age = "B01002_001E"),
  year      = anno_studio,
  survey    = "acs1",
  output    = "wide",
)

dataset_census <- dati_raw %>%
  select(
    GEOID,
    NAME,
    median_income  = median_incomeE,
    poverty_rate,
    insurance_rate,
    median_age
  )%>%
  mutate(  poverty_per_100k   = poverty_rate * 1000,
    insurance_per_100k = insurance_rate * 1000
  ) %>%
  # Rimuoviamo i vecchi tassi in percentuale per non confonderci durante la regressione
  select(-poverty_rate, -insurance_rate)

head(dataset_census)

library(readr)
cause_mortality<- read_csv("data/data_1/raw/Cause_of_Death.csv")

allcause_mortality_per_100k <- cause_mortality[, -c(1, 3, 4, 5)]
allcause_mortality_per_100k <- allcause_mortality_per_100k %>%
  rename(crude_rate_mortality = 2, age_adjusted_mortality=3)

medical_cause_per_100k<-read_csv("data/data_1/raw/medical_cause_of_death.csv")[, -c(1, 3, 4, 5)]
medical_cause_per_100k<- medical_cause_per_100k%>%
  rename(crude_rate_medical_mortality = 2, age_adjusted_medical_mortality=3)

dataset_finale <- dataset_census %>%
  inner_join(
    allcause_mortality_per_100k, 
    by = c("NAME" = "State")
  ) %>%
  inner_join(
    medical_cause_per_100k, 
    by = c("NAME" = "State") 
  )

head(dataset_finale)

# Contiamo quanti stati hanno combaciato (dovrebbero essere 50 o 51 se c'è DC)
print(paste("Numero di stati uniti con successo:", nrow(dataset_finale)))

Sys.info()["user"]
write_csv(dataset_finale, "data/data_1/processed/mio_dataset_output.csv")

