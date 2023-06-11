# Script for conducting exploratory data anaysis (EDA) for predictor variables 
# in wetland carbon modeling project
# Jenny Hansen
# May 25 2023

# working in the Wetland_Carbon_Mod project
# rm(list = ls())

# Load required libraries -------------------------------------------------
library(here)
library(readr)
library(dplyr)
library(ggplot2)
library(sf)
library(DataExplorer)
library(performance)
library(dotenv) # loading secure variables from .env file

# Check operating system --------------------------------------------------
sys_info <- Sys.info()[c("sysname", "release", "version")]
sys_name <- Sys.info()["sysname"]

if (sys_name == "Linux") {
  # print system and use info 
  cat("OS:", sys_info, "\n")
  user_dir <- Sys.getenv("HOME") 
  cat("user_dir: ", user_dir, "\n")

  # load secure variables from .env file
  load_dot_env(file.path(user_dir, ".env"))
  OS = Sys.getenv("LINUX")


} else if (sys_name == "Windows") {
  # print system and use info 
  cat("OS:", sys_info, "\n")
  user_dir <- Sys.getenv("USERPROFILE") 
  cat("user_dir: ", user_dir, "\n")

  # load secure variables from .env file
  load_dot_env(file.path(user_dir, ".env"))
  OS = Sys.getenv("WINDOWS")

} else {
  cat("OS:", sys_info, "\n")
}


# Project variables -------------------------------------------------------
project_root <- here()
project_data <- file.path(OS, Sys.getenv("WETLAND_PATH"))
cat("Local GIT location:", project_root, "\n")
cat("Local data location: ", project_data, "\n")

path_raw <- file.path(project_data, "data", "raw")
path_interim <- file.path(project_data, "data", "interim")



# Import data -------------------------------------------------------------

# predictor variables for terrain & worldclim came from the GEE script here:
# https://code.earthengine.google.com/6c09a62aab4645bfcd73ccf196868897
path_env_vars <- file.path(path_interim, "predictors_terrain_climate.csv")
env_vars <- read_csv(path_env_vars) %>%
  select(-c(`system:index`, assigned, in_tact, notes, `.geo`)) %>%
  filter(!duplicated(name))

# mire spatial data was generated in the previous r script:
# prepare_responseVar.R

path_mires <- file.path(path_interim, "vector", "assigned_mire_data_terrain.shp")
mires <- st_read(path_mires) %>%
  filter(!duplicated(name))


# Join response variables with predictor variables ------------------------
# TODO - clean csv files and upload to R 
# join env_vars with mires
env_sf <- mires %>% 
  select(-c(assigned, in_tact, notes)) %>% 
  left_join(env_vars)

# full dataset without spatial data

env_all <- env_sf %>% 
  st_drop_geometry()



# Exploratory data analysis -----------------------------------------------

# look for missing data & visualize data distribution

#plot_missing(env_all)
plot_missing(mires)

# missing half of the values for avg_pd

plot_bar(env_all)

# very skewed with a few dominant types

plot_histogram(env_all)

# some obvious outliers apparent in the histograms


plot_correlation(na.omit(env_all), type = "c")

# as suspected, many of the predictors are highly correlated

# see if there are any obvious gradients

pca_pred <- na.omit(env_all[ , c("aspect", "elevation", "elevation_max",        
                                "elevation_min", "isothermality",
                                "rain_coldestQuart", "rain_driestMonth",
                                "rain_driestQuart", "rain_mean_annual",     
                                "rain_seasonailty", "rain_warmestQuart",
                                "rain_wettestMonth", "rain_wettestQuart",    
                                "slope", "temp_annual_range", "temp_coldestQuart",
                                "temp_diurnal_range", "temp_driestQuart",
                                "temp_max_warmestMonth", "temp_mean_annual",
                                "temp_min_coldestMonth", "temp_seasonality",
                                "temp_warmestQuart", "temp_wettestQuart")])
plot_prcomp(pca_pred)

pca_resp <- na.omit(env_all[ ,c("avg_ash", "avg_cao", "avg_n", "avg_dsw")])
plot_prcomp(pca_resp)




# Outlier detection -------------------------------------------------------

# avg_ash (has obvious outliers to remove)

boxplot(env_all$avg_ash)
plot(env_all$avg_ash)
quantile(env_all$avg_ash, 0.025) # 1.898
quantile(env_all$avg_ash, 0.975) # 37.249


# avg_cao (also some outliers)

boxplot(env_all$avg_cao)
plot(env_all$avg_cao)
quantile(env_all$avg_cao, 0.025, na.rm = T) # 0.08 
quantile(env_all$avg_cao, 0.975, na.rm = T) # 2.2354 


