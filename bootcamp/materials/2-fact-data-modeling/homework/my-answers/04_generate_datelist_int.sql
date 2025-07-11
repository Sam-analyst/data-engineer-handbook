-- Query 4: Convert device_activity_datelist to datelist_int
WITH dates AS (
SELECT
	GENERATE_SERIES(MIN(snapshot_date)::DATE, MAX(snapshot_date)::DATE, '1 day')::DATE AS date
FROM user_devices_cumulated
),
flattened_user_devices AS (
	SELECT
		user_id,
		snapshot_date,
		(UNNEST(device_activity_datelist)::device_activity_datelist).*
	FROM user_devices_cumulated
	WHERE snapshot_date = '2023-01-14'
),
placeholder_int AS (
SELECT
	*,
	(CASE
		WHEN active_dates @> ARRAY[date] THEN POW(2, 31 - (snapshot_date - date))
		ELSE 0
	END)::bigint as placeholder_int_value
FROM flattened_user_devices
CROSS JOIN dates
),
cumulated_dates AS (
SELECT
	user_id,
	snapshot_date,
	browser_type,
	active_dates,
	CAST(SUM(placeholder_int_value)::bigint AS BIT(32)) AS active_datelist_int
FROM placeholder_int
GROUP BY user_id, snapshot_date, browser_type, active_dates
)
SELECT
	user_id,
	snapshot_date,
	ARRAY_AGG(
		ROW(browser_type, active_datelist_int)
	)
FROM cumulated_dates
GROUP BY user_id, snapshot_date