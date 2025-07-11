-- Query 3: Cumulative query to generate device_activity_datelist
INSERT INTO user_devices_cumulated
WITH yesterday AS (
	SELECT *
	FROM user_devices_cumulated
	WHERE snapshot_date = '2023-01-13'
),
today AS (
	SELECT
		e.user_id,
		d.browser_type,
		e.event_time::timestamp::date AS event_date
	FROM events e
	JOIN devices d
		ON e.device_id = d.device_id
	WHERE e.user_id IS NOT NULL
		AND d.browser_type IS NOT NULL
		AND e.event_time::timestamp::date = '2023-01-14'
	GROUP BY
		e.user_id,
		d.browser_type,
		e.event_time::timestamp::date	
),
yesterday_long AS (
	SELECT
		user_id,
		snapshot_date + INTERVAL '1 Day' AS snapshot_date,
		UNNEST(device_activity_datelist) as arr
	FROM yesterday
),
yesterdays_changed_flattened AS (
	SELECT
		user_id,
		snapshot_date,
		(arr::device_activity_datelist).*
	FROM yesterday_long
),
yesterdays_changed_flattened_again AS (
	SELECT
		user_id,
		browser_type,
		snapshot_date,
		UNNEST(active_dates) as active_date
	FROM yesterdays_changed_flattened
),
yesterday_and_today AS(
  SELECT user_id, snapshot_date, browser_type, active_date FROM yesterdays_changed_flattened_again
  UNION ALL
  SELECT user_id, event_date AS snapshot_date, browser_type, event_date AS active_date FROM today
),
yesterday_and_today_aggregated AS (
  SELECT
    user_id,
	snapshot_date,
    browser_type,
    ARRAY_AGG(DISTINCT active_date ORDER BY active_date) AS active_dates
  FROM yesterday_and_today
  GROUP BY user_id, snapshot_date, browser_type
),
final_data AS (
	SELECT
		user_id,
		snapshot_date,
		ARRAY_AGG(
			ROW(browser_type, active_dates)::device_activity_datelist
		) AS device_activity_datelist
	FROM yesterday_and_today_aggregated
	GROUP BY user_id, snapshot_date
)
SELECT *
FROM final_data
