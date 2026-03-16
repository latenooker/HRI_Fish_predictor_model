# =============================================================================
# 06_model_spAbundance.R
# Multi-species spatial abundance models using spAbundance
#
# Fits Bayesian multi-species GLMMs with spatial random effects (NNGP) to
# jointly model coral reef response variables as a function of bathymetric
# and oceanographic predictors along the Belize Barrier Reef.
#
# "Species" in this context are the 4 response variables:
#   1. Coral cover (%)
#   2. Fleshy macroalgae cover (%)
#   3. Commercial fish biomass (g/100m²)
#   4. Herbivorous fish biomass (g/100m²)
#
# Models fit (in order of complexity):
#   M1: msAbund     — non-spatial multi-species GLMM
#   M2: sfMsAbund   — spatial factor multi-species GLMM (NNGP)
#
# Input:  data/external/HRI_all_variables.csv
# Output: results/tables/model_*  — posterior summaries
#         results/figures/model_*  — diagnostics and effect plots
#
# Requires: spAbundance, coda
# =============================================================================

library(here)
library(tidyverse)
library(spAbundance)
library(coda)

set.seed(42)

# --- Output directories -------------------------------------------------------
fig_dir   <- here("results", "figures")
table_dir <- here("results", "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# 1. DATA PREPARATION
# =============================================================================

message("=== Loading and preparing data ===")

dat <- read.csv(here("data", "external", "HRI_all_variables.csv"))

# Rename columns for clarity
dat <- dat %>%
  rename(
    lon        = Longitude_,
    lat        = Latitude_y,
    coral      = Coral_cove,
    algae      = Algae_cove,
    fish_comm  = Commercial,
    fish_herb  = Herbivorou,
    bathy      = depth
  )

# Drop incomplete cases (response NAs are only in coral/algae)
dat_complete <- dat %>%
  filter(complete.cases(coral, algae, fish_comm, fish_herb))

message("  Complete cases: ", nrow(dat_complete), " of ", nrow(dat))

# --- Response matrix: species (rows) x sites (columns) -----------------------
# Log-transform biomass (right-skewed, spans orders of magnitude)
# Leave cover on natural scale (roughly normal after site averaging)
y_mat <- rbind(
  coral     = dat_complete$coral,
  algae     = dat_complete$algae,
  fish_comm = log(dat_complete$fish_comm + 1),
  fish_herb = log(dat_complete$fish_herb + 1)
)

n_species <- nrow(y_mat)
n_sites   <- ncol(y_mat)
message("  Species: ", n_species, ", Sites: ", n_sites)

# --- Coordinates matrix: sites x 2 -------------------------------------------
# Project from lat/lon to UTM Zone 16N (EPSG:32616) for proper distance calcs.
# Simple approximation: convert degrees to km (sufficient for NNGP)
lon_center <- mean(dat_complete$lon)
lat_center <- mean(dat_complete$lat)

coords <- cbind(
  x = (dat_complete$lon - lon_center) * 111.32 * cos(lat_center * pi / 180),
  y = (dat_complete$lat - lat_center) * 110.57
)

message("  Spatial extent: ",
        round(diff(range(coords[, 1])), 1), " x ",
        round(diff(range(coords[, 2])), 1), " km")

# --- Predictor covariates -----------------------------------------------------
# Select non-collinear predictors (from EDA: removed curv_plan, slopeslo_1, slope_240)
covs <- dat_complete %>%
  select(
    bathy,                # bathymetry (depth, negative = deeper)
    slope,                # terrain slope
    aspect_cos,           # cosine of aspect (N-S exposure)
    aspect_sin,           # sine of aspect (E-W exposure)
    aspect_std,           # aspect standard deviation (terrain roughness proxy)
    slopeslope,           # slope of slope (terrain complexity)
    aspect_10m,           # aspect at 10m resolution
    aspect_s_1            # aspect × std curvature interaction
  ) %>%
  as.data.frame()

message("  Predictors: ", paste(names(covs), collapse = ", "))

# Names for output labeling
species_names <- c("Coral cover", "Macroalgae cover",
                   "Commercial fish (log)", "Herbivorous fish (log)")
predictor_names <- c("Intercept", "Depth", "Depth²",
                     "Slope", "Aspect (N-S)", "Aspect (E-W)",
                     "Terrain roughness")

# --- Assemble spAbundance data list ------------------------------------------
sp_data <- list(
  y      = y_mat,
  covs   = covs,
  coords = coords
)

# =============================================================================
# 2. MODEL FORMULA
# =============================================================================

# Scale all continuous predictors. Key hypotheses:
#   - bathy: deeper reefs may serve as refugia (quadratic for optimum depth)
#   - slope: steeper slopes = more current exposure, different communities
#   - aspect_cos/sin: exposure to prevailing currents/waves
#   - aspect_std: terrain roughness as habitat complexity proxy
ms_formula <- ~ scale(bathy) + I(scale(bathy)^2) +
  scale(slope) + scale(aspect_cos) + scale(aspect_sin) +
  scale(aspect_std)

# Number of regression coefficients (intercept + 6 predictors)
n_beta <- 7

# =============================================================================
# 3. MODEL 1: NON-SPATIAL MULTI-SPECIES GLMM (msAbund)
# =============================================================================

message("\n=== Fitting M1: Non-spatial multi-species GLMM (msAbund) ===")

# --- MCMC settings (short run for initial diagnostics) ------------------------
n_batch_m1      <- 400
batch_length_m1 <- 25
n_samples_m1    <- n_batch_m1 * batch_length_m1  # 10,000
n_burn_m1       <- 5000
n_thin_m1       <- 5
n_chains_m1     <- 3

# --- Priors -------------------------------------------------------------------
priors_m1 <- list(
  beta.comm.normal  = list(mean = 0, var = 100),   # community-level coeff means
  tau.sq.beta.ig    = list(a = 0.1, b = 0.1),      # community-level coeff variances
  sigma.sq.mu.ig    = list(a = 2, b = 1)            # residual variance hyperprior
)

# --- Initial values -----------------------------------------------------------
inits_m1 <- list(
  beta.comm  = rep(0, n_beta),
  beta       = matrix(0, nrow = n_species, ncol = n_beta),
  tau.sq.beta = rep(1, n_beta),
  sigma.sq   = rep(1, n_species)
)

# --- Tuning -------------------------------------------------------------------
tuning_m1 <- list(
  beta      = 0.1,
  beta.comm = 0.1,
  sigma.sq  = 0.5
)

# --- Fit ----------------------------------------------------------------------
t1 <- system.time({
  m1 <- msAbund(
    formula      = ms_formula,
    data         = sp_data,
    inits        = inits_m1,
    priors       = priors_m1,
    tuning       = tuning_m1,
    family       = "Gaussian",
    n.batch      = n_batch_m1,
    batch.length = batch_length_m1,
    n.burn       = n_burn_m1,
    n.thin       = n_thin_m1,
    n.chains     = n_chains_m1,
    n.report     = 100,
    verbose      = TRUE
  )
})
message("  M1 elapsed: ", round(t1[3], 1), "s")

# --- Diagnostics --------------------------------------------------------------
message("  M1 summary:")
m1_summary <- summary(m1)
print(m1_summary)

# Rhat check (requires mcmc.list with >= 2 chains)
beta_comm_samples <- m1$beta.comm.samples
if (inherits(beta_comm_samples, "mcmc.list") && length(beta_comm_samples) >= 2) {
  rhat_vals <- gelman.diag(beta_comm_samples, multivariate = FALSE)
  message("  Max Rhat (beta.comm): ", round(max(rhat_vals$psrf[, 1]), 3))
} else {
  message("  Rhat: skipped (need mcmc.list with >=2 chains, got ",
          class(beta_comm_samples)[1], ")")
}

# Trace plots for community-level coefficients
png(file.path(fig_dir, "model_m1_trace_beta_comm.png"),
    width = 12, height = 8, units = "in", res = 200)
plot(beta_comm_samples, density = FALSE)
dev.off()

# Residual diagnostics (ppcAbund not supported for Gaussian; use direct residuals)
if (!is.null(m1$y.rep.samples)) {
  y_rep_mean <- apply(m1$y.rep.samples, c(2, 3), mean)  # species x sites
  resid_m1   <- y_mat - y_rep_mean

  png(file.path(fig_dir, "model_m1_residuals.png"),
      width = 10, height = 8, units = "in", res = 200)
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  for (i in 1:n_species) {
    hist(resid_m1[i, ], breaks = 30, col = "gray70", border = "white",
         main = species_names[i], xlab = "Residual")
  }
  dev.off()

  message("  M1 residual SD by species: ",
          paste(round(apply(resid_m1, 1, sd), 2), collapse = ", "))
} else {
  message("  M1 y.rep.samples not available (save.fitted may be FALSE)")
}

# =============================================================================
# 4. MODEL 2: SPATIAL FACTOR MULTI-SPECIES GLMM (sfMsAbund)
# =============================================================================

message("\n=== Fitting M2: Spatial factor multi-species GLMM (sfMsAbund) ===")

# --- MCMC settings (longer for spatial model) ---------------------------------
n_batch_m2      <- 800
batch_length_m2 <- 25
n_samples_m2    <- n_batch_m2 * batch_length_m2  # 20,000
n_burn_m2       <- 10000
n_thin_m2       <- 10
n_chains_m2     <- 3
n_factors       <- 2    # latent spatial factors (captures species correlations)

# --- Spatial parameters -------------------------------------------------------
# Effective spatial range: 3/phi. With coords in km, phi.unif bounds set
# min range ~ 3km (3/1.0), max range ~ 300km (3/0.01) — spans reef to barrier scale
priors_m2 <- list(
  beta.comm.normal = list(mean = 0, var = 100),
  tau.sq.beta.ig   = list(a = 0.1, b = 0.1),
  sigma.sq.mu.ig   = list(a = 2, b = 1),
  phi.unif         = list(a = 0.01, b = 1.0),    # spatial decay
  sigma.sq.ig      = list(a = 2, b = 1)           # spatial variance
)

inits_m2 <- list(
  beta.comm   = rep(0, n_beta),
  beta        = matrix(0, nrow = n_species, ncol = n_beta),
  tau.sq.beta = rep(1, n_beta),
  sigma.sq    = rep(1, n_species),
  phi         = rep(0.3, n_factors),
  sigma.sq.mu = rep(1, n_factors)
)

tuning_m2 <- list(
  beta      = 0.1,
  beta.comm = 0.1,
  sigma.sq  = 0.5,
  phi       = 0.5
)

# --- Fit ----------------------------------------------------------------------
t2 <- system.time({
  m2 <- sfMsAbund(
    formula      = ms_formula,
    data         = sp_data,
    inits        = inits_m2,
    priors       = priors_m2,
    tuning       = tuning_m2,
    cov.model    = "exponential",
    NNGP         = TRUE,
    n.neighbors  = 15,
    n.factors    = n_factors,
    family       = "Gaussian",
    n.batch      = n_batch_m2,
    batch.length = batch_length_m2,
    n.burn       = n_burn_m2,
    n.thin       = n_thin_m2,
    n.chains     = n_chains_m2,
    n.report     = 100,
    verbose      = TRUE
  )
})
message("  M2 elapsed: ", round(t2[3], 1), "s")

# --- Diagnostics --------------------------------------------------------------
message("  M2 summary:")
m2_summary <- summary(m2)
print(m2_summary)

beta_comm_m2 <- m2$beta.comm.samples
if (inherits(beta_comm_m2, "mcmc.list") && length(beta_comm_m2) >= 2) {
  rhat_m2 <- gelman.diag(beta_comm_m2, multivariate = FALSE)
  message("  Max Rhat (beta.comm): ", round(max(rhat_m2$psrf[, 1]), 3))
} else {
  message("  Rhat: skipped (got ", class(beta_comm_m2)[1], ")")
}

png(file.path(fig_dir, "model_m2_trace_beta_comm.png"),
    width = 12, height = 8, units = "in", res = 200)
plot(beta_comm_m2, density = FALSE)
dev.off()

# Residual diagnostics for M2
if (!is.null(m2$y.rep.samples)) {
  y_rep_mean_m2 <- apply(m2$y.rep.samples, c(2, 3), mean)
  resid_m2      <- y_mat - y_rep_mean_m2

  png(file.path(fig_dir, "model_m2_residuals.png"),
      width = 10, height = 8, units = "in", res = 200)
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  for (i in 1:n_species) {
    hist(resid_m2[i, ], breaks = 30, col = "gray70", border = "white",
         main = species_names[i], xlab = "Residual")
  }
  dev.off()

  # Observed vs fitted
  png(file.path(fig_dir, "model_m2_obs_vs_fitted.png"),
      width = 10, height = 8, units = "in", res = 200)
  par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  for (i in 1:n_species) {
    plot(y_rep_mean_m2[i, ], y_mat[i, ], pch = 16, cex = 0.6,
         col = adjustcolor("#2C3E50", 0.5),
         xlab = "Fitted", ylab = "Observed", main = species_names[i])
    abline(0, 1, col = "red", lty = 2)
  }
  dev.off()

  message("  M2 residual SD by species: ",
          paste(round(apply(resid_m2, 1, sd), 2), collapse = ", "))
}

# =============================================================================
# 5. MODEL COMPARISON
# =============================================================================

message("\n=== Model comparison (WAIC) ===")

waic_results <- tryCatch({
  waic_m1 <- waicAbund(m1)
  waic_m2 <- waicAbund(m2)

  waic_table <- tibble(
    model = c("M1: Non-spatial", "M2: Spatial (NNGP)"),
    WAIC  = c(waic_m1$WAIC, waic_m2$WAIC),
    pWAIC = c(waic_m1$p.eff, waic_m2$p.eff),
    lppd  = c(waic_m1$lppd, waic_m2$lppd)
  )
  print(waic_table)

  write.csv(waic_table, file.path(table_dir, "model_comparison_waic.csv"),
            row.names = FALSE)
  waic_table
}, error = function(e) {
  message("  WAIC computation failed: ", e$message)
  message("  (This can happen with Gaussian models; comparing via residual variance instead)")

  # Fall back to residual variance comparison
  resid_sd_m1 <- if (!is.null(m1$y.rep.samples)) {
    apply(y_mat - apply(m1$y.rep.samples, c(2, 3), mean), 1, sd)
  } else rep(NA, n_species)
  resid_sd_m2 <- if (!is.null(m2$y.rep.samples)) {
    apply(y_mat - apply(m2$y.rep.samples, c(2, 3), mean), 1, sd)
  } else rep(NA, n_species)

  comp <- tibble(
    species    = species_names,
    resid_sd_m1 = round(resid_sd_m1, 3),
    resid_sd_m2 = round(resid_sd_m2, 3)
  )
  print(comp)
  write.csv(comp, file.path(table_dir, "model_comparison_residuals.csv"),
            row.names = FALSE)
  NULL
})

# =============================================================================
# 6. EXTRACT AND VISUALIZE RESULTS
# =============================================================================

message("\n=== Extracting results from best model ===")

# Use spatial model (M2) for results
best_model <- m2

# Helper: extract matrix from mcmc or mcmc.list
as_matrix <- function(x) {
  if (inherits(x, "mcmc.list")) do.call(rbind, x)
  else if (inherits(x, "mcmc")) as.matrix(x)
  else as.matrix(x)
}

# --- Species-specific coefficients -------------------------------------------
beta_combined <- as_matrix(best_model$beta.samples)

# Reshape: columns are species_1_pred_1, species_1_pred_2, ..., species_n_pred_p
beta_summary <- tibble(
  species   = rep(species_names, each = n_beta),
  predictor = rep(predictor_names, times = n_species),
  mean      = colMeans(beta_combined),
  sd        = apply(beta_combined, 2, sd),
  q025      = apply(beta_combined, 2, quantile, 0.025),
  q500      = apply(beta_combined, 2, quantile, 0.5),
  q975      = apply(beta_combined, 2, quantile, 0.975),
  sig       = ifelse(sign(q025) == sign(q975), "*", "")
)

print(beta_summary, n = 40)

write.csv(beta_summary, file.path(table_dir, "model_beta_species.csv"),
          row.names = FALSE)

# --- Community-level coefficients --------------------------------------------
beta_comm_combined <- as_matrix(best_model$beta.comm.samples)

beta_comm_summary <- tibble(
  predictor = predictor_names,
  mean      = colMeans(beta_comm_combined),
  sd        = apply(beta_comm_combined, 2, sd),
  q025      = apply(beta_comm_combined, 2, quantile, 0.025),
  q500      = apply(beta_comm_combined, 2, quantile, 0.5),
  q975      = apply(beta_comm_combined, 2, quantile, 0.975),
  sig       = ifelse(sign(q025) == sign(q975), "*", "")
)

print(beta_comm_summary)

write.csv(beta_comm_summary, file.path(table_dir, "model_beta_community.csv"),
          row.names = FALSE)

# --- Plot: Species-specific coefficient estimates (caterpillar plot) ----------
coef_plot_data <- beta_summary %>%
  filter(predictor != "Intercept")

p_coef <- ggplot(coef_plot_data,
       aes(x = mean, y = predictor, xmin = q025, xmax = q975, color = species)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_pointrange(position = position_dodge(width = 0.6), size = 0.4) +
  scale_color_brewer(palette = "Dark2") +
  labs(x = "Posterior mean (95% CI)", y = NULL, color = "Response",
       title = "Species-Specific Coefficient Estimates") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    legend.position = "bottom"
  )

ggsave(file.path(fig_dir, "model_coefficients.png"), p_coef,
       width = 10, height = 7, dpi = 300)

# --- Plot: Community-level coefficients ---------------------------------------
p_comm <- ggplot(beta_comm_summary %>% filter(predictor != "Intercept"),
       aes(x = mean, y = predictor, xmin = q025, xmax = q975)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_pointrange(color = "#2C3E50", size = 0.6) +
  labs(x = "Posterior mean (95% CI)", y = NULL,
       title = "Community-Level Coefficient Estimates") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5))

