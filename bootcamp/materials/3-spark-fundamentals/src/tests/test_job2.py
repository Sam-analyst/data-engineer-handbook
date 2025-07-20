from chispa.dataframe_comparer import *

from ..jobs.job2 import agg_host_activity
from collections import namedtuple
from datetime import date

hosts_cumulated = namedtuple("hosts_cumulated",  "host snapshot_date host_activity_datelist")
events = namedtuple("events",  "host event_time")

def test_dedupe_game_details(spark):
    input_data_hosts_cumulated = [
        # Make sure basic case is handled gracefully
        hosts_cumulated(
            host="admin.zachwilson.tech",
            snapshot_date=date(2023, 1, 3),
            host_activity_datelist=[
                date(2023, 1, 3),
                date(2023, 1, 2),
                date(2023, 1, 1)
            ]
        )
    ]

    input_data_events = [
        events(
            host="admin.zachwilson.tech",
            event_time="2023-01-04 11:55:28.032000"
        ),
        events(
            host="admin.zachwilson.tech",
            event_time="2023-01-04 09:55:28.032000"
        ),
    ]

    source_df_host_cumulated = spark.createDataFrame(input_data_hosts_cumulated)
    source_df_events = spark.createDataFrame(input_data_events)
    actual_df = agg_host_activity(spark, source_df_host_cumulated, source_df_events, "2023-01-04")

    expected_values = [
        hosts_cumulated(
            host="admin.zachwilson.tech",
            snapshot_date=date(2023, 1, 4),
            host_activity_datelist=[
                date(2023, 1, 4),
                date(2023, 1, 3),
                date(2023, 1, 2),
                date(2023, 1, 1)
            ]
        )
    ]
    expected_df = spark.createDataFrame(expected_values)
    assert_df_equality(actual_df, expected_df)