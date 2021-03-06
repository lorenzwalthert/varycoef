## ----setup, include=FALSE------------------------------------------------
rm(list = ls())
knitr::opts_chunk$set(echo = TRUE)
library(varycoef)

## ----define and sample SVC, warning=FALSE, fig.width=7, fig.height=7, message=FALSE----
# number of SVC
p <- 3

(pars <- data.frame(mu = rep(0, p), 
                    var = c(0.1, 0.2, 0.3), 
                    scale = c(0.3, 0.1, 0.2)))
nugget.var <- 0.05

# sqrt of total number of observations

m <- 20


library(RandomFields)
library(sp)

sp.SVC <- varycoef:::fullSVC_reggrid(m = m, p = p, 
                                     pars = list(pars = pars, 
                                                 nugget.var = nugget.var))

spplot(sp.SVC, colorkey = TRUE)

## ----sample covariates---------------------------------------------------
n <- m^2

X <- matrix(c(rep(1, n), rnorm((p-1)*n)), ncol = p)
head(X)

## ----compute response----------------------------------------------------
y <- apply(X * as.matrix(sp.SVC@data[, 1:p]), 1, sum) + sp.SVC@data[, p+1]

## ----contorl parameters--------------------------------------------------
control <- SVC_mle_control()
str(control)

## ----illustrate tapering, echo = FALSE, fig.width=7, fig.height=7--------

r <- c(0.5, 0.3, 0.1)
out <- lapply(c(list(NULL), as.list(r)), function(taper.range) {
  
  
  locs <- coordinates(sp.SVC)
  if (is.null(taper.range)) {
    d <- as.matrix(dist(locs))
  } else {
    d <- spam::nearest.dist(locs, delta = taper.range)
  }
  
  
  # get covariance function
  raw.cov.func <- varycoef:::MLE.cov.func("exp")
  
  # covariance function
  cov.func <- function(x) raw.cov.func(d, x)
    
  
  W <- X
  
  outer.W <- lapply(1:p, function(j) W[, j]%o%W[, j])
  
  
  # tapering?
  taper <- if(is.null(taper.range)) {
    # without tapering
    NULL
  } else {
    # with tapering
    spam::cov.wend1(d, c(taper.range, 1, 0))
  }
  
  x <- c(rep(1, 2*p+1), rep(0, p))
  
  S_y <- varycoef:::Sigma_y(x, p, cov.func, outer.W, taper)
  
  nll <- function() varycoef:::n2LL(x, cov.func, outer.W, y, X, W, taper = taper)
  
  list(d, taper, S_y, nll)
})




par(mfrow = c(2, 2))


image(out[[1]][[3]])
title(main = "No tapering applied")
image(out[[2]][[3]])
title(main = paste0("Taper range = ", r[1]))
image(out[[3]][[3]])
title(main = paste0("Taper range = ", r[2]))
image(out[[4]][[3]])
title(main = paste0("Taper range = ", r[3]))


par(mfrow = c(1, 1))


## ----runtime tapering, fig.width=7, echo = TRUE, fig.height=5, warning=FALSE----


library(microbenchmark)

(mb <- microbenchmark(no_tapering  = out[[1]][[4]](),
                      tapering_0.5 = out[[2]][[4]](), 
                      tapering_0.3 = out[[3]][[4]](),
                      tapering_0.1 = out[[4]][[4]]())
)

boxplot(mb, unit = "ms", log = TRUE, xlab = "tapering", ylab = "time (milliseconds)")

## ----mean initials-------------------------------------------------------
(mu.init <- coef(lm(y~.-1, data = data.frame(y = y, X = X))))

## ----variance initials---------------------------------------------------
(var.init <- sigma(lm(y~.-1, data = data.frame(y = y, X = X)))^2)

## ----scale initials------------------------------------------------------
scale.init <- 0.2

## ----joint initials------------------------------------------------------
init <- c(rep(c(scale.init, var.init), p), # GRFs scales and variances
          var.init,                        # nugget variance
          mu.init)                         # means

## ----overwrite initials--------------------------------------------------
# default
control$init

# overwrite
control$init <- init

# create new
control <- SVC_mle_control(init = init)

## ----overwrite save.fitted-----------------------------------------------
# default
control$save.fitted

# overwrite
control$save.fitted <- TRUE

## ----show profileLik-----------------------------------------------------
# default
control$profileLik

## ----SVC MLE-------------------------------------------------------------
fit <- SVC_mle(y = y, X = X, locs = coordinates(sp.SVC), control = control)

class(fit)

# estimated parameters
cov_par(fit) # covariance parameters
coef(fit)    # mean effects

## ----make predictions----------------------------------------------------
# calling predictions without specifying new locations (newlocs) or 
# new covariates (newX) gives estimates of SVC only at the training locations.
pred.SVC <- predict(fit)

