## -----------------------------------------------------------------------------
## In this script, one finds every function directly related to estimating
## and predicting SVC using our proposed MLE.
## -----------------------------------------------------------------------------



## ---- help function to give back correct covariance function ----
MLE.cov.func <- function(cov.name) {
  cov.func = switch(cov.name,
                    "exp" = spam::cov.exp,
                    "sph" = spam::cov.sph,
                    stop("SVC.cov argument not defined."))
}

## ---- help function to do MLE for SVC model ----
#' @importFrom stats coef lm
MLE_computation <- function(y, X, locs, W,
                            control,
                            optim.control) {


  pW <- ncol(W)
  pX <- ncol(X)

  # # check for multiple observations at locations
  # if (nrow(unique(locs)) < nrow(locs)) {
  #   warning("Multiple Observations at single location detected.\nAggregating Observations for MLE!")
  #   # aggregating by location
  #   u.locs <- unique(locs)
  #   ch.locs <- apply(locs, 1, paste0, collapse = "x")
  #   u.ch.locs <- unique(ch.locs)
  #
  #   ns <- as.numeric(table(ch.locs)[u.ch.locs])
  #
  #   J <- spam::diag.spam(as.numeric(unlist(mapply(rep, times = ns, x = 1/ns))))
  #   J@colindices <- as.numeric(unlist(mapply(rep, times = ns, x = 1:nrow(u.locs))))
  #   J@dimension[2] <- nrow(u.locs)
  #
  #   ord <- as.numeric(unlist(sapply(u.ch.locs, function(loc) which(ch.locs %in% loc))))
  #
  #   # X.tilde <- sapply(1:pX, function(j){
  #   #   spam::diag.spam(spam::crossprod.spam(J, spam::diag.spam(X[ord, j]))%*%J)
  #   # })
  #
  #   X.tilde <- spam::crossprod.spam(J, X[ord, ])
  #
  #
  #   W.tilde <- if (is.null(W)) {
  #     NULL
  #   } else {
  #     # sapply(1:pW, function(j){
  #     #   spam::diag.spam(spam::crossprod.spam(J, spam::diag.spam(W[ord, j]))%*%J)
  #     # })
  #
  #     spam::crossprod.spam(J, W[ord, ])
  #   }
  #
  #   return(MLE_computation(y = spam::crossprod.spam(J, y[ord]),
  #                          X = X.tilde,
  #                          locs = u.locs,
  #                          control = control,
  #                          W = W.tilde,
  #                          ns = NULL,
  #                          optim.control = optim.control))
  # }

  # define distance matrix
  if (is.null(control$tapering)) {
    d <- as.matrix(stats::dist(locs))
  } else {
    d <- spam::nearest.dist(locs, delta = control$tapering)
  }


  # get covariance function
  raw.cov.func <- MLE.cov.func(control$cov.name)

  # covariance function
  cov.func <- function(x) raw.cov.func(d, x)

  # init
  if (is.null(control$init)) {
    init <- c(rep(0.3, 2*pW+1),
              rep(0.0, pX))
  } else {
    init <- control$init
  }

  # lower bound for optim
  if (is.null(control$lower)) {
    lower <- c(rep(0.00001, 2*pW+1), rep(-Inf, pX))
  } else {
    lower <- control$lower
  }

  # upper bound for optim
  if (is.null(control$upper)) {
    upper <- rep(Inf, 2*pW+1+ pX)
  } else {
    upper <- control$upper
  }


  # call optimization
  if (is.null(control$cl)) {

  } else {
    stop("Parallelization not yet implemented.")
  }


  # tapering?
  if (is.null(control$tapering)) {
    taper <- NULL
    outer.W <- lapply(1:pW, function(j) W[, j]%o%W[, j])
  } else {
    taper <- switch(control$cov.name,
                    "exp" = spam::cov.wend1(d, c(control$taper, 1, 0)),
                    "sph" =
                      {
                        h <- d
                        h@entries <- rep(1, length(h@entries))
                        h
                      })
    outer.W <- lapply(1:pW, function(j) {
      (W[, j]%o%W[, j]) * spam::as.spam(d<control$tapering)
    })
  }



  # holds parameters we optimize over
  path.env <- new.env(parent = emptyenv())
  path.env$mu <- NULL
  path.env$x  <- NULL
  path.env$profileLik <- control$profileLik


  # pc priors
  # ordering: pcp = c(\rho_0, \alpha_\rho, \sigma_0, \alpha_\sigma)
  pcp.neg2dens <- if (is.null(control$pc.prior)) {
    NULL
  } else {
    pcp <- control$pc.prior

    lambda.r <- -log(pcp[2])*2*pcp[1]
    lambda.s <- -log(pcp[4])/pcp[3]

    # for Matérn GRF (-2 * log( pc prior dens))
    function(theta) {
      4*log(theta[1]) +
        lambda.r/theta[1]+2*lambda.s*sqrt(theta[2])
    }

  }



  if (control$profileLik) {

    # prepare for optimization by computing mean effect
    mu.estimate <- if (control$mean.est == "GLS") {
      NULL
    } else { # Ordinary Least Squares
      coef(lm(y~X-1))
    }

    # start optimization
    optim.output <- stats::optim(par     = init[1:(2*pW + 1)],
                                 fn      = profile.n2LL,
                                 # arguments of profile.2nLL
                                    cov_func = cov.func,
                                    outer.W  = outer.W,
                                    y        = y,
                                    X        = X,
                                    W        = W,
                                    mean.est = mu.estimate,
                                    taper    = taper,
                                    envir    = path.env,
                                    pc.dens  = pcp.neg2dens,
                                 method  = "L-BFGS-B",
                                 lower   = lower[1:(2*pW + 1)],
                                 upper   = upper[1:(2*pW + 1)],
                                 control = optim.control)
  } else {

    optim.output <- stats::optim(par     = init,
                                 fn      = n2LL,
                                 # arguments of n2LL
                                    cov_func = cov.func,
                                    outer.W  = outer.W,
                                    y        = y,
                                    X        = X,
                                    W        = W,
                                    taper    = taper,
                                    envir    = path.env,
                                    pc.dens  = pcp.neg2dens,
                                 method  = "L-BFGS-B",
                                 lower   = lower,
                                 upper   = upper,
                                 control = optim.control)
    }

  # preparing output
  return(list(optim.output = optim.output,
              path = path.env,
              call.args = list(y = y,
                               X = X,
                               locs = locs,
                               control = control,
                               optim.control = optim.control,
                               W = W),
              comp.args = list(outer.W = outer.W,
                               lower = lower,
                               upper = upper,
                               init  = init,
                               pW = pW,
                               pX = pX)))


}

