require 'httparty'
require 'sinatra'
require 'pg'
require 'pry'

def db_connection
  begin
    connection = PG.connect(dbname: "shows")
    yield(connection)
  ensure
    connection.close
  end
end

def add_show(band, date, time, venue, ticket_url)
  sql = "INSERT into show (band, date, time, venue, ticket_url) VALUES ($1, $2, $3, $4, $5)"

  db_connection do |conn|
    conn.exec_params(sql, [band, date, time, venue, ticket_url])
  end
end

def read_shows
  shows = []
  HTTParty.get("http://api.seatgeek.com/2/events?per_page=5000")["events"].each do |event|
    if event["venue"]["city"].downcase == "boston" && event["type"].downcase == "concert"
      shows << {band: event["performers"].first["name"], date: event["datetime_local"].split("T")[0],
        time: event["datetime_local"].split("T")[1], venue: event["venue"]["name"],
        tickets: event["url"]}
    end
  end
  return shows
end

def add_all_shows
  shows = read_shows
  shows.each do |show|
    add_show(show[:band], show[:date], show[:time], show[:venue], show[:tickets])
  end
end

def get_shows
  shows = db_connection do |conn|
    conn.exec("SELECT * FROM show")
  end
  return shows.to_a
end

get "/shows" do
  @shows = get_shows
  erb :shows
end
