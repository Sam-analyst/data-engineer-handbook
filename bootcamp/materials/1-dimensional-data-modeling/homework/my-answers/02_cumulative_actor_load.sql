-- 02 cumulative actor load


-- using this query, i determined min year is 1970. 1969 is seed query
-- SELECT MIN(year) FROM actor_films

-- i also found out the max year is 2021

-- code I used to populate actors table
INSERT INTO actors
WITH ly AS (
	SELECT *
	FROM actors
	WHERE current_year = 1974
),
cy AS (
	SELECT
		actor,
		actorid,
		year,
		ARRAY_AGG(ROW(film, year, votes, rating, filmid)::films) AS films,
		CASE -- order matters here!
			WHEN avg(rating) > 8 THEN 'star'
			WHEN avg(rating) > 7 THEN 'good'
			WHEN avg(rating) > 6 THEN 'average'
			WHEN avg(rating) <= 6 THEN 'bad' -- coding this in for quality insurance vs having as else stmt
		END::quality_class
	FROM actor_films
	WHERE year = 1975
	GROUP BY actor, actorid, year
),
combined AS (
	SELECT
		COALESCE(cy.actor, ly.actor) AS actor,
		COALESCE(cy.actorid, ly.actorid) AS actorid,
		CASE
			WHEN ly.films IS NULL THEN cy.films
			WHEN CY.films IS NOT NULL THEN ly.films || cy.films
			ELSE ly.films
		END AS films,
		COALESCE(cy.quality_class, ly.quality_class) AS quality_class,
		CASE
			WHEN cy.year IS NOT NULL THEN TRUE ELSE FALSE
		END AS is_active,
		COALESCE(cy.year, ly.current_year + 1) AS current_year
	FROM ly
	FULL OUTER JOIN cy
		ON ly.actorid = cy.actorid
)
SELECT * FROM combined