ggsave(file.path(fig_dir, "model_community_coefficients.png"), p_comm,
       width = 8, height = 5, dpi = 300)

# --- Species correlation matrix from latent factors --------------------------
# The factor loadings (lambda) encode species correlations
# Species correlation = lambda %*% t(lambda) + diag(sigma.sq)
lambda_combined <- as_matrix(best_model$lambda.samples)
lambda_mean <- matrix(colMeans(lambda_combined),
                      nrow = n_species, ncol = n_factors)

# Correlation from loadings
cov_from_lambda <- lambda_mean %*% t(lambda_mean)
diag_sigma <- colMeans(as_matrix(best_model$sigma.sq.samples))
cov_total  <- cov_from_lambda + diag(diag_sigma)
cor_species <- cov2cor(cov_total)
rownames(cor_species) <- species_names
colnames(cor_species) <- species_names

message("\n  Estimated species correlation matrix:")
print(round(cor_species, 3))

png(file.path(fig_dir, "model_species_correlations.png"),
    width = 7, height = 6, units = "in", res = 300)
corrplot::corrplot(cor_species, method = "number", type = "upper",
                   diag = FALSE, number.cex = 1.0, tl.cex = 0.9,
                   tl.col = "black",
                   col = colorRampPalette(c("#E74C3C", "white", "#2C3E50"))(200),
                   title = "Estimated Species Correlations (Latent Factors)",
                   mar = c(0, 0, 2, 0))
