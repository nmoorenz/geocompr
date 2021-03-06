## ---- message = FALSE----------------------------------------------------
library(sf)
library(raster)
library(tidyverse)
library(mlr)
library(parallelMap)
library(pROC)
library(RSAGA)

## ------------------------------------------------------------------------
data("landslides", package = "RSAGA")

## ---- eval = FALSE-------------------------------------------------------
## # select non-landslide points
## non_pts = filter(landslides, lslpts == FALSE)
## # select landslide points
## lsl_pts = filter(landslides, lslpts == TRUE)
## # randomly select 175 non-landslide points
## set.seed(11042018)
## non_ind = sample(1:nrow(non_pts), nrow(lsl_pts))
## # rowbind randomly selected non-landslide points and
## # landslide points
## lsl = rbind(non_pts[non_ind, ], lsl_pts)

## ---- eval = FALSE-------------------------------------------------------
## dem =
##   raster(dem$data,
##          crs = dem$header$proj4string,
##          xmn = dem$header$xllcorner,
##          xmx = dem$header$xllcorner +
##            dem$header$ncols * dem$header$cellsize,
##          ymn = dem$header$yllcorner,
##          ymx = dem$header$yllcorner +
##            dem$header$nrows * dem$header$cellsize)

## ---- echo=FALSE---------------------------------------------------------
load("extdata/spatialcv.Rdata")

## ---- echo=FALSE---------------------------------------------------------
dplyr::select(lsl, -x, -y) %>%
  head(3)

## ----lsl-map, echo=FALSE, fig.cap="Landslide initiation points (red) and points unaffected by landsliding (blue) in Southern Ecuador. CRS: UTM zone 17S (EPSG: 32717)."----
library(tmap)
lsl_sf = st_as_sf(lsl, coords = c("x", "y"), crs = 32717)
hs = hillShade(ta$slope * pi / 180, terrain(ta$elev, opt = "aspect"))
rect = tmaptools::bb_poly(hs)
bbx = tmaptools::bb(hs, xlim = c(-0.02, 1), ylim = c(-0.02, 1), relative = TRUE)
# randomly sample 20%
# ind = sample(1:nrow(lsl_sf), round(nrow(lsl_sf) * 0.2))
# sam = lsl_sf[ind, ]

tm_shape(hs, bbox = bbx) +
	tm_grid(col = "black", n.x = 1, n.y = 1, labels.inside.frame = FALSE,
	        labels.rot = c(0, 90)) +
	tm_raster(palette = gray(0:100 / 100), n = 100, legend.show = FALSE) +
	tm_shape(ta$elev) +
	tm_raster(alpha = 0.5, palette = terrain.colors(10),
	          auto.palette.mapping = FALSE, legend.show = FALSE) +
	tm_shape(lsl_sf) + 
	tm_bubbles("lslpts", size = 0.5, palette = "-RdYlBu", title.col = "Landslide: ") +
#   tm_shape(sam) +
#   tm_bubbles(border.col = "gold", border.lwd = 2, alpha = 0, size = 0.5) +
  qtm(rect, fill = NULL) +
	tm_layout(outer.margins = c(0.04, 0.04, 0.02, 0.02), frame = FALSE) +
  tm_legend(bg.color = "white")

## ---- eval = TRUE--------------------------------------------------------
fit = glm(lslpts ~ slope + cplan + cprof + elev + log_carea, 
          data = lsl, family = binomial())
fit

## ------------------------------------------------------------------------
head(predict(object = fit, type = "response"))

## ------------------------------------------------------------------------
# loading among others ta, a raster stack containing the predictors
load("extdata/spatialcv.Rdata")
# making the prediction
pred = raster::predict(object = ta, model = fit,
                       type = "response")

