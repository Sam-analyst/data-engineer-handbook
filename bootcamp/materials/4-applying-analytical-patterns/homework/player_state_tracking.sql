-- first need to create a table
-- CREATE TABLE player_state_tracking (
-- 	player_name TEXT,
-- 	player_status TEXT,
-- 	season INTEGER,
-- 	PRIMARY KEY (player_name, season)
-- )


WITH last_year AS (
	SELECT *
	FROM player_state_tracking
	WHERE season = '2000'
),
current_year AS (
	SELECT
		player_name AS player_name_cy,
		season AS season_cy
	FROM player_seasons
	WHERE season = '2001'
),
combined AS (
	SELECT
		COALESCE(player_name_cy, player_name) AS player_name,
		CASE
	        WHEN season IS NULL THEN 'New'
	        WHEN season_cy IS NULL THEN
	            CASE
	                WHEN player_status IN ('New', 'Continued Playing', 'Returned from Retirement') THEN 'Retired'
	                WHEN player_status IN ('Retired', 'Stayed Retired') THEN 'Stayed Retired'
	            END
	        WHEN season_cy IS NOT NULL THEN
	            CASE
	                WHEN player_status IN ('Retired', 'Stayed Retired') THEN 'Returned from Retirement'
	                WHEN player_status IN ('New', 'Continued Playing', 'Returned from Retirement') THEN 'Continued Playing'
	            END
		END AS player_status,
		COALESCE(season_cy, season + 1) AS season
	FROM last_year ly
	FULL OUTER JOIN current_year cy
	ON ly.player_name = cy.player_name_cy
)
INSERT INTO player_state_tracking
SELECT *
FROM combined