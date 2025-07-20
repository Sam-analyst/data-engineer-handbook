from chispa.dataframe_comparer import *

from ..jobs.job1 import dedupe_game_details
from collections import namedtuple

game_details = namedtuple("game_details",  "game_id team_id player_id game_date_est")

def test_dedupe_game_details(spark):
    input_data = [
        # Make sure basic case is handled gracefully
        game_details(
            game_id=22000001,
            team_id=1610612744,
            player_id=201939,
            game_date_est="2020-12-22"
        ),
        game_details(
            game_id=22000001,
            team_id=1610612744,
            player_id=201939,
            game_date_est="2020-12-22"
        ),
        # make sure date works properly
        game_details(
            game_id=22000001,
            team_id=1610612744,
            player_id=202954,
            game_date_est="2020-12-22"
        ),
        game_details(
            game_id=22000001,
            team_id=1610612744,
            player_id=202954,
            game_date_est="2020-12-21"
        ),
    ]

    source_df = spark.createDataFrame(input_data)
    actual_df = dedupe_game_details(spark, source_df)

    expected_values = [
        game_details(
            game_id=22000001,
            team_id=1610612744,
            player_id=201939,
            game_date_est="2020-12-22"
        ),
        game_details(
            game_id=22000001,
            team_id=1610612744,
            player_id=202954,
            game_date_est="2020-12-22"
        )
    ]
    expected_df = spark.createDataFrame(expected_values)
    assert_df_equality(actual_df, expected_df)