# =============================================================================
# 08_model_species_spAbundance.R
# Species-level multi-species spatial abundance models using spAbundance
#
# Models individual fish families (7) plus benthic cover (2) as 9 "species"
# in a joint multi-species framework, replacing the grouped commercial/
# herbivorous totals from 06_model_spAbundance.R.
#
# Species (9):
#   1. Coral cover (%)
#   2. Fleshy macroalgae cover (%)
#   3. Snappers — Lutjanidae (tLUTJavg, g/100m²)
#   4. Groupers — Serranidae (tSERRavg)
#   5. Jacks — Carangidae (tCARAavg)
#   6. Barracuda — Sphyraenidae (tSPHYavg)
#   7. Grunts — Haemulidae (tHAEMavg)
#   8. Surgeonfish — Acanthuridae (tACANavg)
#   9. Parrotfish — Scaridae (tSCARavg)
#
# Models:
#   M1: msAbund     — non-spatial multi-species GLMM
#   M2: sfMsAbund   — spatial factor NNGP (3 latent factors for 9 species)
#
# Input:  results/tables/ResponseVariables_full.csv
#         data/external/HRI_all_variables.csv
# Output: results/tables/species_model_*
#         results/figures/species_model_*
#         R_workspaces/spAbundance_species_models.RData
#
# Requires: spAbundance, coda, corrplot
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

message("=== Loading and preparing species-level data ===")

# --- Load individual species data (site x year) ------------------------------
full <- read.csv(here("results", "tables", "ResponseVariables_full.csv"))

# Species columns
fish_cols <- c("tLUTJavg", "tSERRavg", "tCARAavg", "tSPHYavg", "tHAEMavg",
               "tACANavg", "tSCARavg")

# Compute site-level averages across years (including individual species)
site_avg <- full %>%
  group_by(Name, Latitude, Longitude) %>%
  summarise(
    tCORALavg = mean(tCORALavg, na.rm = TRUE),
    tFMAavg   = mean(tFMAavg, na.rm = TRUE),
    across(all_of(fish_cols), ~mean(.x, na.rm = TRUE)),
    .groups = "drop"
  )

message("  Site-level averages: ", nrow(site_avg), " sites")

# --- Load predictor data and merge on coordinates ----------------------------
hri <- read.csv(here("data", "external", "HRI_all_variables.csv"))

dat <- site_avg %>%
  inner_join(
    hri %>% rename(Longitude = Longitude_, Latitude = Latitude_y),
    by = c("Longitude", "Latitude")
  )

message("  Matched with predictors: ", nrow(dat), " sites")

# --- Drop incomplete cases ---------------------------------------------------
response_cols <- c("tCORALavg", "tFMAavg", fish_cols)
dat_complete <- dat %>%
  filter(if_all(all_of(response_cols), ~!is.na(.x) & is.finite(.x)))

message("  Complete cases: ", nrow(dat_complete), " of ", nrow(dat))

# --- Response matrix: species (rows) x sites (columns) -----------------------
# Log-transform fish biomass (right-skewed, spans orders of magnitude)
# Leave benthic cover on natural scale (roughly normal after site averaging)
y_mat <- rbind(
  coral      = dat_complete$tCORALavg,
  algae      = dat_complete$tFMAavg,
  snappers   = log(dat_complete$tLUTJavg + 1),
  groupers   = log(dat_complete$tSERRavg + 1),
  jacks      = log(dat_complete$tCARAavg + 1),
  barracuda  = log(dat_complete$tSPHYavg + 1),
  grunts     = log(dat_complete$tHAEMavg + 1),
  surgeonfish = log(dat_complete$tACANavg + 1),
  parrotfish = log(dat_complete$tSCARavg + 1)
)

n_species <- nrow(y_mat)
n_sites   <- ncol(y_mat)
message("  Species: ", n_species, ", Sites: ", n_sites)

# --- Coordinates matrix: sites x 2 -------------------------------------------
lon_center <- mean(dat_complete$Longitude)
lat_center <- mean(dat_complete$Latitude)

coords <- cbind(
  x = (dat_complete$Longitude - lon_center) * 111.32 * cos(lat_center * pi / 180),
  y = (dat_complete$Latitude - lat_center) * 110.57
)

message("  Spatial extent: ",
        round(diff(range(coords[, 1])), 1), " x ",
        round(diff(range(coords[, 2])), 1), " km")

# --- Predictor covariates (same as grouped model) ----------------------------
covs <- dat_complete %>%
  select(depth, slope, aspect_cos, aspect_sin, aspect_std, slopeslope) %>%
  as.data.frame()

