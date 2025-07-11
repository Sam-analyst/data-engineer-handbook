-- Query 8: Incremental query that loads host_activity_reduced
INSERT INTO host_activity_reduced
WITH yesterday AS (
	SELECT
		*
	FROM host_activity_reduced
	WHERE month_start_date = '2023-01-01'
),
today AS (
	SELECT
		host,
		event_time::date AS event_date,
		COUNT(DISTINCT user_id) AS unique_visitors,
		COUNT(1) as site_hits
	FROM events
	WHERE user_id IS NOT NULL
		AND event_time::date = '2023-01-03'
	GROUP BY host, event_time::date 
),
combined AS (
	SELECT
		COALESCE(y.month_start_date, DATE_TRUNC('month', t.event_date)) AS month_start_date,
		COALESCE(y.host, t.host) AS host,
		CASE
			WHEN y.hit_array IS NOT NULL THEN y.hit_array || ARRAY[COALESCE(t.site_hits, 0)]
			ELSE ARRAY_FILL(0, ARRAY[COALESCE(event_date::date - month_start_date, 0)]) || ARRAY[t.site_hits]
		END AS hit_array,
		CASE
			WHEN y.unique_visitors_array IS NOT NULL THEN y.unique_visitors_array || ARRAY[COALESCE(t.unique_visitors, 0)]
			ELSE ARRAY_FILL(0, ARRAY[COALESCE(event_date::date - month_start_date, 0)]) || ARRAY[t.unique_visitors]
		END AS unique_visitors_array
	FROM yesterday y
	FULL OUTER JOIN today t
		ON y.host = t.host
)
SELECT * FROM combined
ON CONFLICT (month_start_date, host)
DO
	UPDATE SET hit_array = EXCLUDED.hit_array, unique_visitors_array = EXCLUDED.unique_visitors_array