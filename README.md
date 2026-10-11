# South African Unemployment Analysis

An analysis of unemployment trends across South Africa's nine provinces, using Stats SA's Quarterly Labour Force Survey (QLFS). The data is cleaned and queried in SQL, analysed and charted in R, and presented in a Power BI dashboard.

## Questions

1. How has the national unemployment rate changed over time?
2. Which provinces have the highest and lowest unemployment, and how has that ranking moved?
3. Which provinces are improving or worsening compared with the same quarter a year earlier?
4. How far does each province sit above or below the national rate?

## Data

Source: Statistics South Africa, [Quarterly Labour Force Survey (P0211)](https://www.statssa.gov.za/?page_id=1854&PPN=P0211&SCH=73898). Provincial labour-market figures in thousands of persons, one row per province per quarter. See [data/README.md](data/README.md) for the exact format and how to build the input file.

## Method

- **SQL** (`sql/`): a schema with validation constraints, a view that calculates the unemployment, participation and absorption rates, and seven analysis queries. These include national rates rebuilt from provincial totals, year-on-year change, a four-quarter moving average using window functions, and each province's gap to the national rate.
- **R** (`R/analysis.R`): validates the CSV, loads it into SQLite, runs the SQL queries, draws the charts, and exports tidy CSVs for Power BI.
- **Power BI** (`powerbi/`): an interactive dashboard with KPI cards, trend lines by province, and a latest-quarter ranking. Build steps and DAX measures are in [powerbi/README.md](powerbi/README.md).

Unemployment rate follows the official definition: unemployed divided by the labour force (employed plus unemployed). National rates are recalculated from provincial totals rather than averaging provincial rates, because the provinces differ greatly in size.

## Project structure

```
data/        Input CSV format, template and data notes
sql/         Schema and analysis queries (SQLite)
R/           Analysis script
powerbi/     Dashboard build guide and screenshots
outputs/     Generated charts and CSVs (created when you run the analysis)
```

## How to run

1. Build `data/qlfs_provincial.csv` as described in [data/README.md](data/README.md).
2. Install R 4.1 or newer and the packages: `install.packages(c("readr", "dplyr", "ggplot2", "scales", "DBI", "RSQLite"))`.
3. From the project root, run `Rscript R/analysis.R`.
4. Charts appear in `outputs/figures/` and Power BI input files in `outputs/powerbi/`.

## Limitations

- QLFS figures are survey estimates and carry sampling error, especially for the smaller provinces.
- Quarterly figures show seasonal patterns, so compare the same quarter across years (as the year-on-year query does) or use the moving average.
- Population weights have been revised over the years, which can affect comparability across releases.
- This analysis describes patterns and does not explain their causes.

## Author

Kabelo Mokgobu, [GitHub](https://github.com/KabeloCode-Byte)
