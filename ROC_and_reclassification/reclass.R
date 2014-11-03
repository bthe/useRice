
##############################################################################################
# reclass function
# 
# Calculates NRI and IDI measures  					
#										
# Description:									
# The reclass function calculates the NRI and IDI, which are measures that	
# compare discrimination ability between two logistic regression prediction	 
# models. The function assumes a binary dependent variable and two sets	
# of numerical and/or categorical covariates for the two models. For		
# calculation of NRI the cutoff	probabilities separating risk categories are 
# input paramaters. Output are estimated NRI and IDI with standard errors and 
# p values for test of the null	hypotheses that each measure in the population 
# is zero. Optional output is	the reclassification table for NRI and the c statistics.
# The Design package by Frank Harrell is required to run the function.						
#						
# Usage:
# reclass(f, data, lim, npred, tab)
#
# f         Model formula for logistic regression. Full model including new predictor(s). These 
#           should be placed at the end of the formula. If several new predictors are included 
#           in the model the number of new predictors should be given with argument npred. 
#           Example of model: Y ~ X1 + X2 + X3 + NEWPRED1 + NEWPRED2  (set npred to 2)
#
# data      Dataframe 
#
# lim       Vector containing limits (in the interval 0-1) for clinically relevant risk strata. 
#           Example: c(0.06, 0.20) to indicate strata <6%, 6-20%, >=20%
#
# npred     Number of new predictors in full model. Defaults to 1.
#
# tab       Set to TRUE to include printout of reclassification table and c statistics for
#           old and new model. Defaults to FALSE.
#
# Value:
# A list with the following named elements 
# reclass.table.with.outcome        Reclassification table for subjects who experienced the outcome
# reclass.table.without.outcome     Reclassification table for subjects who did not experience the outcome
# Cindex.old                        C index (area under ROC curve) for original model
# Cindex.new                        C index (area under ROC curve) for model with new predictor(s) added
# NRI                               Net reclassification improvement (NRI)
# SE.NRI                            Standard error for NRI
# pval.NRI                          P value for NRI
# IDI                               Integrated discrimination improvement (IDI)
# SE.IDI                            Standard error for IDI
# pval.IDI                          P value for IDI
#
# Author:
# Rolf Gedeborg, Dept of Surgical Sciences & UCR, Uppsala University
# (rolf.gedeborg@surgsci.uu.se) using R ver 2.9.2       Ver 2011-09-27
#
# Reference: 
# Pencina MJ, D' Agostino RB Sr, D' Agostino RB Jr, Vasan RS.	Evaluating the added predictive ability of a 
# new marker: From area under the ROC curve to reclassification and beyond. 
# Stat Med. 2008 Jan 30 27(2):157-72 discussion 207-12.
#             
##############################################################################################


