-- Query: Incremental update for actors_history_scd (SCD Type 2)

CREATE TYPE scd_type AS (
	quality_class quality_class,
	is_active BOOLEAN,
	start_year INTEGER,
	end_year INTEGER
);

INSERT INTO actors_history_scd
WITH ly_scd AS (
	SELECT
		*
	FROM actors_history_scd
	WHERE end_year = 1974
),
historical_scd AS (
	SELECT
		actor,
		actorid,
		quality_class,
		is_active,
		start_year,
		end_year,
		1975 AS current_year
	FROM actors_history_scd
	WHERE end_year < 1974
),
cy_actors AS (
	SELECT
		*
	FROM actors
	WHERE current_year = 1975
),
unchanged_records AS (
	SELECT
		cy.actor,
		cy.actorid,
		cy.quality_class,
		cy.is_active,
		ly.start_year,
		cy.current_year AS end_year,
		1975 AS current_year
	FROM ly_scd ly
	JOIN cy_actors cy
		ON ly.actorid = cy.actorid
	WHERE ly.quality_class = cy.quality_class
		AND ly.is_active = cy.is_active
),
changed_records AS (
	SELECT
		cy.actor,
		cy.actorid,
		UNNEST(ARRAY[
			ROW(
				ly.quality_class,
				ly.is_active,
				ly.start_year,
				ly.end_year
			)::scd_type,
			ROW(
				cy.quality_class,
				cy.is_active,
				cy.current_year,
				cy.current_year
			)::scd_type
		]) as arr,
		1975 as current_year
	FROM cy_actors cy
	LEFT JOIN ly_scd ly
		ON ly.actorid = cy.actorid
	WHERE ly.quality_class <> cy.quality_class
		OR ly.is_active <> cy.is_active
),
unnested_changed_records AS (
	SELECT
		actor,
		actorid,
		(arr::scd_type).*,
		current_year
	FROM changed_records
),
new_records AS (
	SELECT
		cy.actor,
		cy.actorid,
		cy.quality_class,
		cy.is_active,
		cy.current_year AS start_year,
		cy.current_year AS end_year,
		1975 AS current_year
	FROM cy_actors cy 
	LEFT JOIN ly_scd ly
		ON ly.actorid = cy.actorid
	WHERE ly.actor IS NULL
)
SELECT * FROM historical_scd
UNION ALL
SELECT * FROM unchanged_records
UNION ALL
SELECT * FROM unnested_changed_records
UNION ALL
SELECT * FROM new_records