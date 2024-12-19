

CREATE TABLE developers (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE franchises (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE games (
    id INTEGER PRIMARY KEY,
    serial_id TEXT,
    -- rom_id INTEGER,
    developer_id INTEGER,
    publisher_id INTEGER,
    rating_id INTEGER,
    users INTEGER,
    franchise_id INTEGER,
    release_year INTEGER,
    release_month INTEGER,
    region_id INTEGER,
    genre_id INTEGER,
    display_name TEXT,
    full_name TEXT,
    -- boxart_url TEXT,
    platform_id INTEGER
);


CREATE TABLE genres (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE manufacturers (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE platforms (
    id INTEGER PRIMARY KEY,
    name TEXT,
    manufacturer_id INTEGER
);


CREATE TABLE publishers (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE ratings (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE regions (
    id INTEGER PRIMARY KEY,
    name TEXT
);


CREATE TABLE roms (
    id INTEGER PRIMARY KEY,
    serial_id TEXT,
    name TEXT,
    md5 TEXT
);


-- Add artwork table
CREATE TABLE artwork (
    id INTEGER PRIMARY KEY,
    serial_id TEXT,
    type TEXT,      -- boxart, screenshot, titlescreen, etc.
    url TEXT,       -- URL to the artwork
    FOREIGN KEY(serial_id) REFERENCES games(serial_id)
);


-- Create index for faster artwork lookups
CREATE INDEX idx_artwork_serial_id ON artwork(serial_id);
CREATE INDEX idx_artwork_type ON artwork(type);