## ---- help function to compute fitted values after MLE ----
fitted_computation <- function(SVC_obj, y, X, W, locs) {
  class(SVC_obj) <- "SVC_mle"

  predict.SVC_mle(SVC_obj, newlocs = locs, newX = X, newW = W)

}

## ---- help function to construct SVC_mle object ----
create_SVC_mle <- function(ML_estimate, y, X, W, locs, control) {

  # extract covariance parameters and coefficients for methods
  if (control$profileLik) {
    # with profile LL has to get mu first
    cov.par <- ML_estimate$optim.output$par

    if (control$mean.est == "GLS") {
      id <- which.min(apply(ML_estimate$path$x, 2,
                            function(x) sum(( x-cov.par)^2)))
      mu <- ML_estimate$path$mu[, id]
    } else {
      mu <- ML_estimate$path$mu[, 1]
    }


  } else {
    pW <- ncol(W)
    pX <- ncol(X)

    # without profile LL mu is already in optim pars.
    hyper.par <- ML_estimate$optim.output$par

    cov.par <- hyper.par[1:(2*pW+1)]
    mu <- hyper.par[2*pW+1 + 1:pX]
  }


  SVC_obj <- list(MLE = ML_estimate,
                  coefficients = mu,
                  cov.par = cov.par,
                  fitted = NULL,
                  residuals = NULL,
                  data = list(y = y, X = X, W = W, locs = locs))


  if (control$save.fitted) {
    # compute fitted values (i.e. EBLUP = empirical BLUP)
    pred <- fitted_computation(SVC_obj, y, X, W, locs)

    SVC_obj$fitted = pred
    SVC_obj$residuals = y-pred$y.pred
  }


  return(SVC_obj)


}


