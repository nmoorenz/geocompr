par(mfrow = c(1, 3), mar = c(0, 0, 1, 0))
plot(urb$geometry, col = "white", main = "Target object")
plot(asia$geom, add = TRUE)
plot(urb$geometry, col = "white", main = "Source object (points)")
plot(urb["population_millions"], pch = 15, key.pos = NULL, add = TRUE, pal = rainbow)
plot(asia$geom, border = "grey", add = TRUE)
par(mar = c(0, 0, 1, 0))
plot(urb$geometry, col = "white", main = "Result of spatial join")
plot(urb["population_millions"], pch = 15, key.pos = NULL, add = TRUE, pal = rainbow)
plot(asia$geom, add = TRUE)
plot(joined["population_millions"], add = TRUE, key.pos = NULL, pal = rainbow)
par(mfrow = c(1, 1))