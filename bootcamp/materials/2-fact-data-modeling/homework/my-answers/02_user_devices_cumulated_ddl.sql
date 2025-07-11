-- Query 2: DDL for user_devices_cumulated table
CREATE TYPE device_activity_datelist AS (
	browser_type TEXT,
	active_dates DATE[]
)

CREATE TABLE user_devices_cumulated (
	user_id NUMERIC,
	snapshot_date DATE,
	device_activity_datelist device_activity_datelist[],
	PRIMARY KEY (user_id, snapshot_date)
)