# Power BI dashboard

Build the dashboard in Power BI Desktop (Windows) from the CSVs that `R/analysis.R` writes to `outputs/powerbi/`.

## 1. Load the data

1. Open Power BI Desktop and choose **Get data > Text/CSV**.
2. Load `provincial_rates.csv` and `national_trend.csv`. Optionally also load `yoy_change.csv` and `gap_to_national.csv`.
3. In Power Query, check that `year`, `quarter` and `period_key` are whole numbers and the rate columns are decimal numbers.
4. Add a column to each table for a real date: **Add column > Custom column**, named `quarter_start`, with this formula:

   `#date([year], ([quarter] - 1) * 3 + 1, 1)`

5. Set the data type of `quarter_start` to Date.

## 2. Relationships

`provincial_rates` and `national_trend` can be joined on `period_key`. Set the relationship to many-to-one, with `national_trend` on the one side.

## 3. Measures

Create these in a new measures table (**Home > Enter data**, then add measures). Calculating the rate from totals, rather than averaging the stored rates, keeps the numbers correct when you filter by province or year.

```
Unemployed = SUM(provincial_rates[unemployed])

Labour Force = SUM(provincial_rates[labour_force])

Unemployment Rate % =
DIVIDE([Unemployed], [Labour Force]) * 100

Latest Period Key = MAX(provincial_rates[period_key])

Latest Unemployment Rate % =
CALCULATE([Unemployment Rate %], provincial_rates[period_key] = [Latest Period Key])

Rate Year Ago % =
CALCULATE([Unemployment Rate %], DATEADD(provincial_rates[quarter_start], -1, YEAR))

YoY Change (pp) = [Unemployment Rate %] - [Rate Year Ago %]
```

`DATEADD` needs a continuous date column. If it complains, mark a date table: create a calendar table with **Modeling > New table** and relate it to `quarter_start`, then use that table's date column in the measure.

## 4. Suggested page layout

- **Top row:** three KPI cards for the latest national unemployment rate, the year-on-year change, and the province with the highest rate.
- **Left:** line chart of `Unemployment Rate %` by `quarter_start`, with `province` as the legend. Add a second line for the national rate.
- **Right:** map or bar chart of the latest rate by province. For the map, set the data category of `province` to State or Province and add "South Africa" as a country column so the map places the provinces correctly. A sorted bar chart is a safe alternative.
- **Side:** slicers for year and province.
- Keep the same colour for the same thing on every visual, and put units and the source (Stats SA QLFS) in a text box at the bottom.

## 5. Save screenshots

Export or screenshot each finished page into `powerbi/screenshots/` and reference them from the main README. You can also commit the `.pbix` file, but check its size and make sure it contains only the public Stats SA data.
