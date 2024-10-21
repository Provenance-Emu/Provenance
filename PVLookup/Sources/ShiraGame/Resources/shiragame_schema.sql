

CREATE TABLE game ( 
        game_id INTEGER PRIMARY KEY,
        platform_id TEXT NOT NULL,
        entry_name TEXT NOT NULL,
        entry_title TEXT,
        release_title TEXT,
        region TEXT NOT NULL,
        part_number INTEGER,
        is_unlicensed BOOLEAN NOT NULL,
        is_demo BOOLEAN NOT NULL,
        is_system BOOLEAN NOT NULL,
        version TEXT,
        status TEXT,
        naming_convention TEXT,
        source TEXT NOT NULL
    );


CREATE TABLE rom ( 
        file_name TEXT NOT NULL,
        mimetype TEXT,
        md5 TEXT,
        crc TEXT,
        sha1 TEXT,
        size INTEGER NOT NULL,
        game_id INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES game (game_id)
    );


CREATE TABLE serial ( 
        serial TEXT NOT NULL,
        normalized TEXT NOT NULL,
        game_id INTEGER NOT NULL,
        FOREIGN KEY (game_id) REFERENCES game (game_id)
    );


CREATE TABLE shiragame (
        shiragame TEXT,
        schema_version TEXT,
        stone_version TEXT,
        generated TEXT,
        release TEXT,
        aggregator TEXT
    );