#' @title Set Parameters for \code{SVC_mle}
#'
#' @description Function to set up control parameters for \code{\link{SVC_mle}}
#'
#' @param cov.name    name of the covariance function defining the covariance matrix of the GRF. Currently, only \code{"exp"} for the exponential and \code{"exp"} for spherical covariance functions are supported.
#' @param tapering    if \code{NULL}, no tapering is applied. If a scalar is given, covariance tapering with this taper range is applied, for all GRF modelling the SVC.
#' @param cl          cluster for parallelization. Currently not supported.
#' @param init        numeric. Initial values for optimization procedure. The vector consists of p-times (alternating) scale and variance, the nugget variance and the p + p.fix mean effects
#' @param lower       lower bound for optim, default \code{NULL} sets the lower bounds to 1e-6 for covariance parameters and \code{-Inf} for mean parameters.
#' @param upper       upper bound for optim, default \code{NULL} sets the upper bounds to \code{Inf} for covariance and mean parameters.
#' @param save.fitted logical. If \code{TRUE}, calculates the fitted values and residuals after MLE and saves them.
#' @param profileLik  logical. If \code{TRUE}, MLE is done over profile Likelihood of covariance parameters.
#' @param mean.est    if \code{profileLik} is \code{TRUE}, the means have to be estimated seperately. \code{"GLS"} uses the generalized least square estimate while \code{"OLS"} uses the ordinary least squares estiamte.
#' @param pc.prior    takes vector of \eqn{\rho_0, \alpha_\rho, \sigma_0, \alpha_\sigma} to compute penalized complexity priors. This regulates the optimization process. Currently, only supported for Gaussian random fields of Matérn class. Based on the idea Simpson and Fulgstad.
#' @param ...         further parameters yet to be implemented
#'
#' @return A list with which \code{\link{SVC_mle}} can be controlled
#' @seealso \code{\link{SVC_mle}}
#'
#' @examples
#' control <- SVC_mle_control(init = rep(0.3, 10))
#' # or
#' control <- SVC_mle_control()
#' control$init <- rep(0.3, 10)
#'
#' @author Jakob Dambon
#'
#' @export
SVC_mle_control <- function(...) UseMethod("SVC_mle_control")


#' @rdname SVC_mle_control
#' @export
SVC_mle_control.default <- function(cov.name = c("exp", "sph"),
                                    tapering = NULL,
                                    cl = NULL,
                                    init = NULL,
                                    lower = NULL,
                                    upper = NULL,
                                    save.fitted = TRUE,
                                    profileLik = FALSE,
                                    mean.est = c("GLS", "OLS"),
                                    pc.prior = NULL, ...) {
  stopifnot(is.null(tapering) |
              (tapering>=0) |
              is.logical(save.fitted) |
              is.logical(profileLik))


  list(cov.name = match.arg(cov.name),
       tapering = tapering,
       cl = cl,
       init = init,
       lower = lower,
       upper = upper,
       save.fitted = save.fitted,
       profileLik = profileLik,
       mean.est = match.arg(mean.est),
       pc.prior = pc.prior,
       ...)
}

#' @param object An object of class \code{SVC_mle}. The function then extracts the control settings from the particular function call used to compute \code{object}.
#'
#' @rdname SVC_mle_control
#' @export
SVC_mle_control.SVC_mle <- function(object, ...) {
  object$MLE$call.args$control
}





###############################
## SVC MLE functions ##########
###############################