## ----visualization of prediction, fig.width=7, fig.height=7--------------
colnames(pred.SVC)[1:p] <- paste0("pred.",colnames(pred.SVC)[1:p])
coordinates(pred.SVC) <- ~loc_x+loc_y
all.SVC <- cbind(pred.SVC, sp.SVC[, 1:3])

# compute errors
all.SVC$err.SVC_1 <- all.SVC$pred.SVC_1 - all.SVC$SVC_1
all.SVC$err.SVC_2 <- all.SVC$pred.SVC_2 - all.SVC$SVC_2
all.SVC$err.SVC_3 <- all.SVC$pred.SVC_3 - all.SVC$SVC_3

colnames(all.SVC@data) <- paste0(rep(c("pred.", "true.", "err."), each = p), "SVC_", rep(1:p, 3))

spplot(all.SVC[, paste0(rep(c("true.", "err.", "pred."), each = p), 
                        "SVC_", 1:p)], colorkey = TRUE)

## ----n2500 figure, fig.width=7, fig.height=7-----------------------------
knitr::include_graphics("figures/SVCs_result_n2500_p3.png")

## ----n2500 example, eval=FALSE-------------------------------------------
#  # new m
#  m <- 50
#  
#  # new SVC model
#  sp.SVC <- varycoef:::fullSVC_reggrid(m = m, p = p,
#                                       pars = list(pars = pars,
#                                                   nugget.var = nugget.var))
#  spplot(sp.SVC, colorkey = TRUE)
#  
#  # total number of observations
#  n <- m^2
#  X <- matrix(c(rep(1, n), rnorm((p-1)*n)), ncol = p)
#  y <- apply(X * as.matrix(sp.SVC@data[, 1:p]), 1, sum) + sp.SVC@data[, p+1]
#  
#  
#  fit <- SVC_mle(y = y, X = X, locs = coordinates(sp.SVC))
#  
#  
#  
#  sp2500 <- predict(fit)
#  
#  
#  colnames(sp2500)[1:p] <- paste0("pred.",colnames(sp2500)[1:p])
#  coordinates(sp2500) <- ~loc_x+loc_y
#  all.SVC <- cbind(sp2500, sp.SVC[, 1:3])
#  
#  # compute errors
#  all.SVC$err.SVC_1 <- all.SVC$pred.SVC_1 - all.SVC$SVC_1
#  all.SVC$err.SVC_2 <- all.SVC$pred.SVC_2 - all.SVC$SVC_2
#  all.SVC$err.SVC_3 <- all.SVC$pred.SVC_3 - all.SVC$SVC_3
#  
#  colnames(all.SVC@data) <- paste0(rep(c("pred.", "true.", "err."), each = p), "SVC_", rep(1:p, 3))
#  
#  png(filename = "figures/SVCs_result_n2500_p3.png")
#  spplot(all.SVC[, paste0(rep(c("true.", "err.", "pred."), each = p),
#                          "SVC_", 1:p)], colorkey = TRUE,
#         as.table = TRUE, layout = c(3, 3))
#  dev.off()

## ----sample SVC model----------------------------------------------------
# new m
m <- 20

# number of fixed effects
pX <- 4
# number of mean-zero SVC
pW <- 3


# mean values
mu <- 1:pX

# new SVC model
sp.SVC <- varycoef:::fullSVC_reggrid(m = m, p = pW, 
                                     pars = list(pars = pars,
                                                 nugget.var = nugget.var), 
                                     seed = 4)

# total number of observations
n <- m^2
X <- matrix(c(rep(1, n), rnorm((pX-1)*n, 
                               mean = rep(1:(pX-1), each = n), 
                               sd = rep(0.2*(1:(pX-1)), each = n))), ncol = pX)
W <- X[, 1:pW]
# calculate y 
y <- 
  # X * mu
  X %*% mu +
  # W * beta_tilde
  apply(W * as.matrix(sp.SVC@data[, 1:pW]), 1, sum) + 
  # nugget
  sp.SVC@data[, pW+1]

# new initial values
control <- SVC_mle_control(init = c(init[1:(2*pW + 1)], mu))

# MLE
fit <- SVC_mle(y = y, X = X, W = W, locs = coordinates(sp.SVC), control = control)


## ----give predictions----------------------------------------------------
set.seed(5)
newlocs <- matrix(c(0, 0), ncol = 2)


# only SVC prediction without y prediction
(pred.SVC <- predict(fit, newlocs = newlocs))



# SVC prediction and y prediction (with predictive variance)
newX <- matrix(c(1, rnorm(pX-1)), ncol = pX)
newW <- matrix(newX[, 1:pW], ncol = pW)

(pred.SVC <- predict(fit, 
                     newlocs = newlocs, 
                     newX = newX, newW = newW, 
                     compute.y.var = TRUE))