# avg_n (no outliers)

boxplot(env_all$avg_n)
plot(env_all$avg_n)
quantile(env_all$avg_n, 0.025, na.rm = T) # 0.9125 
quantile(env_all$avg_n, 0.975, na.rm = T) # 3.1328 


# avg_dsw (some ovious outliers)

boxplot(env_all$avg_dsw)
plot(env_all$avg_dsw)
quantile(env_all$avg_dsw, 0.025, na.rm = T) # 66 
quantile(env_all$avg_dsw, 0.975, na.rm = T) # 677 


# avg_pd (a few outliers)

boxplot(env_all$avg_pd)
plot(env_all$avg_pd)
quantile(env_all$avg_pd, 0.025, na.rm = T) # 0.39
quantile(env_all$avg_pd, 0.975, na.rm = T) # 4.5


# aspect (a few outliers)

boxplot(env_all$aspect)
plot(env_all$aspect)
quantile(env_all$aspect, 0.025, na.rm = T) # 64.5554
quantile(env_all$aspect, 0.975, na.rm = T) # 233.6043 


# elevation (possible outliers; weirdly distributed)

boxplot(env_all$elevation)
plot(env_all$elevation)
quantile(env_all$elevation, 0.025, na.rm = T) # 7.4568 
quantile(env_all$elevation, 0.975, na.rm = T) # 754.7247 


# elevation_max (same)

boxplot(env_all$elevation_max)
plot(env_all$elevation_max)
quantile(env_all$elevation_max, 0.025, na.rm = T) # 12.41 
quantile(env_all$elevation_max, 0.975, na.rm = T) # 772.17 


# elevation_min (same)

boxplot(env_all$elevation_min)
plot(env_all$elevation_min)
quantile(env_all$elevation_min, 0.025, na.rm = T) # 1.08  
quantile(env_all$elevation_min, 0.975, na.rm = T) # 744.08 


# isothermality (no outliers)

boxplot(env_all$isothermality)
plot(env_all$isothermality)
quantile(env_all$isothermality, 0.025, na.rm = T) # 2.3   
quantile(env_all$isothermality, 0.975, na.rm = T) # 3.1 


# rain_coldestQuart (no outliers)

boxplot(env_all$rain_coldestQuart)
plot(env_all$rain_coldestQuart)
quantile(env_all$rain_coldestQuart, 0.025, na.rm = T) # 100    
quantile(env_all$rain_coldestQuart, 0.975, na.rm = T) # 614.3615 


# rain_driestMonth (a couple of outliers)

boxplot(env_all$rain_driestMonth)
plot(env_all$rain_driestMonth)
quantile(env_all$rain_driestMonth, 0.025, na.rm = T) # 26.56215     
quantile(env_all$rain_driestMonth, 0.975, na.rm = T) # 101.813 


# rain_driestQuart (same as above)

boxplot(env_all$rain_driestQuart)
plot(env_all$rain_driestQuart)
quantile(env_all$rain_driestQuart, 0.025, na.rm = T) # 86.8625      
quantile(env_all$rain_driestQuart, 0.975, na.rm = T) # 378.5941 


# rain_mean_annual (same as above)

boxplot(env_all$rain_mean_annual)
plot(env_all$rain_mean_annual)
quantile(env_all$rain_mean_annual, 0.025, na.rm = T) # 624.7409       
quantile(env_all$rain_mean_annual, 0.975, na.rm = T) # 2184.62 


# rain_seasonailty (no outliers)

boxplot(env_all$rain_seasonailty)
plot(env_all$rain_seasonailty)
quantile(env_all$rain_seasonailty, 0.025, na.rm = T) # 22.91163        
quantile(env_all$rain_seasonailty, 0.975, na.rm = T) # 39.02066 


# rain_warmestQuart (some obvious outliers)

boxplot(env_all$rain_warmestQuart)
plot(env_all$rain_warmestQuart)
quantile(env_all$rain_warmestQuart, 0.025, na.rm = T) # 227.3947        
quantile(env_all$rain_warmestQuart, 0.975, na.rm = T) # 445.4587 


# rain_wettestMonth (no outliers)

boxplot(env_all$rain_wettestMonth)
plot(env_all$rain_wettestMonth)
quantile(env_all$rain_wettestMonth, 0.025, na.rm = T) # 83.575         
quantile(env_all$rain_wettestMonth, 0.975, na.rm = T) # 267.7661 


# rain_wettestQuart (no outliers)     

boxplot(env_all$rain_wettestQuart)
plot(env_all$rain_wettestQuart)
quantile(env_all$rain_wettestQuart, 0.025, na.rm = T) # 238.1079          
quantile(env_all$rain_wettestQuart, 0.975, na.rm = T) # 704.1772 


