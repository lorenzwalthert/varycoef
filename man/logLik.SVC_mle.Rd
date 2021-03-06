% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/logLik-SVC_mle.R
\name{logLik.SVC_mle}
\alias{logLik.SVC_mle}
\title{Extact the Likelihood}
\usage{
\method{logLik}{SVC_mle}(object, ...)
}
\arguments{
\item{object}{\code{\link{SVC_mle}} object}

\item{...}{further arguments}
}
\value{
an object of class \code{logLik} with attributes
\itemize{
  \item \code{"penalized"}, logical, if the likelihood (\code{FALSE}) or some penalized likelihood (\code{TRUE}) was optimized.
  \item \code{"profileLik"}, logical, if the optimization was done using the profile likelihood  (\code{TRUE}) or not.
  \item \code{"nobs"}, integer of number of observations
  \item \code{"df"}, integer of how many parameters were estimated. \strong{Note}: This includes only the covariance parameters if the profile likelihood was used.
}
}
\description{
Method to extract the computed (penalized) log (profile) Likelihood from an \code{\link{SVC_mle}} object.
}
\author{
Jakob Dambon
}
