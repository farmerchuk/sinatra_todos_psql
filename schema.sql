CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE,
  completed boolean NOT NULL DEFAULT false,
  list_id integer REFERENCES lists (id)
);