dev.off()

# =============================================================================
# 7. SPATIAL PREDICTION SURFACE (out-of-sample)
# =============================================================================

message("\n=== Generating prediction surface ===")

# Predict at all 267 external data sites (including those with NA responses)
dat_pred <- dat %>%
  select(lon, lat, bathy, slope, aspect_cos, aspect_sin, aspect_std,
         slopeslope, aspect_10m, aspect_s_1)

pred_covs <- data.frame(
  bathy      = dat_pred$bathy,
  slope      = dat_pred$slope,
  aspect_cos = dat_pred$aspect_cos,
  aspect_sin = dat_pred$aspect_sin,
  aspect_std = dat_pred$aspect_std,
  slopeslope = dat_pred$slopeslope,
  aspect_10m = dat_pred$aspect_10m,
  aspect_s_1 = dat_pred$aspect_s_1
)

pred_coords <- cbind(
  x = (dat_pred$lon - lon_center) * 111.32 * cos(lat_center * pi / 180),
  y = (dat_pred$lat - lat_center) * 110.57
)

pred_data <- list(
  covs   = pred_covs,
  coords = pred_coords
)

pred_df <- tryCatch({
  preds_out <- predict(best_model, pred_data)

  # Extract posterior mean predictions for each species at each site
  pred_means <- apply(preds_out$y.0.samples, c(2, 3), mean)

  tibble(
    lon       = dat_pred$lon,
    lat       = dat_pred$lat,
    coral     = pred_means[1, ],
    algae     = pred_means[2, ],
    fish_comm = exp(pred_means[3, ]) - 1,
    fish_herb = exp(pred_means[4, ]) - 1
  )
}, error = function(e) {
  message("  Prediction failed: ", e$message)
  message("  Using fitted values from training data instead")

  if (!is.null(best_model$y.rep.samples)) {
    fitted_means <- apply(best_model$y.rep.samples, c(2, 3), mean)
    tibble(
      lon       = dat_complete$lon,
      lat       = dat_complete$lat,
      coral     = fitted_means[1, ],
      algae     = fitted_means[2, ],
      fish_comm = exp(fitted_means[3, ]) - 1,
      fish_herb = exp(fitted_means[4, ]) - 1
    )
  } else {
    message("  No fitted values available either")
    NULL
  }
})

