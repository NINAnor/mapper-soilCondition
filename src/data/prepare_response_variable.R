# Script to clean and prep the Myrselskapet data set
# Jenny Hansen
# 24 February 2023

# working in the Wetland_Carbon_Mod project


# Sys.setlocale("LC_CTYPE", "nb_NO.UTF-8")
# rm(list = ls())

# Load required libraries -------------------------------------------------
#install.packages("readxl")
library(here)
library(readxl)
library(janitor)
library(dplyr)
library(stringr)
library(tidyr)
library(sf)
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
path_myr_sf <- file.path(path_raw, "vector", "new.shp")
myr_sf <- st_read(path_myr_sf)
head(myr_sf)

# Myrselskapet data came from the project sharepoint folder
# prior to importing, I corrected some errors in the raw data
# the CaO measurement at Helgeland_50 had both a commma and a period,
# so I removed the comma, the CaO measurements at Furnes_4 were missing
# a semicolon separator, so I added one, at Osen_1, _12, and _19,
# I removed extra semicolons in the total peat depth column

path_myr_data <- file.path(path_raw, "Digitalisert_myrselskapet.xlsx")
myr_data <- read_excel(path_myr_data, skip = 1,
                       col_names = FALSE) %>%
  row_to_names(1) %>%
  clean_names() %>%
  filter(!is.na(aske_percent),
         !is.na(gis_navn),
         gis_navn != "-") %>%
  select(gis_navn, aske_percent, n_percent, ca_o_percent, myrtype_2,
         volumvekt_torrstoff_pr_1_gram, total_dybde_m)
names(myr_data)


# name repair from below that affects the averaging calculation

# fix misspelled "Elveum_288" in myr_data
# this effects the averaging, so I am going to have to put this
# correction up top before we average the values
myr_data[77, 1] <- "Elverum_288"

# Split grouped samples into individual records & average -----------------

# data separated by a semi-colon are split into individual records,
# the character string is then checked for missing spaces and the mixed
# comma-period situation is changed to periods, the column is changed
# to a numeric and then the data is grouped by the GIS name and the
# average value is obtained
# this is done separately for all measurements because they differ in the
# number of measurements taken at each site
# values are merged (NB: since ash is our main variable of interest, it is
# the only variable not containing NAs)

# 335 records with ash%

avg_ash_df <- myr_data %>%
  separate_longer_delim(aske_percent, delim = ";") %>%
  mutate(ash_prct = str_replace_all(aske_percent, ",", "."),
         ash_prct = str_replace_all(ash_prct, pattern = "\\s",
                                    replacement = ""),
         ash_prct = as.numeric(ash_prct)) %>%
  group_by(gis_navn) %>%
  summarise(avg_ash = mean(ash_prct))

# 307 records with N%

avg_n_df <- myr_data %>%
  filter(!is.na(n_percent)) %>%
  separate_longer_delim(n_percent, delim = ";") %>%
  mutate(n_prct = str_replace_all(n_percent, ",", "."),
         n_prct = str_replace_all(n_prct, pattern = "\\s", replacement = "."),
         n_prct = as.numeric(n_prct)) %>%
  group_by(gis_navn) %>%
  summarise(avg_n = mean(n_prct))

# 307 records with CaO%

avg_cao_df <- myr_data %>%
  filter(!is.na(ca_o_percent)) %>%
  separate_longer_delim(ca_o_percent, delim = ";") %>%
  mutate(cao_prct = str_replace_all(ca_o_percent, ",", "."),
         cao_prct = str_replace_all(cao_prct, pattern = "\\s", replacement = ""),
         cao_prct = as.numeric(cao_prct)) %>%
  group_by(gis_navn) %>%
  summarise(avg_cao = mean(cao_prct))

# 236 records with dry soil weight

avg_dsw_df <- myr_data %>%
  filter(!is.na(volumvekt_torrstoff_pr_1_gram )) %>%
  separate_longer_delim(volumvekt_torrstoff_pr_1_gram , delim = ";") %>%
  mutate(dry_soil_weight = str_replace_all(volumvekt_torrstoff_pr_1_gram , ",", "."),
         dry_soil_weight = str_replace_all(dry_soil_weight, "\\s", "."),
         dry_soil_weight = as.numeric(dry_soil_weight)) %>%
  group_by(gis_navn) %>%
  summarise(avg_dsw = mean(dry_soil_weight))
  
# 163 records with total peat depth

