-- Schema for provincial Quarterly Labour Force Survey (QLFS) data.
-- All counts are in thousands of persons, as published by Stats SA.
-- Written for SQLite (window functions need SQLite 3.25 or newer).

DROP VIEW IF EXISTS v_provincial_rates;
DROP TABLE IF EXISTS qlfs_provincial;

CREATE TABLE qlfs_provincial (
    year                     INTEGER NOT NULL CHECK (year BETWEEN 2008 AND 2100),
    quarter                  INTEGER NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    province                 TEXT    NOT NULL,
    working_age_pop          REAL    NOT NULL CHECK (working_age_pop > 0),
    employed                 REAL    NOT NULL CHECK (employed >= 0),
    unemployed               REAL    NOT NULL CHECK (unemployed >= 0),
    not_economically_active  REAL    NOT NULL CHECK (not_economically_active >= 0),
    PRIMARY KEY (year, quarter, province)
);

-- Derived rates, using the official definitions:
--   unemployment rate = unemployed / (employed + unemployed)
--   participation rate = labour force / working-age population
--   absorption rate = employed / working-age population
CREATE VIEW v_provincial_rates AS
SELECT
    year,
    quarter,
    year * 10 + quarter                          AS period_key,
    year || ' Q' || quarter                      AS period,
    province,
    working_age_pop,
    employed,
    unemployed,
    not_economically_active,
    employed + unemployed                        AS labour_force,
    100.0 * unemployed / (employed + unemployed) AS unemployment_rate,
    100.0 * (employed + unemployed) / working_age_pop AS participation_rate,
    100.0 * employed / working_age_pop           AS absorption_rate
FROM qlfs_provincial;