message("  Predictors: ", paste(names(covs), collapse = ", "))

# --- Names for output labeling ------------------------------------------------
species_names <- c("Coral", "Macroalgae", "Snappers", "Groupers", "Jacks",
                   "Barracuda", "Grunts", "Surgeonfish", "Parrotfish")
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

ms_formula <- ~ scale(depth) + I(scale(depth)^2) +
  scale(slope) + scale(aspect_cos) + scale(aspect_sin) +
  scale(aspect_std)

n_beta <- 7  # intercept + 6 predictors

# =============================================================================
# 3. MODEL 1: NON-SPATIAL MULTI-SPECIES GLMM (msAbund)
# =============================================================================

message("\n=== Fitting M1: Non-spatial msAbund (9 species) ===")

n_batch_m1      <- 400
batch_length_m1 <- 25
n_samples_m1    <- n_batch_m1 * batch_length_m1  # 10,000
n_burn_m1       <- 5000
n_thin_m1       <- 5
n_chains_m1     <- 3

priors_m1 <- list(
  beta.comm.normal  = list(mean = 0, var = 100),
  tau.sq.beta.ig    = list(a = 0.1, b = 0.1),
  sigma.sq.mu.ig    = list(a = 2, b = 1)
)

inits_m1 <- list(
  beta.comm   = rep(0, n_beta),
  beta        = matrix(0, nrow = n_species, ncol = n_beta),
  tau.sq.beta = rep(1, n_beta),
  sigma.sq    = rep(1, n_species)
)

tuning_m1 <- list(
  beta      = 0.1,
  beta.comm = 0.1,
  sigma.sq  = 0.5
)

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

# --- M1 Diagnostics ----------------------------------------------------------
message("  M1 summary:")
m1_summary <- summary(m1)
print(m1_summary)

beta_comm_samples <- m1$beta.comm.samples
if (inherits(beta_comm_samples, "mcmc.list") && length(beta_comm_samples) >= 2) {
  rhat_vals <- gelman.diag(beta_comm_samples, multivariate = FALSE)
  message("  Max Rhat (beta.comm): ", round(max(rhat_vals$psrf[, 1]), 3))
} else {
  message("  Rhat: skipped (got ", class(beta_comm_samples)[1], ")")
}

png(file.path(fig_dir, "species_model_m1_trace.png"),
    width = 14, height = 10, units = "in", res = 200)
plot(beta_comm_samples, density = FALSE)
dev.off()

# Residual diagnostics
if (!is.null(m1$y.rep.samples)) {
  y_rep_mean <- apply(m1$y.rep.samples, c(2, 3), mean)
  resid_m1   <- y_mat - y_rep_mean

  png(file.path(fig_dir, "species_model_m1_residuals.png"),
      width = 14, height = 10, units = "in", res = 200)
  par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
  for (i in 1:n_species) {
    hist(resid_m1[i, ], breaks = 30, col = "gray70", border = "white",
         main = species_names[i], xlab = "Residual")
  }
  dev.off()

  message("  M1 residual SD by species: ",
          paste(species_names, "=", round(apply(resid_m1, 1, sd), 3),
                collapse = ", "))
}

# =============================================================================
# 4. MODEL 2: SPATIAL FACTOR MULTI-SPECIES GLMM (sfMsAbund)
# =============================================================================

message("\n=== Fitting M2: Spatial factor sfMsAbund (9 species, 3 factors) ===")

n_batch_m2      <- 800
batch_length_m2 <- 25
n_samples_m2    <- n_batch_m2 * batch_length_m2  # 20,000
n_burn_m2       <- 10000
n_thin_m2       <- 10
n_chains_m2     <- 3
n_factors       <- 3    # 3 latent factors for 9 species (captures richer correlations)

