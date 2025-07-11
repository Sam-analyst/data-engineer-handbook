-- Query 1: Deduplicate game_details from Day 1
WITH game_details_duped AS (
	SELECT
		gd.*,
		g.game_date_est,
		ROW_NUMBER() OVER (PARTITION BY gd.game_id, gd.team_id, gd.player_id ORDER BY g.game_date_est) AS row_num
	FROM game_details gd
	LEFT JOIN games g
		ON gd.game_id = g.game_id
)
SELECT *
FROM game_details_duped
WHERE row_num = 1