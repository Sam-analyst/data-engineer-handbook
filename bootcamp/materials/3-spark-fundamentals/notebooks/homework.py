from pyspark.sql import SparkSession
from pyspark.sql import functions as f
from pyspark.sql import Window

spark = SparkSession.builder.appName("homework_job").getOrCreate()
spark

# setting auto broadcasting off
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")
print("new broadcast threshold:", spark.conf.get("spark.sql.autoBroadcastJoinThreshold"))

# reading medals df
medals_df = spark.read.option("header","true").csv("/home/iceberg/data/medals.csv")
maps_df = spark.read.option("header","true").csv("/home/iceberg/data/maps.csv")
medals_matches_players_df = spark.read.option("header","true").csv("/home/iceberg/data/medals_matches_players.csv")
matches_df = spark.read.option("header","true").csv("/home/iceberg/data/matches.csv")
match_details_df = spark.read.option("header","true").csv("/home/iceberg/data/match_details.csv")

# create iceberg table DDL for bucketed tables

# match_details
match_details_bucketed_DDL = """
CREATE TABLE bootcamp.match_details_bucketed (
match_id STRING,
player_gamertag STRING,
previous_spartan_rank STRING,
spartan_rank STRING,
previous_total_xp STRING,
total_xp STRING,
previous_csr_tier STRING,
previous_csr_designation STRING,
previous_csr STRING,
previous_csr_percent_to_next_tier STRING,
previous_csr_rank STRING,
current_csr_tier STRING,
current_csr_designation STRING,
current_csr STRING,
current_csr_percent_to_next_tier STRING,
current_csr_rank STRING,
player_rank_on_team STRING,
player_finished STRING,
player_average_life STRING,
player_total_kills STRING,
player_total_headshots STRING,
player_total_weapon_damage STRING,
player_total_shots_landed STRING,
player_total_melee_kills STRING,
player_total_melee_damage STRING,
player_total_assassinations STRING,
player_total_ground_pound_kills STRING,
player_total_shoulder_bash_kills STRING,
player_total_grenade_damage STRING,
player_total_power_weapon_damage STRING,
player_total_power_weapon_grabs STRING,
player_total_deaths STRING,
player_total_assists STRING,
player_total_grenade_kills STRING,
did_win STRING,
team_id STRING
)
USING iceberg
PARTITIONED BY (bucket(16, match_id));
"""
spark.sql(match_details_bucketed_DDL)

# matches
matches_bucketed_DDL = """
CREATE TABLE bootcamp.matches_bucketed (
match_id STRING,
mapid STRING,
is_team_game STRING,
playlist_id STRING,
game_variant_id STRING,
is_match_over STRING,
completion_date STRING,
match_duration STRING,
game_mode STRING,
map_variant_id STRING
)
USING iceberg
PARTITIONED BY (bucket(16, match_id));
"""
spark.sql(matches_bucketed_DDL)

# medal_matches_players 
medal_matches_players_bucketed_DDL = """
CREATE TABLE bootcamp.medal_matches_players_bucketed (
match_id STRING,
player_gamertag STRING,
medal_id STRING,
count STRING
)
USING iceberg
PARTITIONED BY (bucket(16, match_id));
"""
spark.sql(medal_matches_players_bucketed_DDL)

# now save em out
(match_details_df
 .write
 .mode("append")
 .bucketBy(16, "match_id")
 .saveAsTable("bootcamp.match_details_bucketed")
)

(matches_df
 .write
 .mode("append")
 .bucketBy(16, "match_id")
 .saveAsTable("bootcamp.matches_bucketed")
)

(medals_matches_players_df
 .write
 .mode("append")
 .bucketBy(16, "match_id")
 .saveAsTable("bootcamp.medal_matches_players_bucketed")
)

# now save em out
match_details_df_bucketed = spark.read.table("bootcamp.match_details_bucketed")
matches_df_bucketed = spark.read.table("bootcamp.matches_bucketed")
medals_matches_players_df_bucketed = spark.read.table("bootcamp.medal_matches_players_bucketed")

# for some reason, spark plan prints sortmergejoin and not bucketjoin. please analyze my code above and explain whats going on
medals_matches_players_df_bucketed.join(matches_df_bucketed, on="match_id", how="inner").explain()

joined_df = (
    match_details_df_bucketed
    .join(medals_matches_players_df_bucketed, on=["match_id", "player_gamertag"], how="left")
    .join(matches_df_bucketed, on="match_id", how="inner")
    .join(f.broadcast(maps_df), on="mapid", how="inner")
    .join(
        f.broadcast(
            (medals_df
             .withColumnRenamed("description", "medal_description")
             .withColumnRenamed("name", "medal_name")
            )
        ), on="medal_id", how="left")
)

joined_df.limit(5).toPandas()

# which player averages the most kills per game?
avg_kills_per_game = (match_details_df
 .groupBy("player_gamertag")
 .agg(f.avg("player_total_kills").alias("avg_kills"))
 .withColumn("rank", f.dense_rank().over(Window.orderBy(f.col("avg_kills").desc())))
 .filter(f.col("rank") == 1)
)

