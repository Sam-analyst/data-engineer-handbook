-- 04 backfill scd
INSERT INTO actors_history_scd
WITH raw_actors AS (
	SELECT
		*,
		LAG(quality_class, 1) OVER (PARTITION BY actorid ORDER BY current_year) as prev_quality,
		LAG(is_active, 1) OVER (PARTITION BY actorid ORDER BY current_year) as prev_is_active
	FROM actors
),
indicators AS (
	SELECT
		*,
		CASE
			WHEN quality_class <> prev_quality THEN 1
			WHEN is_active <> prev_is_active THEN 1
			ELSE 0
		END AS change_indicator
	FROM raw_actors
),
streaks AS (
SELECT
	*,
	SUM(change_indicator) OVER (PARTITION BY actorid ORDER BY current_year) AS streak_identifier
FROM indicators
)
SELECT
	actor,
	actorid,
	quality_class,
	is_active,
	MIN(current_year) AS start_season,
	MAX(current_year) AS end_season,
	1975 AS current_year
FROM streaks
GROUP BY actor, actorid, quality_class, is_active, streak_identifier
ORDER BY actor