priors_m2 <- list(
  beta.comm.normal = list(mean = 0, var = 100),
  tau.sq.beta.ig   = list(a = 0.1, b = 0.1),
  sigma.sq.mu.ig   = list(a = 2, b = 1),
  phi.unif         = list(a = 0.01, b = 1.0),
  sigma.sq.ig      = list(a = 2, b = 1)
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

# --- M2 Diagnostics ----------------------------------------------------------
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

png(file.path(fig_dir, "species_model_m2_trace.png"),
    width = 14, height = 10, units = "in", res = 200)
plot(beta_comm_m2, density = FALSE)
dev.off()

# Residual diagnostics
if (!is.null(m2$y.rep.samples)) {
  y_rep_mean_m2 <- apply(m2$y.rep.samples, c(2, 3), mean)
  resid_m2      <- y_mat - y_rep_mean_m2

  png(file.path(fig_dir, "species_model_m2_residuals.png"),
      width = 14, height = 10, units = "in", res = 200)
  par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
  for (i in 1:n_species) {
    hist(resid_m2[i, ], breaks = 30, col = "gray70", border = "white",
         main = species_names[i], xlab = "Residual")
  }
  dev.off()

  # Observed vs fitted
  png(file.path(fig_dir, "species_model_m2_obs_vs_fitted.png"),
      width = 14, height = 10, units = "in", res = 200)
  par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
  for (i in 1:n_species) {
    plot(y_rep_mean_m2[i, ], y_mat[i, ], pch = 16, cex = 0.6,
         col = adjustcolor("#2C3E50", 0.5),
         xlab = "Fitted", ylab = "Observed", main = species_names[i])
    abline(0, 1, col = "red", lty = 2)
  }
  dev.off()

  message("  M2 residual SD by species: ",
          paste(species_names, "=", round(apply(resid_m2, 1, sd), 3),
                collapse = ", "))
}

# =============================================================================
# 5. MODEL COMPARISON
# =============================================================================

message("\n=== Model comparison ===")

waic_results <- tryCatch({
  waic_m1 <- waicAbund(m1)
  waic_m2 <- waicAbund(m2)

  waic_table <- tibble(
    model = c("M1: Non-spatial (9 spp)", "M2: Spatial NNGP (9 spp)"),
    WAIC  = c(waic_m1$WAIC, waic_m2$WAIC),
    pWAIC = c(waic_m1$p.eff, waic_m2$p.eff),
    lppd  = c(waic_m1$lppd, waic_m2$lppd)
  )
  print(waic_table)
  write.csv(waic_table, file.path(table_dir, "species_model_comparison_waic.csv"),
            row.names = FALSE)
  waic_table
}, error = function(e) {
  message("  WAIC failed: ", e$message)
  message("  Comparing via residual variance instead")

  resid_sd_m1 <- if (!is.null(m1$y.rep.samples)) {
    apply(y_mat - apply(m1$y.rep.samples, c(2, 3), mean), 1, sd)
  } else rep(NA, n_species)
  resid_sd_m2 <- if (!is.null(m2$y.rep.samples)) {
    apply(y_mat - apply(m2$y.rep.samples, c(2, 3), mean), 1, sd)
  } else rep(NA, n_species)

  comp <- tibble(
    species     = species_names,
    resid_sd_m1 = round(resid_sd_m1, 3),
    resid_sd_m2 = round(resid_sd_m2, 3),
    improvement = round(100 * (resid_sd_m1 - resid_sd_m2) / resid_sd_m1, 1)
  )
  print(comp)
  write.csv(comp, file.path(table_dir, "species_model_comparison_residuals.csv"),
            row.names = FALSE)
  NULL
})

# =============================================================================
# 6. EXTRACT AND VISUALIZE RESULTS
# =============================================================================

message("\n=== Extracting results from best model ===")

best_model <- m2

as_matrix <- function(x) {
  if (inherits(x, "mcmc.list")) do.call(rbind, x)
  else if (inherits(x, "mcmc")) as.matrix(x)
  else as.matrix(x)
}

# --- Species-specific coefficients -------------------------------------------
beta_combined <- as_matrix(best_model$beta.samples)

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

print(beta_summary, n = 70)

write.csv(beta_summary, file.path(table_dir, "species_model_beta.csv"),
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

write.csv(beta_comm_summary, file.path(table_dir, "species_model_beta_community.csv"),
          row.names = FALSE)

# --- Caterpillar plot: species-specific coefficients -------------------------
# Separate panels for benthic vs commercial vs herbivorous
coef_plot_data <- beta_summary %>%
  filter(predictor != "Intercept") %>%
  mutate(
    group = case_when(
      species %in% c("Coral", "Macroalgae") ~ "Benthic",
      species %in% c("Snappers", "Groupers", "Jacks", "Barracuda", "Grunts") ~ "Commercial fish",
      TRUE ~ "Herbivorous fish"
    ),
    group = factor(group, levels = c("Benthic", "Commercial fish", "Herbivorous fish"))
  )

p_coef <- ggplot(coef_plot_data,
       aes(x = mean, y = predictor, xmin = q025, xmax = q975, color = species)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_pointrange(position = position_dodge(width = 0.7), size = 0.3) +
  facet_wrap(~group, ncol = 1) +
  scale_color_brewer(palette = "Set2") +
  labs(x = "Posterior mean (95% CI)", y = NULL, color = "Species",
       title = "Species-Specific Coefficient Estimates (9-Species Model)") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    legend.position = "right",
    strip.text = element_text(face = "bold", size = 12)
  )

ggsave(file.path(fig_dir, "species_model_coefficients.png"), p_coef,
       width = 12, height = 10, dpi = 300)

# --- Community-level coefficient plot ----------------------------------------
p_comm <- ggplot(beta_comm_summary %>% filter(predictor != "Intercept"),
       aes(x = mean, y = predictor, xmin = q025, xmax = q975)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_pointrange(color = "#2C3E50", size = 0.6) +
  labs(x = "Posterior mean (95% CI)", y = NULL,
       title = "Community-Level Coefficients (9-Species Model)") +
  theme_minimal(base_size = 14) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5))

ggsave(file.path(fig_dir, "species_model_community_coefficients.png"), p_comm,
       width = 8, height = 5, dpi = 300)

# --- Species correlation matrix from latent factors --------------------------
lambda_combined <- as_matrix(best_model$lambda.samples)
lambda_mean <- matrix(colMeans(lambda_combined),
                      nrow = n_species, ncol = n_factors)

cov_from_lambda <- lambda_mean %*% t(lambda_mean)

tau_sq_mat <- if (!is.null(best_model$sigma.sq.samples)) {
  as_matrix(best_model$sigma.sq.samples)
} else if (!is.null(best_model$tau.sq.samples)) {
  as_matrix(best_model$tau.sq.samples)
} else {
  matrix(1, nrow = 1, ncol = n_species)
}
diag_sigma <- colMeans(tau_sq_mat)
cov_total  <- cov_from_lambda + diag(diag_sigma)
cor_species <- cov2cor(cov_total)
rownames(cor_species) <- species_names
colnames(cor_species) <- species_names

message("\n  Estimated species correlation matrix (9 x 9):")
print(round(cor_species, 3))

write.csv(round(cor_species, 4),
          file.path(table_dir, "species_model_correlations.csv"))

png(file.path(fig_dir, "species_model_correlations.png"),
    width = 9, height = 8, units = "in", res = 300)
corrplot::corrplot(cor_species, method = "number", type = "upper",
                   diag = FALSE, number.cex = 0.7, tl.cex = 0.85,
                   tl.col = "black",
                   col = colorRampPalette(c("#E74C3C", "white", "#2C3E50"))(200),
                   title = "Estimated Species Correlations (9-Species Spatial Model)",
                   mar = c(0, 0, 2, 0))
dev.off()

# --- Latent factor loadings heatmap -----------------------------------------
lambda_df <- as.data.frame(lambda_mean)
colnames(lambda_df) <- paste0("Factor ", 1:n_factors)
lambda_df$species <- species_names
lambda_long <- lambda_df %>%
  pivot_longer(-species, names_to = "factor", values_to = "loading") %>%
  mutate(species = factor(species, levels = rev(species_names)))

p_lambda <- ggplot(lambda_long, aes(x = factor, y = species, fill = loading)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(loading, 2)), size = 3.5) +
  scale_fill_gradient2(low = "#E74C3C", mid = "white", high = "#2C3E50",
                       midpoint = 0, name = "Loading") +
  labs(x = NULL, y = NULL,
       title = "Latent Factor Loadings") +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5))

