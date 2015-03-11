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
  counter = 1
  until counter >= 18
    HTTParty.get("http://api.seatgeek.com/2/events?per_page=5000&page=#{counter}")["events"].each do |event|
      if event["venue"]["city"].downcase == "boston" && event["type"].downcase == "concert"
        shows << {band: event["performers"].first["name"], date: event["datetime_local"].split("T")[0],
          time: event["datetime_local"].split("T")[1], venue: event["venue"]["name"],
          tickets: event["url"]}
      end
    end
    counter += 1
    puts counter
  end
  binding.pry
  return shows
end

def add_all_shows
  new_shows = read_shows
  current_shows = get_shows_without_id
  new_shows.each do |show|
    unless current_shows.include?({"band" => show[:band], "date" => show[:date],
      "time" => show[:time], "venue" => show[:venue], "ticket_url" => show[:tickets]})
      add_show(show[:band], show[:date], show[:time], show[:venue], show[:tickets])
    end
  end
end

def get_shows_without_id
  shows = db_connection do |conn|
    conn.exec("SELECT band, date, time, venue, ticket_url FROM show")
  end
  return shows.to_a
end

def get_shows
  shows = db_connection do |conn|
    conn.exec("SELECT * FROM show")
  end
  return shows.to_a
end

get "/" do
  redirect "/shows"
end

get "/shows" do
  @shows = get_shows
  erb :shows
end

add_all_shows
