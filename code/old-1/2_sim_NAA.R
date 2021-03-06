# Brian Stock
# June 15 2020
# Simulation test WHAM

# source("/home/bstock/Documents/ms/wham-sim/code/2_sim_NAA.R")

# devtools::install_github("timjmiller/wham", dependencies=TRUE, ref = "om_mode")
library(wham)
library(here)
library(tidyverse)

# Step 1: Fit 4 NAA models to 2019 SNE-MA yellowtail flounder data
# Step 2: Simulate 4 NAA operating models:
#  1. rec 	iid
#  2. rec 	ar1_y
#  3. rec+1 iid
#  4. rec+1 2dar1

# For each OM, simulate using
#  a. obs error only (fix NAA at estimated values)
#  b. obs + process error (new NAA)

# functions to calculate F/F40 and B/B40
calc_relF <- function(mod){
	F.t <- mod$rep$log_FXSPR
	faa <- log(mod$rep$FAA_tot)
  	age.full.f <- apply(faa,1, function(x) max(which(x == max(x))))
  	full.f <- faa[cbind(seq_along(age.full.f),age.full.f)]
	rel.f <- exp(full.f - F.t)
	return(rel.f)
}
calc_relB <- function(mod){
	SSB.t <- exp(mod$rep$log_SSB_FXSPR)
	ssb <- mod$rep$SSB
	rel.ssb <- ssb / SSB.t	
	return(rel.ssb)
}

# Assumes you open R in project directory
# Load fit models from step 1
# mod.list <- here("results","NAA",paste0("m",1:4,".rds"))
# mods <- lapply(mod.list, readRDS)
# input.list <- here("results","NAA",paste0("m",1:4,"_input.rds"))
# inputs <- lapply(input.list, readRDS)

# Simulate models
n.mods <- 4
n.sim <- 1000
mod <- readRDS(here("results","NAA","m1.rds"))
n.years <- length(mod$years)
rm("mod")
n.types <- 2
set.seed(12345)
sim.seeds = sample(1:1000000, n.sim, replace = FALSE) # set random seeds (re-use for each model)
options(warn=-1) # suppress warning messages

res.colnames <- c("om","em","type","year","sim","F","SSB","relF","relB","pred_catch",paste0("NAA",1:6))
# results <- rep(list(rep(list(rep(list(matrix(NA, ncol = length(res.colnames), nrow = n.years)),n.sim)),n.mods)),n.types) # nested lists with preallocated matrices
# results <- matrix(NA, ncol = length(res.colnames), nrow = n.types*n.sim*n.mods*n.years) # one giant preallocated matrix
# colnames(results) <- res.colnames
for(m in 1:n.mods){
	mod <- readRDS(here("results","NAA",paste0("m",m,".rds")))
	input <- readRDS(here("results","NAA",paste0("m",m,"_input.rds")))
	input$par <- mod$env$parList(par=mod$env$last.par.best) # get fit pars
	tmp_a <- tmp_b <- input
	tmp_a$data$simulate_state <- rep(0,4)
	om_a <- fit_wham(tmp_a, do.fit = FALSE)

	for(i in 1:n.sim){
		print(paste0("Model: ",m," Sim: ", i))
		set.seed(sim.seeds[i])
		simdata <- vector("list",2) # save simulated data for cross-tests
		results <- vector("list",2) # save results so don't accumulate large object
		# results <- matrix(NA, ncol = length(res.colnames), nrow = n.types*n.sim*n.mods*n.years)

		# a) obs error, keep all parameters (incl NAA) as in fit model, simulate catch + index data
		tmp_ai <- tmp_a
		simdata[[1]] <- om_a$simulate(par=mod$env$last.par.best, complete=TRUE)
		tmp_ai$data <- simdata[[1]]
		fit_ai <- fit_wham(tmp_ai, do.sdrep=F, do.osa=F, do.retro=F, do.proj=F, MakeADFun.silent=TRUE)
		if(exists("err")) rm("err") # need to clean this up
		df <- as.matrix(data.frame(om=m, em=m, type=1, year=fit_ai$years, sim=i, 
			F=fit_ai$rep$F[,1], SSB=fit_ai$rep$SSB, relF=calc_relF(fit_ai), relB=calc_relB(fit_ai), pred_catch=fit_ai$rep$pred_catch[,1]))
		dfnaa <- fit_ai$rep$NAA; colnames(dfnaa) <- paste0("NAA",1:6)
		# results[seq(((i-1)*n.types*n.years)) + 1:n.years,] <- cbind(df, dfnaa)
		# results <- rbind(results, cbind(df, dfnaa))
		# results[[1]][[m]][[i]] <- cbind(df, dfnaa)
		results[[1]] <- cbind(df, dfnaa)

		# b) process + obs error, keep parameters except NAA as in fit model, simulate NAA (process error) and catch + index data (obs error)
		tmp_bi <- tmp_b
		simdata[[2]] <- mod$simulate(par=mod$env$last.par.best, complete=TRUE)
		tmp_bi$data <- simdata[[2]]
		fit_bi <- fit_wham(tmp_bi, do.sdrep=F, do.osa=F, do.retro=F, do.proj=F, MakeADFun.silent=TRUE)		
		if(exists("err")) rm("err") # need to clean this up
		df <- as.matrix(data.frame(om=m, em=m, type=2, year=fit_bi$years, sim=i, 
			F=fit_bi$rep$F[,1], SSB=fit_bi$rep$SSB, relF=calc_relF(fit_bi), relB=calc_relB(fit_bi), pred_catch=fit_bi$rep$pred_catch[,1]))
		dfnaa <- fit_bi$rep$NAA; colnames(dfnaa) <- paste0("NAA",1:6)
		# results <- rbind(results, cbind(df, dfnaa))
		# results[[2]][[m]][[i]] <- cbind(df, dfnaa)
		results[[2]] <- cbind(df, dfnaa)

		# save simulated data for cross-tests
		saveRDS(results, file=here("results","NAA",paste0("res_om",m,"_sim_",i,".rds")))
		saveRDS(simdata, file=here("data","simdata","SNEMAYT","NAA",paste0("om",m,"_sim_",i,".rds")))
		# rm(list=c("simdata","fit_ai","fit_bi","df","dfnaa"))
		rm(list=c("simdata","fit_ai","fit_bi","df","dfnaa","results"))
	}
	rm(list=c("mod","input"))
}
# saveRDS(results, file=here("results","NAA","results.rds"))

# un-suppress warnings
options(warn=0)