ggsave(file.path(fig_dir, "species_model_factor_loadings.png"), p_lambda,
       width = 7, height = 6, dpi = 300)

# =============================================================================
# 7. SPATIAL PREDICTIONS
# =============================================================================

message("\n=== Generating species-level prediction surface ===")

# Predict at all external data sites
dat_pred <- hri %>%
  rename(Longitude = Longitude_, Latitude = Latitude_y) %>%
  select(Longitude, Latitude, depth, slope, aspect_cos, aspect_sin,
         aspect_std, slopeslope)

pred_covs <- data.frame(
  depth      = dat_pred$depth,
  slope      = dat_pred$slope,
  aspect_cos = dat_pred$aspect_cos,
  aspect_sin = dat_pred$aspect_sin,
  aspect_std = dat_pred$aspect_std,
  slopeslope = dat_pred$slopeslope
)

pred_coords <- cbind(
  x = (dat_pred$Longitude - lon_center) * 111.32 * cos(lat_center * pi / 180),
  y = (dat_pred$Latitude - lat_center) * 110.57
)

X.0 <- model.matrix(ms_formula, data = pred_covs)

pred_df <- tryCatch({
  preds_out <- predict(best_model, X.0 = X.0, coords.0 = pred_coords)
  pred_means <- apply(preds_out$y.0.samples, c(2, 3), mean)

  tibble(
    lon        = dat_pred$Longitude,
    lat        = dat_pred$Latitude,
    coral      = pred_means[1, ],
    algae      = pred_means[2, ],
    snappers   = exp(pred_means[3, ]) - 1,
    groupers   = exp(pred_means[4, ]) - 1,
    jacks      = exp(pred_means[5, ]) - 1,
    barracuda  = exp(pred_means[6, ]) - 1,
    grunts     = exp(pred_means[7, ]) - 1,
    surgeonfish = exp(pred_means[8, ]) - 1,
    parrotfish = exp(pred_means[9, ]) - 1
  )
}, error = function(e) {
  message("  Prediction failed: ", e$message)
  message("  Using fitted values from training data instead")

  if (!is.null(best_model$y.rep.samples)) {
    fitted_means <- apply(best_model$y.rep.samples, c(2, 3), mean)
    tibble(
      lon        = dat_complete$Longitude,
      lat        = dat_complete$Latitude,
      coral      = fitted_means[1, ],
      algae      = fitted_means[2, ],
      snappers   = exp(fitted_means[3, ]) - 1,
      groupers   = exp(fitted_means[4, ]) - 1,
      jacks      = exp(fitted_means[5, ]) - 1,
      barracuda  = exp(fitted_means[6, ]) - 1,
      grunts     = exp(fitted_means[7, ]) - 1,
      surgeonfish = exp(fitted_means[8, ]) - 1,
      parrotfish = exp(fitted_means[9, ]) - 1
    )
  } else {
    message("  No fitted values available")
    NULL
  }
})

