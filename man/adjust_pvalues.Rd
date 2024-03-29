% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/adjust_pvalues.R
\name{adjust_pvalues}
\alias{adjust_pvalues}
\title{Bi-directionally adjust p-values for multiple testing}
\usage{
adjust_pvalues(emp_pmat, maxExpTbl, lowExpCutoff = 30)
}
\arguments{
\item{emp_pmat}{A gene-by-condition matrix of p-values to be adjusted}

\item{maxExpTbl}{A gene-by-condition matrix of maximal median expression level between the control and case being contrasted in the statistical test. Used for independent filtering.}

\item{lowExpCutoff}{Normalized read count cutoff for independent filtering. Default is 30.}
}
\value{
A matrix of adjusted p-values.
\describe{
\item{\code{dual_fdr_mat}}{A gene-by-condition matrix of adjusted p-values (FDR). }
}
}
\description{
A wrapper function using \code{p.adjust} to adjust for multiple testing.
This function simultaneously adjusts for the multiple testing of many genes in a single condition and for that of many conditions regarding the same gene.
This dual adjustment scheme is designed for large-scale experiment such as WPS.
The function is for internal use and must work with a maxExpTbl and lowExpCutoff for indepdendent filtering prior to adjustments.
}
\author{
Xuhang Li
}
