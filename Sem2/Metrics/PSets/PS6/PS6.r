library(Matrix)
library(dplyr)
library(tidyr)
library(magrittr)

df <- read.csv('metrics.csv')
# Creating Variables
id <- df$id
year <- df$year

n <- length(unique(id))
t <- length(unique(year))
nt <- n*t

df %<>% mutate(D=1*(first.displaced <= year & first.displaced !=0), yearf = factor(year))

Y <- Matrix(df$learn)
X <- model.matrix(~ yearf + D-1, data = df)
X <- Matrix(X)

I <- diag(nt)
D <- bdiag(replicate(n,Matrix(rep(1,t)),simplify=FALSE))
M <- I - D%*%solve(t(D)%*%D)%*%t(D)
alpha_hat <- solve(t(X)%*%M%*%X)%*%t(X)%*%M%*%Y
e_hat <- Y - X%*%alpha_hat
var_error = as.numeric(t(e_hat) %*% e_hat) / (nt - ncol(X))
var_alpha = var_error * solve(t(X) %*% M %*% X)
se_alpha = sqrt(diag(var_alpha))

cat("Part A: Report of Estimates\n")
alpha_hat
se_alpha

## Problem B - Diff-in-Differences

calc_group_time_att <- function(df, group, time) {

  if (time < group) {
    return(NA)
  }
  treat <- subset(df, first.displaced == group)
  control <- subset(df, first.displaced == 0)

  pre_period <- group - 2

  treat_pre <- subset(treat, year == pre_period)$learn
  treat_post <- subset(treat, year == time)$learn
  treat_diff <- mean(treat_post) - mean(treat_pre)

  control_pre <- subset(control, year == pre_period)$learn
  control_post <- subset(control, year == time)$learn
  control_diff <- mean(control_post) - mean(control_pre)

  att <- treat_diff - control_diff
  return(att)
}

groups <- c(2001, 2003, 2005, 2007, 2009, 2011, 2013)
years <- unique(df$year)

att_results <- matrix(NA, nrow = length(groups), ncol = length(years))
rownames(att_results) <- paste0("Group_", groups)
colnames(att_results) <- paste0("Year_", years)

for (i in 1:length(groups)) {
  for (j in 1:length(years)) {
    att_results[i, j] <- calc_group_time_att(df, groups[i], years[j])
  }
}

cat("Part B: Report of ATT Estimates\n")
print(att_results)
cat("\n")

## Part C: Report of ATT Estimates

att_values <- as.vector(att_results)
att_values <- att_values[!is.na(att_values)]
att_overall <- mean(att_values)

set.seed(19)
B <- 50
att_boot <- numeric(B)

for (b in 1:B) {
  ids <- unique(df$id)
  boot_ids <- sample(ids, length(ids), replace = TRUE)

  boot_df <- data.frame()
  for (id in boot_ids) {
    boot_df <- rbind(boot_df, subset(df, id == id))
  }

  boot_att_results <- matrix(NA, nrow = length(groups), ncol = length(years))

  for (i in 1:length(groups)) {
    for (j in 1:length(years)) {
      boot_att_results[i, j] <- calc_group_time_att(boot_df, groups[i], years[j])
    }
  }

  boot_att_values <- as.vector(boot_att_results)
  boot_att_values <- boot_att_values[!is.na(boot_att_values)]
  att_boot[b] <- mean(boot_att_values)
}

se_att <- sd(att_boot)

cat("Part C: Report of ATT Estimates\n")
cat("Overall ATT Estimate:", att_overall, "\n")
cat("Standard Error of ATT Estimate:", se_att, "\n")
cat("Comparison with Part A:", alpha_hat, "\n\n")

## Part D: 

rel_time <- -3:6

event_study_results <- matrix(NA, nrow = length(groups), ncol = length(rel_time))
rownames(event_study_results) <- paste0("Group_", groups)
colnames(event_study_results) <- paste0("t", rel_time)

for (i in 1:length(groups)) {
  group <- groups[i]
  for (k in 1:length(rel_times)) {
    rel_time <- rel_times[k]
    time <- group + rel_time*2

    if (time %in% years) {
      event_study_results[i, k] <- calc_group_time_att(df, group, time)
    }
  }
}

even_sstudy_avg <- colMeans(event_study_results)
event_boot <- matrix(NA, nrow = B, ncol = length(rel_times))

for (b in 1:B) {
  ids <- unique(df$id)
  boot_ids <- sample(ids, length(ids), replace = TRUE)

  boot_df <- data.frame()
  for (id in boot_ids) {
    boot_df <- rbind(boot_df, subset(df, id == id))
  }
  boot_event_study_results <- matrix(NA, nrow = length(groups), ncol = length(rel_times))

  for (i in 1:length(groups)) {
    group <- groups[i]
    for (k in 1:length(rel_times)) {
      rel_time <- rel_times[k]
      time <- group + rel_time*2

      if (time %in% years) {
        boot_event_study_results[i, k] <- calc_group_time_att(boot_df, group, time)
      }
    }
  }
  event_boot[b, ] <- colMeans(boot_event_study_results)
}

event_se <- apply(event_boot, 2, sd)
ci_l <- event_study_avg - 1.96*event_se
ci_u <- event_study_avg + 1.96*event_se

cat("Part D: Report of Event Study Estimates\n")
cat("Event Study Estimates:\n")
print(data.frame(
  rel_time = rel_times,
  Estimate = event_study_avg,
  SE = event_se,
  CI_Lower = ci_l,
  CI_Upper = ci_u
))

plot(rel_times, event_study_avg, type = "o",
     ylim = c(min(ci_l), max(ci_u)),
     xlab = "Time relative to displaced", ylab = "Effect of log earnings")
arrows(rel_times, ci_l, rel_times, ci_u,
       length = 0.05, angle = 90, code = 3)
abline(h=0, lty=2)
abline(v=-0.5, lty=3)