avg_kills_per_game.toPandas()

# which playlist gets played the most?
mosted_played_playlist = (matches_df_bucketed
 .groupBy("playlist_id")
 .agg(f.count("playlist_id").alias("num_matches"))
 .withColumn("rank", f.dense_rank().over(Window.orderBy(f.col("num_matches").desc())))
 .filter(f.col("rank") == 1)
)

mosted_played_playlist.toPandas()

# which map gets played the most?
mosted_played_map = (
    matches_df_bucketed
    .join(f.broadcast(maps_df), on="mapid", how="left")
    .groupBy("name")
    .agg(f.count("*").alias("num_matches"))
    .withColumn("rank", f.dense_rank().over(Window.orderBy(f.col("num_matches").desc())))
    .filter(f.col("rank") == 1)
)

mosted_played_map.limit(10).toPandas()

# which map do players get the most killing spree medals on?
killing_spree_medals = (
    medals_df
    .filter(f.col("name") == "Killing Spree")
    .withColumnRenamed("name", "medal_name")
)

maps_with_most_killing_sprees = (
    medals_matches_players_df_bucketed
    .withColumnRenamed("count", "num_medals")
    .join(f.broadcast(killing_spree_medals), on="medal_id", how="inner")
    .join(matches_df_bucketed.select("match_id", "mapid"), on="match_id", how="inner")
    .join(f.broadcast(maps_df), on="mapid", how="inner")
    .groupBy("name")
    .agg(f.sum("num_medals").alias("num_medals"))
    .withColumn("rank", f.dense_rank().over(Window.orderBy(f.col("num_medals").desc())))
    .filter(f.col("rank") == 1)
)
maps_with_most_killing_sprees.limit(5).toPandas()

# matches
last_question_DDL = """
CREATE TABLE bootcamp.last_question_v3 (
    medal_id STRING,
    mapid STRING,
    match_id STRING,
    player_gamertag STRING,
    previous_spartan_rank STRING,
    spartan_rank STRING,
    previous_total_xp STRING,
    total_xp STRING,
    previous_csr_tier STRING,
    previous_csr_designation STRING,
    previous_csr STRING,
    previous_csr_percent_to_next_tier STRING,
    previous_csr_rank STRING,
    current_csr_tier STRING,
    current_csr_designation STRING,
    current_csr STRING,
    current_csr_percent_to_next_tier STRING,
    current_csr_rank STRING,
    player_rank_on_team STRING,
    player_finished STRING,
    player_average_life STRING,
    player_total_kills STRING,
    player_total_headshots STRING,
    player_total_weapon_damage STRING,
    player_total_shots_landed STRING,
    player_total_melee_kills STRING,
    player_total_melee_damage STRING,
    player_total_assassinations STRING,
    player_total_ground_pound_kills STRING,
    player_total_shoulder_bash_kills STRING,
    player_total_grenade_damage STRING,
    player_total_power_weapon_damage STRING,
    player_total_power_weapon_grabs STRING,
    player_total_deaths STRING,
    player_total_assists STRING,
    player_total_grenade_kills STRING,
    did_win STRING,
    team_id STRING,
    count STRING,
    is_team_game STRING,
    playlist_id STRING,
    game_variant_id STRING,
    is_match_over STRING,
    completion_date STRING,
    match_duration STRING,
    game_mode STRING,
    map_variant_id STRING,
    name STRING,
    description STRING,
    sprite_uri STRING,
    sprite_left STRING,
    sprite_top STRING,
    sprite_sheet_width STRING,
    sprite_sheet_height STRING,
    sprite_width STRING,
    sprite_height STRING,
    classification STRING,
    medal_description STRING,
    medal_name STRING,
    difficulty STRING
)
USING iceberg
"""

spark.sql(last_question_DDL)

# without sortings
joined_df.write.mode("overwrite").saveAsTable("bootcamp.last_question_v3")


spark.sql(
"SELECT SUM(file_size_in_bytes) as size, COUNT(1) AS num_files FROM demo.bootcamp.last_question_v3.files;"
)

# now sort within partitoins by playlists and maps
joined_df.sortWithinPartitions("playlist_id", "mapid").write.mode("overwrite").saveAsTable("bootcamp.last_question_v3")

spark.sql(
"SELECT SUM(file_size_in_bytes) as size, COUNT(1) AS num_files FROM demo.bootcamp.last_question_v3.files;"
)

spark.sql(
"SELECT SUM(file_size_in_bytes) as size, COUNT(1) AS num_files FROM demo.bootcamp.last_question_v3.files;"
)

joined_df.sortWithinPartitions("playlist_id", "mapid", "player_gamertag").write.mode("overwrite").saveAsTable("bootcamp.last_question_v3")

spark.sql(
"SELECT SUM(file_size_in_bytes) as size, COUNT(1) AS num_files FROM demo.bootcamp.last_question_v3.files;"
)

## answer, compression is best when the joined df is saved out as-is. but, when i sort on a random
# column like player_total_kills, memory increases by about 10%