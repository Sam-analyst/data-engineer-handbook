-- Query 5: DDL for hosts_cumulated table
CREATE TABLE hosts_cumulated (
    host TEXT,
    snapshot_date DATE,
    host_activity_datelist DATE[],
    PRIMARY KEY (host, snapshot_date)
);