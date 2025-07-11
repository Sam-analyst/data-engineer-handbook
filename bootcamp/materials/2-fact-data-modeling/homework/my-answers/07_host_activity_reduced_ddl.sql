-- Query 7: DDL for host_activity_reduced table
CREATE TABLE host_activity_reduced (
	month_start_date DATE,
	host TEXT,
    hit_array INTEGER[],
    unique_visitors_array INTEGER[],
    PRIMARY KEY (host, month_start_date)
)