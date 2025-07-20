from pyspark.sql import SparkSession
from datetime import datetime, timedelta

def agg_host_activity(spark, hosts_cumulated, events, date):

    date_today = datetime.strptime(date, "%Y-%m-%d")
    date_yesterday = date_today - timedelta(days=1)

    date_today_str = date_today.strftime("'%Y-%m-%d'")
    date_yesterday_str = date_yesterday.strftime("'%Y-%m-%d'")

    query = f"""
    WITH yesterday AS (
	SELECT
		*
	FROM hosts_cumulated
	WHERE snapshot_date = {date_yesterday_str}
    ),
    today AS (
        SELECT
            host,
            event_time::date AS date,
            ARRAY_AGG(DISTINCT event_time::date) AS today_datelist
        FROM events
        WHERE event_time::date = {date_today_str}
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
    """
    hosts_cumulated.createOrReplaceTempView("hosts_cumulated")
    events.createOrReplaceTempView("events")

    return spark.sql(query)


def main():
    spark = SparkSession.builder \
      .master("local") \
      .appName("host_activity_datelist") \
      .getOrCreate()
    output_df = agg_host_activity(
        spark,
        spark.table("hosts_cumulated"),
        spark.table("events"),
        date
    )
    output_df.write.mode("overwrite").insertInto("host_activity_datelist")