## ----lsl-susc, echo = FALSE, fig.cap="Spatial prediction of landslide susceptibility using a GLM. CRS: UTM zone 17S (EPSG: 32717).", warning=FALSE----
# white raster to only plot the axis ticks, otherwise gridlines would be visible
tm_shape(hs, bbox = bbx) +
  tm_grid(col = "black", n.x = 1, n.y = 1, labels.inside.frame = FALSE,
          labels.rot = c(0, 90)) +
  tm_raster(palette = "white", legend.show = FALSE) +
  # hillshade
  tm_shape(mask(hs, study_area), bbox = bbx) +
	tm_raster(palette = gray(0:100 / 100), n = 100, legend.show = FALSE) +
	# prediction raster
  tm_shape(mask(pred, study_area)) +
	tm_raster(alpha = 0.5, palette = RColorBrewer::brewer.pal(name = "Reds", 6),
	          auto.palette.mapping = FALSE, legend.show = TRUE,
	          title = "Susceptibility") +
	# rectangle and outer margins
  qtm(rect, fill = NULL) +
	tm_layout(outer.margins = c(0.04, 0.04, 0.02, 0.02), frame = FALSE,
	          legend.position = c("left", "bottom"),
	          legend.title.size = 0.9)


## ---- message=FALSE------------------------------------------------------
pROC::auc(pROC::roc(lsl$lslpts, fitted(fit)))

## ----partitioning, fig.cap="Spatial visualization of selected test and training observations for cross-validation of one repetition. Random (upper row) and spatial partitioning (lower row).", echo = FALSE----
knitr::include_graphics("figures/13_partitioning.png")

## ----building-blocks, echo=FALSE, fig.height=4, fig.width=4, fig.cap="Basic building blocks of the **mlr** package. Source: [openml.github.io](http://openml.github.io/articles/slides/useR2017_tutorial/slides_tutorial_files/ml_abstraction-crop.png)."----
knitr::include_graphics("figures/13_ml_abstraction_crop.png")

## ------------------------------------------------------------------------
library(mlr)
# coordinates needed for the spatial partitioning
coords = lsl[, c("x", "y")]
# select response and predictors to use in the modeling
data = dplyr::select(lsl, -x, -y)
coords = lsl[, c("x", "y")]
# create task
task = makeClassifTask(data = data, target = "lslpts",
                       positive = "TRUE", coordinates = coords)

## ---- eval=FALSE---------------------------------------------------------
## listLearners(task)

## ----lrns, echo=FALSE----------------------------------------------------
lrns_df = dplyr::select(listLearners(task, warn.missing.packages = FALSE), class, name, package) %>%
  head
knitr::kable(lrns_df, caption = "Sample of available learners in the **mlr** package.")

## ------------------------------------------------------------------------
lrn = makeLearner(cl = "classif.binomial",
                  link = "logit",
                  predict.type = "prob",
                  fix.factors.prediction = TRUE)

## ---- eval=FALSE---------------------------------------------------------
## getLearnerPackages(lrn)
## helpLearner(lrn)

## ------------------------------------------------------------------------
mod = train(learner = lrn, task = task)
mlr_fit = getLearnerModel(mod)

## ---- eval = FALSE, echo = FALSE-----------------------------------------
## getTaskFormula(task)
## getTaskData(task)
## getLearnerModel(mod)
## mod$learner.model

## ------------------------------------------------------------------------
fit = glm(lslpts ~ ., family = binomial(link = "logit"), data = data)
identical(fit$coefficients, mlr_fit$coefficients)

## ------------------------------------------------------------------------
resampling = makeResampleDesc(method = "SpRepCV", folds = 5, 
                              reps = 100)

## ---- eval=FALSE---------------------------------------------------------
## set.seed(012348)
## sp_cv = mlr::resample(learner = lrn, task = task,
##                       resampling = resampling,
##                       measures = mlr::auc)

## ---- echo=FALSE---------------------------------------------------------
load("extdata/spatialcv.Rdata")

## ------------------------------------------------------------------------
# summary statistics of the 500 models
summary(sp_cv$measures.test$auc)
# mean AUROC of the 500 models
mean(sp_cv$measures.test$auc)

