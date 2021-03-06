# Aim: create area cartograms
library(cartogram)
library(tmap)
library(spData)
nz$pop = 1:nrow(nz)
nz_sp = as(nz, "Spatial")
nz_carto1 = cartogram(nz_sp, "pop")
nz_carto2 = cartogram::nc_cartogram(nz_sp, "pop")
carto1 = tm_shape(nz_carto1) + tm_polygons(col = "pop")
carto2 = tm_shape(nz_carto2) + tm_polygons(col = "pop")
tmap_arrange(carto1, carto2)
