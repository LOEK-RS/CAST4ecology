## Data Preparation

library(geodata)
library(rnaturalearth)
library(terra)
library(sf)
library(tidyverse)
library(geodata)


##### Download Predictors --------------------------------
## Warning: This downloads ~ 1 GB of data
dir.create("raw/")

wcf = geodata::worldclim_global(var = "bio", path = "raw/", res = 0.5)
wc = geodata::worldclim_global(var = "bio", path = "raw/", res = 5)
elevf = geodata::elevation_global(res = 0.5, path = "raw/")
elev = geodata::elevation_global(res = 5, path = "raw/")

wcf = c(wcf, elevf)
wc = c(wc, elev)

##### Download sPlotOpen -------------------------------------
if(!file.exists("raw/splotopen")){
  download.file("https://idata.idiv.de/ddm/Data/DownloadZip/3474?version=5779", destfile = "raw/splotopen.zip")
  unzip(zipfile = "raw/splotopen.zip", exdir = "raw/splotopen")
}



##### Clean up and save necessary files ----------------------------------
# define region: all of south america
region = rnaturalearth::ne_countries(continent = "South America", returnclass = "sf", scale = 110)
st_write(region, "data/modeldomain.gpkg", append = FALSE)

# Predictor clean up
wc = crop(wc, region)
names(wc) = names(wc) |> str_remove(pattern = "wc2.1_5m_")
p = c("bio_1", "bio_4", "bio_5", "bio_6", "bio_8", "bio_9", "bio_12", "bio_13", "bio_14", "bio_15", "elev")
wc = wc[[p]]
writeRaster(wc, "data/predictors.tif", overwrite = TRUE)
saveRDS(wc, "data/predictors.RDS")

# worldclim in full resolution for extracting the training data
wcf = crop(wcf, region)
names(wcf) = names(wcf) |> str_remove(pattern = "wc2.1_30s_")
wcf = wcf[[p]]
wcf$lat = terra::init(wcf, "y")
wcf$lon = terra::init(wcf, "x")


# Gather Response Variable: sPlotOpen Species Richness for South America
## see Appendix 1 of https://doi.org/10.1111/geb.13346
load("raw/splotopen/sPlotOpen.RData")

splot = header.oa |>
    #filter(Resample_1 == TRUE) |>
    filter(Continent == "South America") |> 
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |> 
    left_join(CWM_CWV.oa |> select(c("PlotObservationID", "Species_richness"))) |> 
    select(c("PlotObservationID", "GIVD_ID", "Country", "Biome",
             "Species_richness")) |> 
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


st_write(plots_uni, "data/reference_samples.gpkg", append = FALSE)
saveRDS(plots_uni, "data/reference_samples.RDS")