## ----boxplot-cv, echo=FALSE, fig.width=6, fig.height=9, fig.cap="Boxplot showing the difference in AUROC values between spatial and conventional 100-repeated 5-fold cross-validation."----
# Visualization of non-spatial overfitting
boxplot(sp_cv$measures.test$auc,
        conv_cv$measures.test$auc,
        col = c("lightblue2", "mistyrose2"),
        names = c("spatial CV", "conventional CV"), 
        ylab = "AUROC")

## ---- eval=FALSE---------------------------------------------------------
## lrns = listLearners(task)
## lrns[grep("svm", lrns$class), ]
## dplyr::select(lrns, class, name, package)
## #>            class                                 name short.name package
## #> 6   classif.ksvm              Support Vector Machines       ksvm kernlab
## #> 9  classif.lssvm Least Squares Support Vector Machine      lssvm kernlab
## #> 17   classif.svm     Support Vector Machines (libsvm)        svm   e1071

## ---- eval=FALSE---------------------------------------------------------
## lrn_ksvm = makeLearner("classif.ksvm",
##                         predict.type = "prob",
##                         kernel = "rbfdot")

## ---- eval = FALSE-------------------------------------------------------
## # performance estimation level
## perf_level = makeResampleDesc("SpRepCV", folds = 5, reps = 100)

## ----inner-outer, echo=FALSE, fig.cap="Visual representation of the hyperparameter tuning and performance estimation levels in spatial and non-spatial cross-validation. Permission for reusing the figure was kindly granted by Patrick Schratz [@schratz_performance_nodate]."----
knitr::include_graphics("figures/13_cv.png")

## ---- eval=FALSE---------------------------------------------------------
## # five spatially disjoint partitions
## tune_level = makeResampleDesc("SpCV", iters = 5)
## # use 50 randomly selected hyperparameters
## ctrl = makeTuneControlRandom(maxit = 50)
## # define the outer limits of the randomly selected hyperparameters
## ps = makeParamSet(
##   makeNumericParam("C", lower = -12, upper = 15, trafo = function(x) 2^x),
##   makeNumericParam("sigma", lower = -15, upper = 6, trafo = function(x) 2^x)
##   )

## ---- eval=FALSE---------------------------------------------------------
## wrapped_lrn_ksvm = makeTuneWrapper(learner = lrn_ksvm,
##                                    resampling = tune_level,
##                                    par.set = ps,
##                                    control = ctrl,
##                                    show.info = TRUE,
##                                    measures = mlr::auc)

## ---- eval=FALSE---------------------------------------------------------
## configureMlr(on.learner.error = "warn", on.error.dump = TRUE)

## ---- eval=FALSE---------------------------------------------------------
## library(parallelMap)
## parallelStart(mode = "multicore",
##               # parallelize the hyperparameter tuning level
##               level = "mlr.tuneParams",
##               # just use half of the available cores
##               cpus = round(parallel::detectCores() / 2),
##               mc.set.seed = TRUE)

## ---- eval=FALSE---------------------------------------------------------
## set.seed(12345)
## result = mlr::resample(learner = wrapped_lrn_ksvm,
##                        task = task,
##                        resampling = perf_level,
##                        extract = getTuneResult,
##                        measures = mlr::auc)
## # stop parallelization
## parallelStop()
## # save your result, e.g.:
## # saveRDS(result, "svm_sp_sp_rbf_50it.rds")

## ---- include=FALSE------------------------------------------------------
result = readRDS("extdata/svm_sp_sp_rbf_50it.rds")

## ------------------------------------------------------------------------
# Exploring the results
# runtime in minutes
round(result$runtime / 60, 2)

## ------------------------------------------------------------------------
# final aggregated AUROC 
result$aggr
# same as
mean(result$measures.test$auc)

## ------------------------------------------------------------------------
# winning hyperparameters of tuning step, i.e. the best combination out of 50 *
# 5 models
result$extract[[1]]$x

## ------------------------------------------------------------------------
result$measures.test[1, ]

