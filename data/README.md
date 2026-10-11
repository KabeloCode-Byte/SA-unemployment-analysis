# Data

The analysis reads one file: `data/qlfs_provincial.csv`. It is not included in this repository, so you need to build it from Stats SA's published Quarterly Labour Force Survey (QLFS) tables.

## Source

Statistics South Africa, Quarterly Labour Force Survey (publication P0211):
https://www.statssa.gov.za/?page_id=1854&PPN=P0211&SCH=73898

Each quarterly release includes a table of the labour market by province, with figures in thousands of persons. Use the same table for every quarter so the definitions stay consistent.

## Format

One row per province per quarter. All counts are in thousands, as published.

| Column | Type | Description |
|---|---|---|
| `year` | integer | Calendar year, e.g. `2025` |
| `quarter` | integer | `1` to `4` |
| `province` | text | One of the nine names below, spelled exactly like this |
| `working_age_pop` | number | Population aged 15 to 64 |
| `employed` | number | Employed persons |
| `unemployed` | number | Unemployed persons (official definition) |
| `not_economically_active` | number | Not economically active persons |

Province names: Western Cape, Eastern Cape, Northern Cape, Free State, KwaZulu-Natal, North West, Gauteng, Mpumalanga, Limpopo.

A header-only template is provided in `qlfs_provincial_template.csv`. Copy it to `qlfs_provincial.csv` and fill it in.

## Check your data

- Each quarter should have 9 rows. The analysis flags any quarter that does not.
- `employed + unemployed + not_economically_active` should equal `working_age_pop`, give or take rounding. The analysis flags rows that are off by more than 2 thousand.
- After running the analysis, compare a few of the calculated unemployment rates in `outputs/powerbi/provincial_rates.csv` with the rates Stats SA publishes. They should agree to within about 0.1 percentage points. If they do not, a number was probably copied wrongly.

## Note on comparability

Stats SA has revised the QLFS population weights over the years (for example after new population estimates). Figures from before and after a re-weighting may not be perfectly comparable. Note which release each quarter came from.
