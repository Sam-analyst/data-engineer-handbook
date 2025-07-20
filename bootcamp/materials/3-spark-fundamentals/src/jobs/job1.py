from pyspark.sql import SparkSession


def dedupe_game_details(spark, dataframe):
    query = """
    WITH game_details_duped AS (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY game_id, team_id, player_id ORDER BY game_date_est DESC) AS row_num
        FROM game_details
    )
    SELECT
        game_id,
        team_id,
        player_id,
        game_date_est
    FROM game_details_duped
    WHERE row_num = 1
    """
    dataframe.createOrReplaceTempView("game_details")
    return spark.sql(query)


def main():
    spark = SparkSession.builder \
      .master("local") \
      .appName("game_details_deduped") \
      .getOrCreate()
    output_df = dedupe_game_details(spark, spark.table("game_details"))
    output_df.write.mode("overwrite").insertInto("game_details_deduped")