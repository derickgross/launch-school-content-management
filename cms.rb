# cms.rb
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

get "/" do
  if !session[:user]
    redirect "/users/signin"
  else
    pattern = File.join(data_path, "*")
    @files = Dir.glob(pattern).map do |path|
      File.basename(path)
    end
    erb :index
  end
end

get "/users/signin" do
  erb :signin
end

post "/signin" do
  if params[:username] == "admin" && params[:password] == "secret" 
    session[:user] = "admin"
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb "/users/signin"
  end
end

post "/signout" do
  session[:user] = nil
  session[:message] = "You have been signed out"

  erb :signin
end

get "/new" do
  erb :new
end

post "/create" do
  filename = params[:filename].strip

  if filename == ""
    session[:message] = "A name is required"
    status 422
    erb :new
  else
    File.new("./data/#{filename}", "w+")
    session[:message] = "#{filename} was created."

    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

get "/:filename/delete" do
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]

  File.delete(file_path)
  session[:message] = "#{@filename} was deleted"

  redirect "/"
end

post "/:filename" do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

# generic testing
get "/test" do
  erb :test
end