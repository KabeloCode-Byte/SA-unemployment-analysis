# South African unemployment analysis (Stats SA QLFS)
#
# Pipeline:
#   1. Read and validate data/qlfs_provincial.csv
#   2. Load it into a SQLite database using sql/01_schema.sql
#   3. Run the analysis queries in sql/02_queries.sql
#   4. Save charts to outputs/figures/ and Power BI-ready CSVs to outputs/powerbi/
#
# Run from the project root:  Rscript R/analysis.R

required <- c("readr", "dplyr", "ggplot2", "scales", "DBI", "RSQLite")
missing_pkgs <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop("Install these packages first: install.packages(c(",
       paste0('"', missing_pkgs, '"', collapse = ", "), "))", call. = FALSE)
}

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(scales)
  library(DBI)
  library(RSQLite)
})

data_path    <- "data/qlfs_provincial.csv"
schema_path  <- "sql/01_schema.sql"
queries_path <- "sql/02_queries.sql"
db_path      <- "outputs/qlfs.sqlite"
fig_dir      <- "outputs/figures"
powerbi_dir  <- "outputs/powerbi"

for (d in c("outputs", fig_dir, powerbi_dir)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# ---- helpers ---------------------------------------------------------------

# Runs a script of several SQL statements (comment lines are ignored).
run_sql_script <- function(con, path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[!grepl("^\\s*--", lines)]
  statements <- trimws(strsplit(paste(lines, collapse = "\n"), ";")[[1]])
  for (stmt in statements[nzchar(statements)]) DBI::dbExecute(con, stmt)
  invisible(NULL)
}

# Reads named queries: each starts with a "-- name: something" line.
read_queries <- function(path) {
  lines <- readLines(path, warn = FALSE)
  starts <- grep("^-- name:", lines)
  ends <- c(starts[-1] - 1, length(lines))
  queries <- Map(function(s, e) {
    body <- trimws(paste(lines[(s + 1):e], collapse = "\n"))
    sub(";\\s*$", "", body)
  }, starts, ends)
  names(queries) <- trimws(sub("^-- name:", "", lines[starts]))
  queries
}

quarter_start_date <- function(year, quarter) {
  as.Date(sprintf("%d-%02d-01", year, (quarter - 1) * 3 + 1))
}

# ---- 1. read and validate --------------------------------------------------

if (!file.exists(data_path)) {
  stop("Missing ", data_path, ". See data/README.md for how to build it from the Stats SA QLFS tables.",
       call. = FALSE)
}

provinces <- c("Western Cape", "Eastern Cape", "Northern Cape", "Free State",
               "KwaZulu-Natal", "North West", "Gauteng", "Mpumalanga", "Limpopo")

raw <- read_csv(
  data_path,
  col_types = cols(
    year = col_integer(), quarter = col_integer(), province = col_character(),
    working_age_pop = col_double(), employed = col_double(),
    unemployed = col_double(), not_economically_active = col_double()
  )
)

stopifnot(
  "Unexpected columns in CSV" = setequal(names(raw),
    c("year", "quarter", "province", "working_age_pop", "employed",
      "unemployed", "not_economically_active")),
  "No rows in CSV" = nrow(raw) > 0,
  "Missing values in CSV" = !anyNA(raw),
  "Province names must match the nine official names (see data/README.md)" =
    all(raw$province %in% provinces),
  "Duplicate year/quarter/province rows" =
    !anyDuplicated(raw[, c("year", "quarter", "province")])
)

message("Read ", nrow(raw), " rows covering ",
        n_distinct(raw$year * 10 + raw$quarter), " quarters.")

# ---- 2. load into SQLite ---------------------------------------------------

if (file.exists(db_path)) file.remove(db_path)
con <- dbConnect(RSQLite::SQLite(), db_path)

run_sql_script(con, schema_path)
dbWriteTable(con, "qlfs_provincial", as.data.frame(raw), append = TRUE)

# ---- 3. run the analysis queries ------------------------------------------

queries <- read_queries(queries_path)
results <- lapply(queries, function(q) dbGetQuery(con, q))

quality <- results$data_quality
if (any(quality$provinces != 9)) {
  warning("Some quarters do not have all 9 provinces:\n",
          paste(capture.output(print(quality[quality$provinces != 9, ])), collapse = "\n"))
}
if (any(quality$rows_not_adding_up > 0)) {
  warning("Some rows have employed + unemployed + not economically active that does not match ",
          "the working-age population (beyond rounding). Check your CSV against the Stats SA tables.")
}

by_province_raw <- dbGetQuery(con, "SELECT * FROM v_provincial_rates ORDER BY province, period_key")
dbDisconnect(con)

national <- results$national_trend |>
  mutate(date = quarter_start_date(year, quarter))

by_province <- by_province_raw |>
  mutate(date = quarter_start_date(year, quarter))

# ---- 4. charts -------------------------------------------------------------

theme_set(theme_minimal(base_size = 12) +
            theme(plot.title = element_text(face = "bold"),
                  panel.grid.minor = element_blank()))

p_national <- ggplot(national, aes(date, unemployment_rate)) +
  geom_line(linewidth = 1, colour = "#1f4e79") +
  geom_point(size = 1.8, colour = "#1f4e79") +
  scale_y_continuous(labels = label_number(suffix = "%"), limits = c(0, NA)) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(title = "National unemployment rate",
       subtitle = "Official definition, calculated from provincial QLFS figures",
       x = NULL, y = "Unemployment rate",
       caption = "Source: Stats SA, Quarterly Labour Force Survey")

p_provinces <- ggplot(by_province, aes(date, unemployment_rate)) +
  geom_line(colour = "#1f4e79") +
  facet_wrap(~province) +
  scale_y_continuous(labels = label_number(suffix = "%"), limits = c(0, NA)) +
  scale_x_date(date_labels = "%y", date_breaks = "2 years") +
  labs(title = "Unemployment rate by province",
       x = NULL, y = "Unemployment rate",
       caption = "Source: Stats SA, Quarterly Labour Force Survey")

latest <- results$latest_province_ranking
p_ranking <- ggplot(latest, aes(unemployment_rate, reorder(province, unemployment_rate))) +
  geom_col(fill = "#1f4e79") +
  geom_text(aes(label = sprintf("%.1f%%", unemployment_rate)), hjust = -0.1, size = 3.5) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = paste("Unemployment rate by province,", latest$period[1]),
       x = NULL, y = NULL,
       caption = "Source: Stats SA, Quarterly Labour Force Survey")

ggsave(file.path(fig_dir, "national_trend.png"),   p_national,  width = 8,  height = 4.5, dpi = 150)
ggsave(file.path(fig_dir, "province_trends.png"),  p_provinces, width = 10, height = 7,   dpi = 150)
ggsave(file.path(fig_dir, "latest_ranking.png"),   p_ranking,   width = 8,  height = 4.5, dpi = 150)

# ---- 5. export for Power BI -------------------------------------------------

write_csv(by_province |> select(-date), file.path(powerbi_dir, "provincial_rates.csv"))
write_csv(results$national_trend,       file.path(powerbi_dir, "national_trend.csv"))
write_csv(results$yoy_change,           file.path(powerbi_dir, "yoy_change.csv"))
write_csv(results$gap_to_national,      file.path(powerbi_dir, "gap_to_national.csv"))

message("Done. Charts are in ", fig_dir, " and Power BI files are in ", powerbi_dir, ".")