reclass <- function(f, data, lim, npred = 1, tab = FALSE) {
  
  # Create labels for classes
  c.first <- paste("<", lim[1] * 100, "%", sep = "")
  c.last <- paste(">=", lim[length(lim)] * 100, "%", sep = "")
  
  if(length(lim) > 1) {
    c.lab <- character(length(lim) - 1)
    for(i in 1:(length(lim) - 1)) c.lab[i] <- paste(lim[i] * 100, "-", (lim[i+1] - 0.01) * 100, "%", sep = "")
    c.lab <- c(c.first, c.lab, c.last)  
  }
  
  if(length(lim) == 1) {
    c.lab <- character(length(lim) - 1)
    for(i in 1:(length(lim) - 1)) c.lab[i] <- paste(lim[i] * 100, "-", (lim[i+1] - 0.01) * 100, "%", sep = "")
    c.lab <- c(c.first, c.last)  
  }
  
  # Extract formula without new predictor(s)
  f.nopred <- as.formula(paste(all.vars(f)[1], "~", paste(all.vars(f)[2:(length(all.vars(f)) - npred)], collapse ="+")))
  
  require(rms)
  # Fit basic model without new predictor(s)
  fit.old <- glm(f.nopred, data = data, family = "binomial")
  data$pred.old <- predict(fit.old, newdata = data, type = "response")
  cind.old <- somers2(data$pred.old, data[, names(data)==all.vars(f)[1]])["C"]
  
  # Fit new model with new predictor(s)
  fit.new <- glm(f, data = data, family = "binomial")
  data$pred.new <- predict(fit.new, newdata = data, type = "response")
  cind.new <- somers2(data$pred.new, data[, names(data)==all.vars(f)[1]])["C"]
  
  # Create new empty matrix
  mx1 <- numeric(nrow(data)); mx2 <- numeric(nrow(data)); mx3 <- numeric(nrow(data)); mx4 <- numeric(nrow(data))
  
  # Create matrix with reclassification results
  for(i in 1:length(lim)) { 
    mx1 <- cbind(mx1, ifelse(data[, names(data)==all.vars(f)[1]] == 1 & data$pred.new > data$pred.old & rep(lim[i], nrow(data)) > data$pred.old & 
                               rep(lim[i], nrow(data)) <= data$pred.new, 1, 0))
    mx2 <- cbind(mx2, ifelse(data[, names(data)==all.vars(f)[1]] == 1 & data$pred.new < data$pred.old & rep(lim[i], nrow(data)) < data$pred.old & 
                               rep(lim[i], nrow(data)) >= data$pred.new, 1, 0))
    mx3 <- cbind(mx3, ifelse(data[, names(data)==all.vars(f)[1]] == 0 & data$pred.new > data$pred.old & rep(lim[i], nrow(data)) > data$pred.old & 
                               rep(lim[i], nrow(data)) <= data$pred.new, 1, 0))
    mx4 <- cbind(mx4, ifelse(data[, names(data)==all.vars(f)[1]] == 0 & data$pred.new < data$pred.old & rep(lim[i], nrow(data)) < data$pred.old & 
                               rep(lim[i], nrow(data)) >= data$pred.new, 1, 0))                                                                            
  }
  
  phat.up.ev <- sum(ifelse(rowSums(mx1) > 0, 1, 0)) / sum(data[, names(data)==all.vars(f)[1]])
  phat.down.ev <- sum(ifelse(rowSums(mx2) > 0, 1, 0)) / sum(data[, names(data)==all.vars(f)[1]])
  phat.up.nonev <- sum(ifelse(rowSums(mx3) > 0, 1, 0)) / (nrow(data) - sum(data[, names(data)==all.vars(f)[1]]))
  phat.down.nonev <- sum(ifelse(rowSums(mx4) > 0, 1, 0)) / (nrow(data) - sum(data[, names(data)==all.vars(f)[1]]))
  
  # Calculate NRI
  NRI <- (phat.up.ev - phat.down.ev) - (phat.up.nonev - phat.down.nonev)      
  
  # Test for NRI
  se.nri <- sqrt(((phat.up.ev + phat.down.ev) / sum(data[, names(data)==all.vars(f)[1]])) + 
                   ((phat.up.nonev + phat.down.nonev) / (nrow(data) - sum(data[, names(data)==all.vars(f)[1]]))))
  z.nri <- NRI / se.nri
  
  p.nri <- 2 * (1 - pnorm(abs(z.nri)))
  
  # Create reclassification table...
  data$old.class <- cut(data$pred.old, breaks = c(0, lim, 1), right = TRUE, include.lowest = TRUE, labels = c.lab)
  data$new.class <- cut(data$pred.new, breaks = c(0, lim, 1), right = TRUE, include.lowest = TRUE, labels = c.lab)
  
  label(data$old.class) <- "Old classification"
  label(data$new.class) <- "New classification"
  
  # ...for those with outcome var=1
  data.1 <- subset(data, data[, names(data)==all.vars(f)[1]] == 1)
  Old_classification <- data.1$old.class
  New_classification <- data.1$new.class
  t1 <- addmargins(table(Old_classification, New_classification))
  
  # ...for those with outcome var=0
  data.2 <- subset(data, data[, names(data)==all.vars(f)[1]] == 0)
  Old_classification <- data.2$old.class
  New_classification <- data.2$new.class
  t2 <- addmargins(table(Old_classification, New_classification))
  
  # Calculate IDI
  IDI <- (mean(data$pred.new[data[, names(data)==all.vars(f)[1]] == 1]) - 
            mean(data$pred.old[data[, names(data)==all.vars(f)[1]] == 1])) - 
    (mean(data$pred.new[data[, names(data)==all.vars(f)[1]] == 0]) - 
       mean(data$pred.old[data[, names(data)==all.vars(f)[1]] == 0])); IDI
  
  # Test for IDI
  se.idi <- sqrt((sd(data$pred.new[data[, names(data)==all.vars(f)[1]] == 1] - 
                       data$pred.old[data[, names(data)==all.vars(f)[1]] == 1])^2 / 
                    nrow(data[data[, names(data)==all.vars(f)[1]] == 1, ])) + 
                   (sd(data$pred.new[data[, names(data)==all.vars(f)[1]] == 0] - 
                         data$pred.old[data[, names(data)==all.vars(f)[1]] == 0])^2 / 
                      nrow(data[data[, names(data)==all.vars(f)[1]] == 0, ])))
  z.idi <- IDI / se.idi
  
  p.idi <- 2 * (1 - pnorm(abs(z.idi))); p.idi
  
  result2 <- list(reclass.table.with.outcome=t1, reclass.table.without.outcome=t2,
                  reclass.outcome=(phat.up.ev - phat.down.ev),
                  reclass.without.outcome=(phat.up.nonev - phat.down.nonev), 
                  Cindex.old=cind.old,
                  Cindex.new=cind.new, NRI=NRI, SE.NRI=se.nri, pval.NRI=p.nri, IDI=IDI, SE.IDI=se.idi, 
                  pval.IDI=p.idi)
  result3 <- list(NRI=NRI, SE.NRI=se.nri, pval.NRI=p.nri, IDI=IDI, SE.IDI=se.idi, pval.IDI=p.idi)
  
  if(tab == TRUE) return(result2)  
  if(tab == FALSE) return(result3)
}