# slope (a couple outliers)

boxplot(env_all$slope)
plot(env_all$slope)
quantile(env_all$slope, 0.025, na.rm = T) # 0.5601209           
quantile(env_all$slope, 0.975, na.rm = T) # 7.409242 


# temp_annual_range (no outliers)

boxplot(env_all$temp_annual_range)
plot(env_all$temp_annual_range)
quantile(env_all$temp_annual_range, 0.025, na.rm = T) # 14.57949            
quantile(env_all$temp_annual_range, 0.975, na.rm = T) # 30.6 


# temp_coldestQuart (some obvious outliers)

boxplot(env_all$temp_coldestQuart)
plot(env_all$temp_coldestQuart)
quantile(env_all$temp_coldestQuart, 0.025, na.rm = T) # 9.9425             
quantile(env_all$temp_coldestQuart, 0.975, na.rm = T) # 2.604683 


# temp_diurnal_range (no outliers)

boxplot(env_all$temp_diurnal_range)
plot(env_all$temp_diurnal_range)
quantile(env_all$temp_diurnal_range, 0.025, na.rm = T) # 3.9              
quantile(env_all$temp_diurnal_range, 0.975, na.rm = T) # 7.8 

# temp_driestQuart (no outliers)

boxplot(env_all$temp_driestQuart)
plot(env_all$temp_driestQuart)
quantile(env_all$temp_driestQuart, 0.025, na.rm = T) # 7.24102               
quantile(env_all$temp_driestQuart, 0.975, na.rm = T) # 8.1 


# temp_max_warmestMonth (a couple outliers)

boxplot(env_all$temp_max_warmestMonth)
plot(env_all$temp_max_warmestMonth)
quantile(env_all$temp_max_warmestMonth, 0.025, na.rm = T) # 13.92767                
quantile(env_all$temp_max_warmestMonth, 0.975, na.rm = T) # 19.47184 


# temp_mean_annual (same as above)

boxplot(env_all$temp_mean_annual)
plot(env_all$temp_mean_annual)
quantile(env_all$temp_mean_annual, 0.025, na.rm = T) # 0.03952842                 
quantile(env_all$temp_mean_annual, 0.975, na.rm = T) # 7.181392


# temp_min_coldestMonth (some outliers)

boxplot(env_all$temp_min_coldestMonth)
plot(env_all$temp_min_coldestMonth)
quantile(env_all$temp_min_coldestMonth, 0.025, na.rm = T) # 14.18721                  
quantile(env_all$temp_min_coldestMonth, 0.975, na.rm = T) # 0.6530328 


# temp_seasonality (no outliers)

boxplot(env_all$temp_seasonality)
plot(env_all$temp_seasonality)
quantile(env_all$temp_seasonality, 0.025, na.rm = T) # 39.30014                   
quantile(env_all$temp_seasonality, 0.975, na.rm = T) # 80.51455 


# temp_warmestQuart (a few outliers)

boxplot(env_all$temp_warmestQuart)
plot(env_all$temp_warmestQuart)
quantile(env_all$temp_warmestQuart, 0.025, na.rm = T) # 9.8                    
quantile(env_all$temp_warmestQuart, 0.975, na.rm = T) # 15 


# temp_wettestQuart (some outliers)

boxplot(env_all$temp_wettestQuart)
plot(env_all$temp_wettestQuart)
quantile(env_all$temp_wettestQuart, 0.025, na.rm = T) # 1.478418                     
quantile(env_all$temp_wettestQuart, 0.975, na.rm = T) # 12.61268  



# Check for collinearity --------------------------------------------------


cor(env_all)

# we first fit a model with all the predictors and then look at the variance
# inflation factor (VIF) of each predictor
# variables with a VIF over 2 are usually collinear

ash.lm <- lm(avg_ash ~ elevation + isothermality + rain_coldestQuart +
               rain_driestMonth + rain_driestQuart + rain_mean_annual +
               rain_seasonailty + rain_warmestQuart + rain_wettestMonth +
               rain_wettestQuart + slope + aspect + temp_annual_range +
               temp_coldestQuart + temp_diurnal_range + temp_driestQuart +
               temp_max_warmestMonth + temp_mean_annual + temp_min_coldestMonth +
               temp_seasonality + temp_warmestQuart + temp_wettestQuart,
             data = env_all)
summary(ash.lm)
car::vif(ash.lm)

# vif fails because two or more of the predictors are perfectly correlated with 
# each other

cor(env_all[ , c(8:31)], use = "complete.obs")

# many culprits! will have to suss this out later

