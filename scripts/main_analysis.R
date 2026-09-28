# 1. Packages ---------------------------------------------------------------
pkgs <- c("quantmod", "PerformanceAnalytics", "ggplot2")
for (p in pkgs) if (!require(p, character.only = TRUE)) install.packages(p)
library(quantmod)
library(PerformanceAnalytics)
library(ggplot2)

# 2. Download data (last 3 years) -------------------------------------------
tickers    <- c("AAPL", "^GSPC")
names_used <- c("AAPL", "SP500")
end_date   <- Sys.Date()
start_date <- end_date - 365 * 3

prices <- lapply(tickers, function(t) {
  Ad(getSymbols(t, src = "yahoo", from = start_date, to = end_date,
                auto.assign = FALSE))
})
prices <- do.call(merge, prices)
colnames(prices) <- names_used

# 3. Daily log returns, NA removed ------------------------------------------
returns <- na.omit(CalculateReturns(prices, method = "log"))

# 4. Risk metrics (reported as positive loss, in %) --------------------------
get_risk <- function(x) {
  v <- function(p, m) as.numeric(abs(VaR(x, p = p, method = m)))
  data.frame(
    VaR95_Historical = v(0.95, "historical"),
    VaR99_Historical = v(0.99, "historical"),
    VaR95_Parametric = v(0.95, "gaussian"),
    VaR99_Parametric = v(0.99, "gaussian"),
    ES95_Historical  = as.numeric(abs(ES(x, p = 0.95, method = "historical")))
  )
}

risk_table <- do.call(rbind, lapply(names_used, function(a) get_risk(returns[, a])))
rownames(risk_table) <- names_used
risk_pct <- round(risk_table * 100, 2)

cat("--- RISK ANALYSIS RESULTS (daily, % of portfolio value) ---\n")
print(risk_pct)
write.csv(risk_pct, "data/risk_results.csv")

# 5. Histograms with VaR lines, saved to data/ ------------------------------
for (a in names_used) {
  df <- data.frame(ret = as.numeric(returns[, a]))
  lines_df <- data.frame(
    level = c("VaR 95%", "VaR 99%"),
    value = -c(risk_table[a, "VaR95_Historical"], risk_table[a, "VaR99_Historical"])
  )
  g <- ggplot(df, aes(x = ret)) +
    geom_histogram(bins = 50, fill = "steelblue", colour = "white") +
    geom_vline(data = lines_df, aes(xintercept = value, colour = level),
               linewidth = 1) +
    scale_colour_manual(values = c("VaR 95%" = "orange", "VaR 99%" = "red")) +
    labs(title = paste("Distribution of daily log returns and historical VaR:", a),
         x = "Daily log return", y = "Frequency", colour = "") +
    theme_minimal()
  print(g)
  ggsave(paste0("data/var_chart_", a, ".png"), g, width = 8, height = 6, dpi = 150)
}