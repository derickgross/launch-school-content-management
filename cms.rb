# cms.rb
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
require "pry"

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

def get_filename
  if ENV["RACK_ENV"] == "test"
    "../test/users.yaml"
  else
    "./users.yaml"
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

def user_credentials(file)
  YAML.load_file(file)
end

def check_logged_in
  if !session[:user]
    session[:message] = "You must be signed in to do that"
    redirect "/"
  end
end

def valid_credentials?(password, username, filename)
  binding.pry
  if !user_credentials(filename)[username.to_sym]
    false
  else
    bcrypt_password = BCrypt::Password.new(user_credentials(filename)[username.to_sym])
    bcrypt_password == password
  end
end

VALID_EXTENSIONS = ["txt", "md"]

def valid_file_extension?(filename)
  extension = filename.split(".").last
  VALID_EXTENSIONS.include? extension
end

def check_admin_credentials
  if session[:user] != "admin"
    session[:message] = "No such action is available"
    redirect "/"
  end
end

def invalid_new_username?
  user_credentials(get_filename)[params[:username]]
end

def invalid_new_password?
  params[:password] != params[:confirm_password]
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

get "/user_credentials" do
  check_admin_credentials

  @filename = "./users.yaml"
  @content = user_credentials(@filename)

  erb :edit
end

post "/user_credentials" do
  check_admin_credentials

  credentials_path = File.expand_path("../", __FILE__)

  file_path = File.join(credentials_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

def set_file_name
  if ENV["RACK_ENV"] == "test"
    "./test/users.yaml"
  else
    "./users.yaml"
  end
end

post "/signin" do
  filename = get_filename
  if valid_credentials?(params[:password], params[:username], filename)
    session[:user] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/signout" do
  session[:user] = nil
  session[:message] = "You have been signed out"

  erb :signin
end

get "/register" do
  erb :register
end

post "/register" do
  if invalid_new_username?
    session[:message] = "That username is not available.  Please choose another."
    erb :register
  elsif invalid_new_password?
    session[:message] = "Your password does not match what you re-entered.  Please try again."
    erb :register
  else
    content = user_credentials(get_filename)
    content[params[:username].to_sym] = BCrypt::Password.create(params[:password])

    File.open("/users.yaml", "w") do |f|
      f.write(content)
    end

    session[:message] = "You have been registered.  Please sign in."
    erb :test
  end
end

get "/new" do
  check_logged_in
  erb :new
end

post "/create" do
  check_logged_in

  filename = params[:filename].strip

  if filename == ""
    session[:message] = "A name is required"
    status 422
    erb :new
  elsif !valid_file_extension?(filename)
    session[:message] = "File must have a valid extension: #{VALID_EXTENSIONS.join(", ")}."
    status 422
    erb :new
  else
    if params[:duplicate] == "duplicate"
      filename = "copy_of_" + filename
      File.new("./data/#{filename}", "w+")
    else
      File.new("./data/#{filename}", "w+")
    end
    session[:message] = "#{filename} was created."

    redirect "/"
  end
end

# generic testing
get "/test" do
  @credentials = user_credentials(get_filename)
  @guest_pass = @credentials[:guest]
  erb :test
end

# testing form submissions
post "/test" do
  @filename = params[:filename]
  erb :test
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
  check_logged_in

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

get "/:filename/delete" do
  check_logged_in

  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]

  File.delete(file_path)
  session[:message] = "#{@filename} was deleted"

  redirect "/"
end

post "/:filename" do
  check_logged_in

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end