avg_pd_df <- myr_data %>%
  mutate(total_dybde_m = na_if(total_dybde_m, "-")) %>%
  filter(!is.na(total_dybde_m)) %>%
  separate_longer_delim(total_dybde_m, delim = ";") %>%
  mutate(peat_depth = str_replace_all(total_dybde_m, ",", "."),
         peat_depth = str_replace_all(peat_depth, ">", ""),
         peat_depth = str_replace_all(peat_depth, "over ", ""),
         peat_depth = str_replace_all(peat_depth, "ca.", ""),
         peat_depth = str_replace_all(peat_depth, "\\s", "."),

         peat_depth = as.numeric(peat_depth)) %>%
  group_by(gis_navn) %>%
  summarise(avg_pd = mean(peat_depth))

# split out myrtype
# myrtype is a problem- how to deal with more than one myrtype? ask Zander
# for now, I will just select the first type recorded
# 299 records with myrtype

myrtype_df <- myr_data %>% 
  select(gis_navn, myrtype_2) %>% 
  separate_longer_delim(myrtype_2, delim = ";") %>% 
  filter(!is.na(myrtype_2)) %>% 
  group_by(gis_navn) %>% 
  slice(1) %>% 
  ungroup()



# Combine variables -------------------------------------------------------

df_list <- list(avg_ash_df, avg_cao_df, avg_n_df, avg_dsw_df, avg_pd_df,
                myrtype_df)
ms_clean <- df_list %>% purrr::reduce(left_join, by='gis_navn')

rm(avg_ash_df, avg_cao_df, avg_n_df, avg_dsw_df, avg_pd_df,
   myrtype_df, df_list)


# Check that names match in the sf & df -----------------------------------

myr_sf %>%
  anti_join(ms_clean, by = c("name" = "gis_navn")) %>%
  arrange(name) %>%
  pull(name) # n = 38 not found in ms_clean

ms_clean %>%
  anti_join(myr_sf, by = c("gis_navn" = "name")) %>%
  arrange(gis_navn) %>%
  pull(gis_navn) # n = 28 not found in myr_sf


# problems: there are 2 Aremark_9 polygons
# I think the second one was mislabeled because
# we have measurements for Aremark_10, but it is
# missing in the polygon file; the two polygons are
# also very close spatially
# for now, I will rename the second Aremark_9 to
# Aremark_10, but it may need to be dropped from
# the analysis if not confirmed later
# same with Bjugn_52; I think it is supposed to be
# Bjugn_54, since that poly is missing and we have
# data for it in the ms_clean dataset
# also duplicated: Osen_1
# Langøya_25 appears to be a mislabeling of Langøya_24, which is
# missing in the myr polygons, but is present in the ms data. There
# is a possibility that it is also Langøya_26, which is also missing?
# may have to drop this one later due to uncertainty
# Elverum_173 is two multipolygons; either this may be a single
# feature that has been split into two, but I do not know for sure
# for now, I am going to drop the second entry

myr_sf[172, 2] <- "Aremark_10"
myr_sf[111, 2] <- "Bjugn_54"
myr_sf[154, 2] <- "Langøya_24"
myr_sf <- myr_sf[-c(207),]

# fix misspelled "Bjung_30" in ms_clean

ms_clean[19, 1] <- "Bjugn_30"

# fix misspelled "Helegland_14" in ms_clean

ms_clean[65 ,1] <- "Helgeland_14"

# fix case on "roan_5" in ms_clean

ms_clean[327, 1] <- "Roan_5"

# change Oerland to Ørland in myr_sf

myr_sf <- myr_sf %>% 
  mutate(name = if_else(str_starts(name, "Oe"),
                        paste0("Ø", substr(name, 3, nchar(name))),
                        name))


# Join with bogs  ---------------------------------------------------------

common_values <- myr_sf %>%
  merge(ms_clean, by.x = "name", by.y = "gis_navn") %>%
  select(-c(id, geometry))

plot(common_values[1])


# Assign Jenny or Willeke to check myr ------------------------------------

output_path <- (file.path(path_interim, "vector", "assigned_mire_data.shp"))
xy <- st_coordinates(st_centroid(common_values))
coord_sort <- common_values[order(xy[,"X"], xy[,"Y"]),]
assigned_mire <- coord_sort %>%
  mutate(assigned = if_else(row_number() <= 159, "Willeke", "Jenny")) %>%
  select(name, assigned, avg_ash, avg_cao, avg_n, avg_dsw, avg_pd,
         myrtype = myrtype_2) %>%
  mutate(in_tact = str_pad("", width = 20),
         notes = str_pad("", width = 100))
  st_write(assigned_mire, output_path)
