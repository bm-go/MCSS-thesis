## ----setup, include=FALSE---------------------------------------------------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)


## ---------------------------------------------------------------------------------------------------------------------
library(haven)
library(tidyverse)
library(here)
library(survey)
library(countrycode)
library(conflicted)
library(glue)

# to prevent any tidy package issues
conflict_prefer("filter", "dplyr")
conflict_prefer("select", "dplyr")


## ---------------------------------------------------------------------------------------------------------------------
#ess_data <- haven::read_sav(here("Data/ESS_3.0_june_update/ESS_datafile_3.0.sav"))
ess_data <- haven::read_sav(here("Data/ESS_3.0_update/ESS_update_june2025.sav"))


glue("We have an ESS dataset with {nrow(ess_data)} rows and {ncol(ess_data)} variables.\n
     Data is spread over {length(unique(ess_data$essround))} rounds of the survey, from rounds {min(ess_data$essround)} to {max(ess_data$essround)}.")



## ---------------------------------------------------------------------------------------------------------------------
# first summarise all data and extract variables
ess_data <- ess_data |> 
  select(
    ## ID and weights
    essround,
    cntry,
    anweight,
    pspwght, 
    pweight,
    psu,
    stratum,
    
    # trust variables (and rename)
    trust_people = ppltrst, 
    trust_europ = trstep,
    trust_legal = trstlgl,
    trust_police = trstplc,
    trust_politicians = trstplt,
    trust_parliament = trstprl,
    trust_polparties = trstprt,
    trust_un = trstun,
    trust_scien = trstsci, 
    
    # some demographic variables
    gndr,  # Gender
    agea,  # Calculated age of respondent
    hhmmb, # Number of people living regularly as member of household

      # income + education
    eisced,  # Highest level of education of respondent
    pdwrk,  # In paid work
    hinctnta, # Household's total net income, all sources (reported in deciles)
    hincfel, # Feeling about household's income nowadays - financial stress
        
    # citizenship/ethnicity
    ctzcntr,  # Has UK citizenship (Yes/No)
    brncntr,  #Respondent born in the UK
    blgetmg, # Belong to minority ethnic group in country
    feethngr, # Feel part of same race or ethnic group as most people in country
       
     # location
    region, # region
    domicil, # type of area 5pt scale - A big city, Suburbs or outskirts, town or small city, village, countryside
       
     # health 
    happy, # How happy are you
    health, # Subjective general health
    hlthhmp, # Hampered in daily activities by illness/disability/infirmity/mental problem


    # political identifiers
    vote, # Voted last national election (Yes/No)
    prtvtbgb,  # Party voted for in last national election
    prtclbgb,  # Which party feel closer to, United Kingdom
    prtdgcl,  # How close does the repondent feel to the party party from 'prtclbgb'
    lrscale, # left right political scale 
    polintr, # level of political interest
    clsprty, # Feel closer to a particular party than all other parties
    euftf, # European Union: European unification go further or gone too far

    
    # satisfaction with life and country
    stflife, # How satisfied with life as a whole
    stfdem, # How satisfied with the way democracy works in country
    stfeco, # How satisfied with present state of economy in country
    stfgov, # How satisfied with the national government
    stfedu, # State of education in country nowadays
    stfhlth, # State of health services in country nowadays
    
    
      # additional variables from literature - R8 onwards only. 
        # media consumption - political specific? 
    netusoft, # internet use - R8 onwards only
    nwspol, # Newspaper reading, politics/current affairs on average weekday - R8 onwards
    pstplonl, # Posted or shared anything about politics online last 12 months

    # immigration
    imsmetn,  #Allow many/few immigrants of same race/ethnic group as majority
    imdfetn,  #Allow many/few immigrants of different race/ethnic group from majority
    impcntr,  #Allow many/few immigrants from poorer countries outside Europe
    imbgeco,  #Immigration bad or good for country's economy
    imueclt,  #Country's cultural life undermined or enriched by immigrants
    imwbcnt,  #Immigrants make country worse or better place to live
        
      # sense of 'britishness'/nationalism
    atchctr, # How emotionally attached to [country]
    atcherp, # How emotionally attached to Europe
  )

## add on full country name for visuals etc
ess_data <- ess_data |> 
  mutate(country_name = countrycode(sourcevar = cntry,
                                    origin = "iso2c",
                                    destination = "country.name"
                                    ), .after = cntry)



## ---------------------------------------------------------------------------------------------------------------------
ess_data |> 
  group_by(essround, cntry) |> 
  count() |> 
  pivot_wider(names_from = cntry, 
              values_from = n)



## ---------------------------------------------------------------------------------------------------------------------
# we see the analysis weight is not available in all rounds
ess_data |> group_by(essround) |> summarise(total_wts = sum(anweight))

# Create analysis weight manually
ess_data <- ess_data |> 
  mutate(anweight2 = pspwght * pweight * 10e3, .after=anweight)

# check the number of differences between manual and original - basically identical
ess_data |> 
  mutate(original = round(ess_data$anweight, 4),
         manual = round(ess_data$anweight2/10000, 4),
         diff_wt = ifelse(original != manual, 1,0)) |> 
  group_by(essround) |> 
  summarise(diffs = sum(diff_wt),
            total_resp = length(essround),
            prop_diff_wts = glue("{round(diffs/total_resp*100,4)}%"))


## ---------------------------------------------------------------------------------------------------------------------
ess_data |> 
  mutate(anweight = ifelse(essround %in% c(2,3), anweight2/10000, anweight)) |> 
  group_by(essround) |> summarise(total_wts = sum(anweight))


## ---------------------------------------------------------------------------------------------------------------------
ess_data <- ess_data |> 
  mutate(anweight = ifelse(essround %in% c(2,3), anweight2/10000, anweight)) |> 
  select(-anweight2)


## ---------------------------------------------------------------------------------------------------------------------

# Calculate grouped stats by round
data_by_country <- ess_data %>%
  group_by(country_name) %>%
  summarise(
    num_waves = length(unique(essround)),
    num_resp = n(),
    avg_resp = num_resp / num_waves
  )

# Iterate through the grouped results 
for (i in 1:nrow(data_by_country)) {
  current_group <- data_by_country[i, ]
  report <- glue(
    "--- Responses for {current_group$country_name}:\n",
        "\tRounds: {current_group$num_waves} & Average responses: {round(current_group$avg_resp)}")
  print(report)
  cat("\n")  #blank line
}
rm(current_group)


## ---------------------------------------------------------------------------------------------------------------------
# Calculate grouped stats by round
data_by_round <- ess_data %>%
  group_by(essround) %>%
  summarise(
    num_country = length(unique(cntry)),
    num_resp = n()
  )

# Iterate through the grouped results 
for (i in 1:nrow(data_by_round)) {
  current_group <- data_by_round[i, ]
  report <- glue(
    "--- Statistics for ESS round {current_group$essround} ---\n",
    "        - Number of countries: {current_group$num_country}\n",
    "        - Number of responses: {current_group$num_resp}")
  print(report)
  cat("\n")  #blank line
}

rm(current_group)

