utils::globalVariables(c("x"))
#' @title Fit the empirical null of DE test statistics
#'
#' @description
#' Fit the gene-by-gene empricial null distribution using an input test statistic matrix
#' @param statTbl A gene-by-condition matrix of the DE test statistic (Wald statistic) from DEseq2
#' @param display Whether or not display the fitting of genes with heavy tails (default is FALSE)
#' @param rand_seed random seed
#'
#' @return A list of the fitting results:
#' \describe{
#'   \item{\code{p_mat}}{The matrix of empirical p-values (gene-by-conditions)}
#'   \item{\code{nulls}}{A data frame for the fitted mean and standard deviations for each gene}
#'   \item{\code{not_fit}}{Genes that were not fitted because the number of non-NA test statistics is fewer than 100 (theoratical null is used)}
#'   \item{\code{qualityMetrics}}{A list of fitting quality metrics, including the genes whose test statistic distribution is heavy tailed (these tails were trimmed prior to fitting) and number of trimmed conditions for the fitting of each gene}
#' }
#'
#'
#' @export fit_empirical_null
#'
#' @author Xuhang Li
#' @examples
#' data(example_stat_table)
#' result <- fit_empirical_null(example_stat_table)

fit_empirical_null <- function(statTbl, display = FALSE, rand_seed = 1126) {
  # display: whether or not display the fitting of data with heavy tails
  set.seed(rand_seed)

  # we require 100 observation to calculate the empirical null
  if (stats::quantile(rowSums(!is.na(statTbl)), 0.1) < 100){
    cat("\033[31mCAUTION: Most genes were not detected in more than 100 conditions!\033[39m\n")
    fil_cutoff = min(c(ncol(statTbl) * 0.9, 100))
    cat('Filtering at minimal',round(fil_cutoff),'conditions ...\n')
    keep = (rowSums(!is.na(statTbl)) >= fil_cutoff)
    ther_null_genes = rownames(statTbl)[!keep]
  }else{
    keep = (rowSums(!is.na(statTbl)) >= 100)
    ther_null_genes = rownames(statTbl)[!keep]
  }

  # empirical null modeling based on Efron's implementation
  emp_pmat = matrix(NA, nrow = nrow(statTbl), ncol = ncol(statTbl))
  colnames(emp_pmat) = colnames(statTbl)
  rownames(emp_pmat) = rownames(statTbl)

  compromisedInd = c()
  ntrim = c()
  emp_mean = c()
  emp_sd = c()
  emp_ind = c()
  for (i in 1:nrow(statTbl)){
    if (keep[i]){ # we consider empirical null
      data = as.numeric(statTbl[i,])

      # remove NA
      nonNAid = which(!is.na(data))
      data = data[nonNAid]

      # the fitting of mixed density function will either fail or skewed if there are extreme and discrete outliers
      # always exclude extreme discrete outliers to avoid bugs

      # define outlier by 3MAD deviation from 1/99% quantile
      qts = stats::quantile(data, c(0.01,0.99))
      upper_loose = qts[2] + 3*stats::mad(data)
      lower_loose = qts[1] - 3*stats::mad(data)

      # trimming outliers
      trimInd = data > lower_loose & data < upper_loose
      data_trim = data[trimInd]
      ntrim = c(ntrim, sum(!trimInd))

      # show the fitting for super heavy tails
      if(sum(data > lower_loose & data < upper_loose) > 0.995 *length(data)){
        showplot = 0 & display
      }else{
        showplot = 1 & display
        compromisedInd = c(compromisedInd, i)
      }

      # set the break size for fitting - this formula was empirically identified
      brk = length(data_trim) %/% 8

      success = FALSE
      step = 0
      suppressWarnings({
        while(!success & step < 100){
          fit = try({lfdr_model_trim = locfdr::locfdr(data_trim, bre = brk,plot = showplot, type = 0)},silent = T)
          if (class(fit) == 'try-error'){
            brk = brk + 1
            step = step + 1
          }else{
            f0_mean = lfdr_model_trim$fp0['mlest','delta']
            f0_sd = lfdr_model_trim$fp0['mlest','sigma']
            emp_mean = c(emp_mean, f0_mean)
            emp_sd = c(emp_sd, f0_sd)
            emp_ind = c(emp_ind, i)

            # calculate empirical pvalue
            lowerT = stats::pnorm(data, mean = f0_mean, sd = f0_sd, lower.tail = TRUE, log.p = FALSE)
            upperT = stats::pnorm(data, mean = f0_mean, sd = f0_sd, lower.tail = FALSE, log.p = FALSE)
            p_data = matrixStats::rowMins(cbind(lowerT, upperT)) * 2

            success = TRUE
          }
        }
      })
      if (step == 100){
        print(paste('maximum break tuning step reaches, using median/mad ... ',rownames(statTbl)[i]))
        # the fitting is failed. we do some compromise
        # we use median and mad as best guess of empirical null
        f0_mean = stats::median(data_trim)
        f0_sd = stats::mad(data_trim)
        emp_mean = c(emp_mean, f0_mean)
        emp_sd = c(emp_sd, f0_sd)
        emp_ind = c(emp_ind, i)
        # empirical pvalue
        lowerT = stats::pnorm(data, mean = f0_mean, sd = f0_sd, lower.tail = TRUE, log.p = FALSE)
        upperT = stats::pnorm(data, mean = f0_mean, sd = f0_sd, lower.tail = FALSE, log.p = FALSE)
        emp_pmat[i,nonNAid] = matrixStats::rowMins(cbind(lowerT, upperT)) * 2
        if (display){
          graphics::hist(data_trim)
          graphics::curve(length(data_trim) * stats::dnorm(x, f0_mean, f0_sd), add=TRUE, col="red", lwd=2)
        }
      }else{
        emp_pmat[i,nonNAid] = p_data
      }
    }else{ # we consider theoretical null
      f0_mean = 0
      f0_sd = 1
      data_trim = as.numeric(statTbl[i,])
      # empirical pvalue
      lowerT = stats::pnorm(data_trim, mean = f0_mean, sd = f0_sd, lower.tail = TRUE, log.p = FALSE)
      upperT = stats::pnorm(data_trim, mean = f0_mean, sd = f0_sd, lower.tail = FALSE, log.p = FALSE)
      emp_pmat[i,] = matrixStats::rowMins(cbind(lowerT, upperT)) * 2
    }
    if (i %% 100 == 0){
      print(paste('fitting #',i,' gene.',sep = ''))
    }
  }

  output = list(p_mat = emp_pmat,
                nulls = data.frame(geneName = rownames(statTbl)[emp_ind],
                                   mean = emp_mean,
                                   sd = emp_sd),
                not_fit = rownames(statTbl)[!keep],
                qualityMetrics = list(heavyTailedGenes = rownames(statTbl)[compromisedInd],
                                      Num_trimmed_outliers = ntrim)
  )
  return(output)
}