if (!is.null(pred_df)) {

write.csv(pred_df, file.path(table_dir, "species_model_predictions.csv"),
          row.names = FALSE)

# --- Prediction maps: fish species only (2 panels: commercial + herbivorous) --
fish_pred_long <- pred_df %>%
  select(-coral, -algae) %>%
  pivot_longer(snappers:parrotfish, names_to = "species", values_to = "predicted") %>%
  mutate(
    species = str_to_title(species),
    group = ifelse(species %in% c("Surgeonfish", "Parrotfish"),
                   "Herbivorous", "Commercial"),
    group = factor(group, levels = c("Commercial", "Herbivorous"))
  )

p_pred_fish <- ggplot(fish_pred_long, aes(x = lon, y = lat, color = predicted + 1)) +
  geom_point(size = 1.2, alpha = 0.8) +
  scale_color_viridis_c(option = "C", trans = "log10",
                        name = "Biomass\n(g/100m²)") +
  facet_wrap(~species, ncol = 3) +
  coord_quickmap() +
  labs(x = "Longitude", y = "Latitude",
       title = "Predicted Fish Biomass by Family — Spatial Model") +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
    strip.text = element_text(face = "bold"),
    legend.position = "right"
  )

ggsave(file.path(fig_dir, "species_model_prediction_maps.png"), p_pred_fish,
       width = 14, height = 10, dpi = 300)

# --- Benthic prediction maps -------------------------------------------------
benthic_pred_long <- pred_df %>%
  select(lon, lat, coral, algae) %>%
  pivot_longer(c(coral, algae), names_to = "variable", values_to = "predicted") %>%
  mutate(variable = recode(variable, coral = "Coral cover (%)",
                           algae = "Macroalgae cover (%)"))

p_pred_benthic <- ggplot(benthic_pred_long, aes(x = lon, y = lat, color = predicted)) +
  geom_point(size = 1.5, alpha = 0.8) +
  scale_color_viridis_c(option = "C") +
  facet_wrap(~variable, ncol = 2) +
  coord_quickmap() +
  labs(x = "Longitude", y = "Latitude", color = "Predicted",
       title = "Predicted Benthic Cover — Spatial Model") +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    strip.text = element_text(face = "bold")
  )

ggsave(file.path(fig_dir, "species_model_prediction_benthic.png"), p_pred_benthic,
       width = 10, height = 5, dpi = 300)

} # end if (!is.null(pred_df))

# =============================================================================
# 8. SAVE MODEL OBJECTS
# =============================================================================

dir.create(here("R_workspaces"), showWarnings = FALSE)
save(m1, m2, sp_data, dat_complete, species_names,
     file = here("R_workspaces", "spAbundance_species_models.RData"))

message("\n=== Species-level model fitting complete ===")
message("  Model objects: R_workspaces/spAbundance_species_models.RData")
message("  Figures: results/figures/species_model_*")
message("  Tables:  results/tables/species_model_*")
