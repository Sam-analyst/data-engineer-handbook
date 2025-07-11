-- 03 create actors history scd

CREATE TABLE actors_history_scd (
	actor TEXT,
	actorid TEXT,
	quality_class quality_class,
	is_active BOOLEAN,
	start_year INTEGER,
	end_year INTEGER,
	current_year INTEGER,
	PRIMARY KEY (actorid, start_year)
)
