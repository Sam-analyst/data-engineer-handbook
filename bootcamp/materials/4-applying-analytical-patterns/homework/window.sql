WITH melted_games AS (
	SELECT
	    game_id,
	    game_date_est,
	    season,
	    team_id_home AS team_id,
	    'home' AS home_away,
	    pts_home AS pts,
	    CASE WHEN home_team_wins = 1 THEN 1 ELSE 0 END AS win
	FROM games
	UNION ALL
	SELECT
	    game_id,
	    game_date_est,
	    season,
	    team_id_away AS team_id,
	    'away' AS home_away,
	    pts_away AS pts,
	    CASE WHEN home_team_wins = 0 THEN 1 ELSE 0 END AS win
	FROM games
	ORDER BY game_id, team_id
),
distinct_teams AS (
	SELECT
		DISTINCT
			team_id,
			nickname
	FROM teams
),
melted_games_final AS (
	SELECT
		mg.game_id,
		mg.game_date_est,
		mg.season,
		mg.team_id,
		mg.home_away,
		mg.pts,
		mg.win,
		t.nickname
	FROM melted_games mg
	JOIN distinct_teams t
		ON mg.team_id = t.team_id
), rolling_wins AS (
	SELECT
		*,
		SUM(win) OVER (
				PARTITION BY team_id
				ORDER BY game_date_est
				ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
		) AS rolling_win_90
	FROM melted_games_final
)
SELECT * FROM rolling_wins ORDER BY rolling_win_90 DESC LIMIT(1)
-- golden state warriors had most wins in 90 day rolling window with 77

-- lebron james question
WITH games_with_dates AS (
	SELECT
		gd.game_id,
		g.game_date_est,
		gd.player_name,
		gd.pts,
		CASE WHEN gd.pts > 10 THEN 1 ELSE 0 END AS scored_over_10_pts
	FROM game_details gd
	JOIN games g ON gd.game_id = g.game_id
	WHERE gd.player_name = 'LeBron James'
	  AND gd.comment IS NULL
),
all_games AS (
	SELECT *,
		ROW_NUMBER() OVER (ORDER BY game_date_est, game_id) AS rn_all
	FROM games_with_dates
),
over_10_games AS (
	SELECT *,
		ROW_NUMBER() OVER (ORDER BY game_date_est, game_id) AS rn_over_10
	FROM all_games
	WHERE scored_over_10_pts = 1
),
streak_base AS (
	SELECT
		g.game_id,
		g.game_date_est,
		g.player_name,
		g.pts,
		g.scored_over_10_pts,
		g.rn_all,
		o.rn_over_10,
		-- Create a streak group: stays constant during a streak
		g.rn_all - o.rn_over_10 AS streak_group
	FROM all_games g
	LEFT JOIN over_10_games o
		ON g.game_id = o.game_id
)
-- Now count the streaks
SELECT
	player_name,
	MIN(game_date_est) AS streak_start_date,
	MAX(game_date_est) AS streak_end_date,
	COUNT(*) AS streak_length
FROM streak_base
WHERE scored_over_10_pts = 1
GROUP BY player_name, streak_group
ORDER BY streak_length DESC
-- answer: 134 games