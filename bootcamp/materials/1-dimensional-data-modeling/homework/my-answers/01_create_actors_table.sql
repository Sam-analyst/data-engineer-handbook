-- 01 create actors table

-- create the films struct
CREATE TYPE films AS (
	film TEXT,
	year INTEGER, -- included this because i wanted to
	votes INTEGER,
	rating REAL,
	filmid TEXT
)

-- create the quality_class. used enum to enforce categories
CREATE TYPE quality_class AS ENUM ('star', 'good', 'average', 'bad')

-- create the actors table
CREATE TABLE actors (
	actor TEXT,
	actorid TEXT,
	films films[],
	quality_class quality_class,
	is_active BOOLEAN,
	current_year INTEGER,
	PRIMARY KEY(actorid, current_year)
)