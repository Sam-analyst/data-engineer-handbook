-- Query 6: Incremental query to generate host_activity_datelist
INSERT INTO hosts_cumulated
WITH yesterday AS (
	SELECT
		*
	FROM hosts_cumulated
	WHERE snapshot_date = '2023-01-03'
),
today AS (
	SELECT
		host,
		event_time::date AS date,
		ARRAY_AGG(DISTINCT event_time::date) AS today_datelist
	FROM events
	WHERE event_time::date = '2023-01-04'
	GROUP BY host, event_time::date
),
combined AS (
	SELECT
		COALESCE(t.host, y.host) AS host,
		COALESCE(t.date, y.snapshot_date + INTERVAL '1 Day') AS snapshot_date,
		CASE
			WHEN y.host_activity_datelist IS NULL THEN t.today_datelist
			WHEN t.today_datelist IS NULL THEN y.host_activity_datelist
			ELSE t.today_datelist || y.host_activity_datelist
		END AS host_activity_datelist
	FROM yesterday y
	FULL OUTER JOIN today t
	ON y.host = t.host
)
SELECT * FROM combined