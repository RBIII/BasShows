CREATE TABLE show (
  id serial PRIMARY KEY,
  band varchar(100) NOT NULL,
  date varchar(20),
  time varchar(20),
  venue varchar(50),
  ticket_url varchar(1000)
);
