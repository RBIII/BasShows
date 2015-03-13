require 'httparty'
require 'sinatra'
require 'pg'
require 'json'
require 'pry'
enable :sessions

CONCERTS_PER_PAGE = 21

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
  end
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

def sort_shows(sort)
  options = {date: "date", band: "band", venue: "venue"}
  sort ||= "date"

  if sort == "date"
    options[:date] = "r_date"
  elsif sort == "r_date"
    options[:date] = "date"
  elsif sort == "band"
    options[:band] = "r_band"
  elsif sort == "r_band"
    options[:band] = "band"
  elsif sort == "venue"
    options[:venue] = "r_venue"
  elsif sort == "r_venue"
    options[:sort] = "venue"
  end

  options
end

def delete_old
  sql = "DELETE FROM show WHERE date < #{Time.now.strftime("%Y-%m-%d")}"

  db_connection do |conn|
    conn.exec(sql)
  end
end

def concerts(page, shows)
  start_index = (page - 1) * CONCERTS_PER_PAGE
  shows.slice(start_index, CONCERTS_PER_PAGE) || []
end

def page(page_param)
  if page_param && page_param.to_i >= 1
    page_param.to_i
  else
    1
  end
end

get "/" do
  redirect "/shows"
end

get "/shows" do
  session.delete("search")
  session.delete("q")
  @curr_order = params[:order] || "date"
  @sort_options = sort_shows(params[:order])
  @page = page(params[:page])
  @shows = concerts(@page, get_shows.sort_by { |show| show[params[:order]] })

  erb :shows
end

get "/search" do
  session["search"] = params["search"]
  sql = "SELECT * FROM show WHERE LOWER(show.band) LIKE LOWER('%#{params["search"]}%') or LOWER(show.venue) LIKE LOWER('%#{params["search"]}%');"
  @curr_order = params[:order] || "date"
  @sort_options = sort_shows(params[:order])
  @shows = db_connection do |conn|
    conn.exec(sql).to_a
  end
  unless @shows == nil
    @shows = @shows.sort_by { |show| show[params[:order]] }
  end

  erb :search
end

get "/shows.json" do
  content_type :json

  concerts(page(params[:page]), get_shows.sort_by { |show| show[params[:order]] }).to_json
end