if (!is.null(pred_df)) {

write.csv(pred_df, file.path(table_dir, "model_predictions.csv"),
          row.names = FALSE)

# --- Prediction maps ----------------------------------------------------------
pred_long <- pred_df %>%
  pivot_longer(coral:fish_herb, names_to = "variable", values_to = "predicted") %>%
  mutate(variable = recode(variable,
    coral     = "Coral cover (%)",
    algae     = "Macroalgae cover (%)",
    fish_comm = "Commercial fish (g/100m²)",
    fish_herb = "Herbivorous fish (g/100m²)"
  ))

p_pred <- ggplot(pred_long, aes(x = lon, y = lat, color = predicted)) +
  geom_point(size = 1.5, alpha = 0.8) +
  scale_color_viridis_c(option = "C") +
  facet_wrap(~variable, scales = "free", ncol = 2) +
  labs(x = "Longitude", y = "Latitude", color = "Predicted",
       title = "Spatial Predictions — Multi-Species Model") +
  coord_quickmap() +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 16),
    strip.text = element_text(face = "bold"),
    legend.position = "right"
  )

ggsave(file.path(fig_dir, "model_prediction_maps.png"), p_pred,
       width = 12, height = 10, dpi = 300)

} # end if (!is.null(pred_df))

# =============================================================================
# 8. SAVE MODEL OBJECTS
# =============================================================================

save(m1, m2, sp_data, file = here("R_workspaces", "spAbundance_models.RData"))
message("\n=== Model fitting complete ===")
message("  Model objects saved to: R_workspaces/spAbundance_models.RData")
message("  Figures: results/figures/model_*")
message("  Tables:  results/tables/model_*")