#' @title MLE of SVC model
#'
#' @description Calls MLE of the SVC model defined as:
#'
#' \deqn{y(s) = X \mu + W \eta (s) + \epsilon(s)}
#'
#' where:
#' \itemize{
#'   \item y is the response (vector of length n)
#'   \item X is the data matrix for the fixed effects covariates
#'   \item \eqn{\mu} is the vetor containing the fixed effects
#'   \item W is the data matrix for the SVCs represented by zero mean GRF
#'   \item \eqn{\eta} are the SVCs represented by zero mean GRF
#'   \item \eqn{\epsilon} is the nugget effect
#' }
#'
#' The MLE is done by calling the function \code{optim}.
#'
#' @param y              numeric response vector of dimension n.
#' @param X              matrix of covariates of dimension n x pX. Intercept has to be added manually.
#' @param locs           matrix of locations of dimension n X 2. May contain multiple observations at single location which (may) cause a permutation of \code{y}, \code{X}, \code{W} and \code{locs}.
#' @param W              Optional matrix of covariates with fixed effects, i.e. non-SVC, of dimension n x pW
#' @param control        list of control paramaters, usually given by \code{\link{SVC_mle_control}}
#' @param optim.control  list of control arguments for optimization function, see Details in \code{\link{optim}}
#' @param ...            further arguments
#'
#' @return Object of class \code{SVC_mle}
#'
#' @author Jakob Dambon
#'
#' @seealso \code{\link{predict.SVC_mle}}
#'
#' @examples
#' ## ---- toy example ----
#' ## sample data
#' # setting seed for reproducibility
#' set.seed(123)
#' m <- 7
#' # number of observations
#' n <- m*m
#' # number of SVC
#' p <- 3
#' # sample data
#' y <- rnorm(n)
#' X <- matrix(rnorm(n*p), ncol = p)
#' # locations on a regular m-by-m-grid
#' locs <- expand.grid(seq(0, 1, length.out = m),
#'                     seq(0, 1, length.out = m))
#'
#' ## preparing for maximum likelihood estimation (MLE)
#' # controls specific to MLE
#' control <- SVC_mle_control(
#'   # initial values of optimization
#'   init = rep(0.1, 2*p+1),
#'   # using profile likelihood
#'   profileLik = TRUE
#' )
#'
#' # controls specific to optimization procedure, see help(optim)
#' opt.control <- list(
#'   # number of iterations (set to one for demonstration sake)
#'   maxit = 1,
#'   # tracing information
#'   trace = 6
#' )
#'
#' ## starting MLE
#' fit <- SVC_mle(y = y, X = X, locs = locs,
#'                control = control,
#'                optim.control = opt.control)
#'
#' ## output: convergence code equal to 1, since maxit was only 1
#' summary(fit)
#'
#' \donttest{
#' ## ---- real data example ----
#' require(sp)
#' ## get data set
#' data("meuse", package = "sp")
#'
#' # construct data matrix and response, scale locations
#' y <- log(meuse$cadmium)
#' X <- model.matrix(~1+dist+lime+elev, data = meuse)
#' locs <- as.matrix(meuse[, 1:2])/1000
#'
#'
#' ## starting MLE
#' # the next call takes a couple of seconds
#' fit <- SVC_mle(y = y, X = X, locs = locs,
#'                # has 4 fixed effects, but only 3 random effects (SVC)
#'                # elev is missing in SVC
#'                W = X[, 1:3],
#'                control = SVC_mle_control(
#'                  # inital values for 3 SVC
#'                  # 7 = (3 * 2 covariance parameters + nugget)
#'                  init = c(rep(c(0.4, 0.2), 3), 0.2),
#'                  profileLik = TRUE
#'                ))
#'
#' ## summary and residual output
#' summary(fit)
#' plot(fit)
#'
#' ## predict
#' # new locations
#' newlocs <- expand.grid(
#'   x = seq(min(locs[, 1]), max(locs[, 1]), length.out = 30),
#'   y = seq(min(locs[, 2]), max(locs[, 2]), length.out = 30))
#' # predict SVC for new locations
#' SVC <- predict(fit, newlocs = as.matrix(newlocs))
#' # visualization
#' sp.SVC <- SVC
#' coordinates(sp.SVC) <- ~loc_x+loc_y
#' spplot(sp.SVC, colorkey = TRUE)
#' }
#' @import spam
#' @importFrom stats dist optim
#' @export
SVC_mle <- function(...) UseMethod("SVC_mle")



#' @rdname SVC_mle
#' @export
SVC_mle.default <- function(y, X, locs, W = NULL,
                            control = NULL,
                            optim.control = list(), ...) {

  # check if W is given arguments
  if (is.null(W)) {W <- X}

  # issue warning if called with default control settings
  if (is.null(control)) {
    control <- SVC_mle_control()
    warning("Using default control settings. Do they make sense in your case?")
  }

  # Start ML Estimation using optim
  ML_estimate <- MLE_computation(y = y,
                                 X = X,
                                 locs = locs,
                                 W = W,
                                 control = control,
                                 optim.control = optim.control)

  object <- create_SVC_mle(ML_estimate, y, X, W, locs, control)

  class(object) <- "SVC_mle"
  return(object)
}

# formula call

#' @param formula Formula describing the fixed effects in SVC model. The response, i.e. LHS of the formula, is not allowed to have functions such as \code{sqrt()} or \code{log()}.
#' @param data data frame containing the observations
#' @param RE_formula Formula describing the random effects in SVC model. Only RHS is considered. If \code{NULL}, the same RHS of argument \code{formula} for fixed effects is used.
#' @importFrom stats model.matrix
#'
#' @rdname SVC_mle
#' @export
SVC_mle.formula <- function(formula, data, RE_formula = NULL,
                            locs, control, optim.control = list(), ...) {


  X <- as.matrix(model.matrix(formula, data = data))
  W <- if (is.null(RE_formula)) {X} else {
    as.matrix(model.matrix(RE_formula, data = data))
  }
  y <- as.numeric(data[, all.vars(formula)[1]])

  SVC_mle.default(y = y,
                  X = X,
                  locs = locs,
                  W = W,
                  control = control,
                  optim.control = optim.control)
}





