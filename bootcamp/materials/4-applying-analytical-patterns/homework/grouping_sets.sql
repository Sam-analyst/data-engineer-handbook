WITH combined_games AS (
	SELECT
		g.game_id,
		g.season,
		g.pts_home,
		g.pts_away,
		g.team_id_home,
		gd.team_id,
		gd.team_abbreviation,
		gd.player_name,
		COALESCE(gd.pts, 0) AS pts
	FROM games g
	LEFT JOIN game_details gd
	ON g.game_id = gd.game_id
),
aggregated_data AS (
	SELECT
		COALESCE(team_abbreviation, 'OVERALL') AS team,
		COALESCE(player_name, 'OVERALL') AS player,
		COALESCE(season::TEXT, 'OVERALL') AS season,
		SUM(pts) AS pts,
		COUNT (DISTINCT CASE WHEN team_id = team_id_home AND pts_home > pts_away THEN game_id ELSE NULL END) AS games_won
	FROM combined_games
	GROUP BY GROUPING SETS (
		(team_abbreviation, player_name),
		(player_name, season),
		(team_abbreviation)
	)
)
-- most points scored by player on single team
SELECT *
FROM aggregated_data
WHERE player <> 'OVERALL'
ORDER BY pts DESC
LIMIT 1

-- most points scored by player in single season
SELECT *
FROM aggregated_data
WHERE player <> 'OVERALL' AND season <> 'OVERALL'
ORDER BY pts DESC
LIMIT 1

-- most games won by team
SELECT *
FROM aggregated_data
WHERE player = 'OVERALL'
ORDER BY games_won DESC
LIMIT 1

