-- Analysis queries. Each query starts with a "-- name:" line so the R script
-- can run them one by one. Keep one statement per name.

-- name: data_quality
-- Every period should have 9 provinces, and the three labour-market groups
-- should add up to the working-age population (small rounding gaps are normal
-- because Stats SA publishes figures rounded to the nearest thousand).
SELECT
    period,
    COUNT(*) AS provinces,
    SUM(CASE WHEN ABS(employed + unemployed + not_economically_active - working_age_pop) > 2
             THEN 1 ELSE 0 END) AS rows_not_adding_up
FROM v_provincial_rates
GROUP BY period_key, period
ORDER BY period_key;

-- name: national_trend
-- National totals are rebuilt from the provincial rows, then the rate is
-- recalculated. Averaging provincial rates would be wrong because provinces
-- differ greatly in size.
SELECT
    period_key,
    period,
    year,
    quarter,
    SUM(working_age_pop)  AS working_age_pop,
    SUM(employed)         AS employed,
    SUM(unemployed)       AS unemployed,
    100.0 * SUM(unemployed) / (SUM(employed) + SUM(unemployed)) AS unemployment_rate,
    100.0 * (SUM(employed) + SUM(unemployed)) / SUM(working_age_pop) AS participation_rate
FROM v_provincial_rates
GROUP BY period_key, period, year, quarter
ORDER BY period_key;

-- name: latest_province_ranking
-- Provinces ranked by unemployment rate in the most recent quarter in the data.
SELECT
    province,
    period,
    unemployment_rate,
    RANK() OVER (ORDER BY unemployment_rate DESC) AS rank_high_to_low
FROM v_provincial_rates
WHERE period_key = (SELECT MAX(period_key) FROM v_provincial_rates)
ORDER BY unemployment_rate DESC;

-- name: yoy_change
-- Change in unemployment rate versus the same quarter a year earlier, in
-- percentage points. Joining on year - 1 (instead of using LAG) stays correct
-- even if a quarter is missing from the data.
SELECT
    cur.province,
    cur.period_key,
    cur.period,
    cur.unemployment_rate,
    prev.unemployment_rate AS rate_year_ago,
    cur.unemployment_rate - prev.unemployment_rate AS yoy_change_pp
FROM v_provincial_rates AS cur
JOIN v_provincial_rates AS prev
  ON prev.province = cur.province
 AND prev.year     = cur.year - 1
 AND prev.quarter  = cur.quarter
ORDER BY cur.province, cur.period_key;

-- name: rolling_avg
-- Four-quarter moving average of each province's unemployment rate, which
-- smooths out the seasonal swings in the quarterly figures. Only rows with a
-- full four quarters of history are returned.
SELECT province, period_key, period, unemployment_rate, rolling_4q_avg
FROM (
    SELECT
        province,
        period_key,
        period,
        unemployment_rate,
        AVG(unemployment_rate) OVER w AS rolling_4q_avg,
        COUNT(*)               OVER w AS quarters_in_window
    FROM v_provincial_rates
    WINDOW w AS (
        PARTITION BY province
        ORDER BY period_key
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    )
)
WHERE quarters_in_window = 4
ORDER BY province, period_key;

-- name: gap_to_national
-- How far each province sits above or below the national rate each quarter.
WITH national AS (
    SELECT
        period_key,
        100.0 * SUM(unemployed) / (SUM(employed) + SUM(unemployed)) AS national_rate
    FROM v_provincial_rates
    GROUP BY period_key
)
SELECT
    p.province,
    p.period_key,
    p.period,
    p.unemployment_rate,
    n.national_rate,
    p.unemployment_rate - n.national_rate AS gap_to_national_pp
FROM v_provincial_rates AS p
JOIN national AS n USING (period_key)
ORDER BY p.province, p.period_key;

-- name: province_summary
-- Highest, lowest and average unemployment rate per province across the
-- whole period, plus the latest value.
SELECT
    province,
    MIN(unemployment_rate) AS lowest_rate,
    MAX(unemployment_rate) AS highest_rate,
    AVG(unemployment_rate) AS average_rate,
    (SELECT v2.unemployment_rate
       FROM v_provincial_rates AS v2
      WHERE v2.province = v.province
      ORDER BY v2.period_key DESC
      LIMIT 1) AS latest_rate
FROM v_provincial_rates AS v
GROUP BY province
ORDER BY latest_rate DESC;
