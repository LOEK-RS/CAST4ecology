## Data Preparation

library(geodata)
library(rnaturalearth)
library(terra)
library(sf)
library(tidyverse)


# define region: all of south america
region = rnaturalearth::ne_countries(continent = "South America", returnclass = "sf", scale = 110)
st_write(region, "data/modeldomain.gpkg", append = FALSE)

# worldclim in reduced resolution for prediction
wc = rast(list.files("~/data/global_environmental_layer/geodata_5m/", full.names = TRUE))
wc = crop(wc, region)
names(wc) = names(wc) |> str_remove(pattern = "wc2.1_5m_")

# add terrain feature as additional predictors
wc_terrain = terra::terrain(wc$elev, v = c("slope"))
wc = c(wc, wc_terrain)
writeRaster(wc, "data/predictors.tif", overwrite = TRUE)


# worldclim in full resolution for extracting the training data
wcf = rast(list.files("~/data/global_environmental_layer/geodata_30s/", full.names = TRUE))
wcf = crop(wcf, region)
names(wcf) = names(wcf) |> str_remove(pattern = "wc2.1_30s_")
wcf$lat = terra::init(wcf, "y")
wcf$lon = terra::init(wcf, "x")
wcf_terrain = terra::terrain(wcf$elev, v = c("slope"))
wcf = c(wcf, wcf_terrain)


# Gather Response Variable: sPlotOpen Species Richness for South America
## see Appendix 1 of https://doi.org/10.1111/geb.13346
load("~/data/sPlotOpen/sPlotOpen.RData")

splot = header.oa |>
    filter(Resample_1 == TRUE) |>
    filter(Continent == "South America") |> 
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |> 
    left_join(CWM_CWV.oa |> select(c("PlotObservationID", "Species_richness", "SLA_CWM", "LDMC_CWM"))) |> 
    select(c("PlotObservationID", "GIVD_ID", "Country", "Biome",
             "Species_richness", "LDMC_CWM", "SLA_CWM")) |> 
    na.omit()

# extract predictor values and attach to response
splot = terra::extract(wcf, splot, ID = FALSE, bind = TRUE) |>
    st_as_sf() |> 
    na.omit()


# only keep unique locations
## some reference sample locations are in the same predictor stack pixel
## this can lead to erroneous models and misleading validations
plots_uni = splot[!duplicated(c(splot$lat, splot$lon)),]
plots_uni = plots_uni |> na.omit()
plots_uni$lat = NULL
plots_uni$lon = NULL


st_write(plots_uni, "data/plots.gpkg", append = FALSE)


