

CREATE TABLE game_alternates (
            game_id INTEGER,
            alternate_title TEXT,
            PRIMARY KEY (game_id, alternate_title),
            FOREIGN KEY (game_id) REFERENCES games(id)
        );


CREATE TABLE game_artwork (
            id INTEGER PRIMARY KEY,
            game_id INTEGER,
            type TEXT,
            side TEXT,
            filename TEXT,
            resolution TEXT,
            FOREIGN KEY (game_id) REFERENCES games(id)
        );


CREATE TABLE game_developers (
            game_id INTEGER,
            developer_id INTEGER,
            PRIMARY KEY (game_id, developer_id),
            FOREIGN KEY (game_id) REFERENCES games(id)
        );


CREATE TABLE game_genres (
            game_id INTEGER,
            genre_id INTEGER,
            PRIMARY KEY (game_id, genre_id),
            FOREIGN KEY (game_id) REFERENCES games(id)
        );


CREATE TABLE game_publishers (
            game_id INTEGER,
            publisher_id INTEGER,
            PRIMARY KEY (game_id, publisher_id),
            FOREIGN KEY (game_id) REFERENCES games(id)
        );


CREATE TABLE games (
            id INTEGER PRIMARY KEY,
            game_title TEXT NOT NULL,
            release_date TEXT,
            platform INTEGER,
            region_id INTEGER,
            country_id INTEGER,
            overview TEXT,
            youtube TEXT,
            players INTEGER,
            coop TEXT,
            rating TEXT,
            FOREIGN KEY (platform) REFERENCES systems(id)
        );


CREATE TABLE systems (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            alias TEXT
        );
