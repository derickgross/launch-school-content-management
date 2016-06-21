# test/cms_test.rb
ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"
require "minitest/rg"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def session
    last_request.env["rack.session"]
  end

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { "rack.session" => { user: "admin"} }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/", {}, admin_session

    assert_equal "admin", session[:user]
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"

  end

  def test_viewing_text_document
    create_document("history.txt", "Drunk history.")

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal "Drunk history.", last_response.body
  end

  def test_document_not_found
    get "/notafile.ext"

    assert_equal 302, last_response.status
    assert_equal session[:message], "notafile.ext does not exist."
  end

  def test_viewing_markdown_document
    create_document("about.md", "We're all *about* excellence.")
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<em>about</em> excellence."
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/create", { filename: "test.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", { filename: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_delete_document
    create_document("about.md", "We're all *about* excellence.")
    get "/", {}, admin_session
    assert_includes last_response.body, "about.md"

    get "/about.md/delete"

    assert_equal 302, last_response.status
    refute_includes last_response.body, "about.md"
  end

  def test_signin_and_signout
    get "/"
    assert_equal 302, last_response.status
  end

  def test_signin_form
    get "/users/signin", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    assert_equal session[:message], "Welcome!"
    #assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    post "/signin", username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome!"

    post "/signout"

    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, %q(<button type="submit">Sign in</button>)
  end
end