#' Prediction of SVC (and response variable)
#'
#' @param object        output of \code{\link{SVC_mle}}
#' @param newlocs       matrix of dimension n' x 2. These are the new locations the SVCs are predicted for. If \code{NULL}, the locations from the \code{SVC_mle} (i.e. \code{locs}) are considered.
#' @param newX          optional matrix of dimension n' x pX. If provided, besides the predicted SVC, the function also returns the predicted response variable.
#' @param newW          optional matrix of dimension n' x pW.
#' @param compute.y.var logical. If y will be estimated and \code{TRUE}, the standard deviation of each estimate will be computed.
#' @param ...           further arguments
#' @return returns a data frame of n' rows and with columns
#' \itemize{
#'   \item \code{SVC_1, ..., SVC_p}, i.e. the predicted SVC at locations \code{newlocs}
#'   \item \code{y.pred}, if \code{newX} and \code{newW} are provided
#'   \item \code{y.var}, if \code{newX} and \code{newW} are provided and \code{compute.y.var} is set to \code{TRUE}.
#'   \item \code{loc_x, loc_y}, the locations of the predictions
#' }
#'
#' @seealso \code{\link{SVC_mle}}
#'
#' @author Jakob Dambon
#'
#' @examples
#' ## ---- toy example ----
#' ## sample data
#' # setting seed for reproducibility
#' set.seed(123)
#' m <- 7
#' # number of observations
#' n <- m*m
#' # number of SVC
#' p <- 3
#' # sample data
#' y <- rnorm(n)
#' X <- matrix(rnorm(n*p), ncol = p)
#' # locations on a regular m-by-m-grid
#' locs <- expand.grid(seq(0, 1, length.out = m),
#'                     seq(0, 1, length.out = m))
#'
#' ## preparing for maximum likelihood estimation (MLE)
#' # controls specific to MLE
#' control <- SVC_mle_control(
#'   # initial values of optimization
#'   init = rep(0.1, 2*p+1),
#'   # using profile likelihood
#'   profileLik = TRUE
#' )
#'
#' # controls specific to optimization procedure, see help(optim)
#' opt.control <- list(
#'   # number of iterations (set to one for demonstration sake)
#'   maxit = 1,
#'   # tracing information
#'   trace = 6
#' )
#'
#' ## starting MLE
#' fit <- SVC_mle(y = y, X = X, locs = locs,
#'                control = control,
#'                optim.control = opt.control)
#'
#' ## output: convergence code equal to 1, since maxit was only 1
#' summary(fit)
#'
#' ## prediction
#' # new location
#' newlocs <- matrix(0.5, ncol = 2, nrow = 1)
#'
#' # new data
#' X.new <- matrix(rnorm(p), ncol = p)
#'
#' # predicting SVCs
#' predict(fit, newlocs = newlocs)
#'
#' # predicting SVCs and calculating response
#' predict(fit, newlocs = newlocs,
#'         newX = X.new, newW = X.new)
#'
#' # predicting SVCs, calculating response and predictive variance
#' predict(fit, newlocs = newlocs,
#'         newX = X.new, newW = X.new,
#'         compute.y.var = TRUE)
#'
#' @import spam
#' @importFrom fields rdist
#' @importFrom stats dist sd
#' @export
predict.SVC_mle <- function(object, newlocs = NULL, newX = NULL, newW = NULL, compute.y.var = FALSE, ...) {

  mu <- coef(object)
  cov.par <- cov_par(object)


  pW <- object$MLE$comp.args$pW
  pX <- object$MLE$comp.args$pX
  n <- length(object$MLE$call.args$y)

  # if no new locations are given,
  # predict for training data
  if (is.null(newlocs)) {
    # compute untapered distance matrix
    newlocs <- object$MLE$call.args$locs
    d <- d_cross <- as.matrix(dist(newlocs))
    n.new <- n
  } else {
    d <- as.matrix(stats::dist(object$MLE$call.args$locs))
    d_cross <- fields::rdist(newlocs, object$MLE$call.args$locs)
    n.new <- nrow(newlocs)
  }

  # covariance function (not tapered)
  raw.cf <- MLE.cov.func(object$MLE$call.args$control$cov.name)



  if (is.null(object$MLE$call.args$control$taper)) {
    taper <- NULL

    # cross-covariance (newlocs and locs)
    cf_cross <- function(x) raw.cf(d_cross, x)

  } else {
    taper <- switch(object$MLE$call.args$control$cov.name,
                    "exp" = spam::cov.wend1(d, c(object$MLE$call.args$control$taper, 1, 0)),
                    "sph" =
                      {
                        spam::as.spam(d<object$MLE$call.args$control$taper)
                      })

    taper_cross <- switch(object$MLE$call.args$control$cov.name,
                      "exp" = spam::cov.wend1(d_cross, c(object$MLE$call.args$control$taper, 1, 0)),
                      "sph" =
                        {
                          spam::as.spam(d_cross<object$MLE$call.args$control$taper)
                        })

    # cross-covariance (newlocs and locs)
    cf_cross <- function(x) raw.cf(d_cross, x)*taper_cross
  }

  # covariance y
  cf <- function(x) raw.cf(d, x)



  cov_y <- Sigma_y(x = cov.par,
                   p = pW,
                   cov_func = cf,
                   outer.W = object$MLE$comp.args$outer.W,
                   taper = taper)


  # cross-covariance beta' y
  cov_b_y <- Sigma_b_y(x = cov.par,
                       cov.func = cf_cross,
                       W = as.matrix(object$MLE$call.args$W),
                       n.new = n.new)



  eff <- cov_b_y %*% solve(cov_y) %*%
    (object$MLE$call.args$y - object$MLE$call.args$X %*% mu)

  eff <- matrix(eff, ncol = pW)


  if (!is.null(newX) & !is.null(newW)) {

    stopifnot(pW == ncol(newW),
              pX == ncol(newX))

    y.pred <- apply(newW * eff, 1, sum) + newX %*% mu

    # computation of standard deviation fro each observation.
    if (compute.y.var) {
      # Have to compute
      #
      # var.y = Sigma_ynew - Sigma_ynew_y Sigma_y^-1 Sigma_y_ynew
      #
      # Sigma_ynew   = A
      # Sigma_ynew_y = B
      # Sigma_y      = C
      # Sigma_y_ynew = D = t(C)


      # Part B:
      cov_ynew_y <- Sigma_y_y(cov.par,
                            cov.func = cf_cross,
                            X = object$MLE$call.args$W,
                            newX = newW)

      # Part A:

      d_new <- as.matrix(stats::dist(newlocs))


      if (is.null(object$MLE$call.args$control$taper)) {
        outer.newW <- lapply(1:pW, function(j) {
          (newW[, j]%o%newW[, j]) })
      } else {
        outer.newW <- lapply(1:pW, function(j) {
          (newW[, j]%o%newW[, j]) * spam::as.spam(d_new<object$MLE$call.args$control$taper)})
      }

      if (is.null(object$MLE$call.args$control$taper)) {
        taper_new <- NULL



      } else {
        taper_new <- switch(object$MLE$call.args$control$cov.name,
                           "exp" = spam::cov.wend1(d_new, c(object$MLE$call.args$control$taper, 1, 0)),
                           "sph" =
                             {
                               spam::as.spam(d_new<object$MLE$call.args$control$taper)
                             })
      }

      # cross-covariance (newlocs and locs)
      cf_new <- function(x) raw.cf(d_new, x)

      cov_ynew <- Sigma_y(cov.par, pW,
                          cf_new,
                          outer.W = outer.newW,
                          taper = taper_new)


      # Part C: already calculated with cov_y


      # Computation of variance of y
      var.y <- diag(cov_ynew) - diag(cov_ynew_y %*% solve(cov_y) %*% t(cov_ynew_y))

      # form out put
      out <- as.data.frame(cbind(eff, y.pred, var.y, newlocs))
      colnames(out) <- c(paste0("SVC_", 1:ncol(eff)), "y.pred", "y.var", "loc_x", "loc_y")
    } else {
      out <- as.data.frame(cbind(eff, y.pred, newlocs))
      colnames(out) <- c(paste0("SVC_", 1:ncol(eff)), "y.pred", "loc_x", "loc_y")
    }


  } else {

    if (compute.y.var)
      warning("Please provide new X and W matrix to predict y and its standard deviation.")

    out <- as.data.frame(cbind(eff, newlocs))
    colnames(out) <- c(paste0("SVC_", 1:ncol(eff)), "loc_x", "loc_y")
  }



  return(out)
}


