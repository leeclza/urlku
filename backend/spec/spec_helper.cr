require "spec"
require "../src/urlku"

Log.setup(:none)
Kemal.config.env = "test"
Kemal.config.logging = false

SPEC_DB_PATH = File.join(Dir.tempdir, "urlku-spec-#{Process.pid}.db")
File.delete(SPEC_DB_PATH) if File.exists?(SPEC_DB_PATH)

SPEC_CONFIG = Urlku::Config.new(
  database_url: SPEC_DB_PATH,
  base_url: "https://urlku.test",
  cors_origins: ["http://localhost:5173"],
  rate_limit_create: 5,
  rate_limit_api: 1000,
)

SPEC_CONTAINER = Urlku.boot(SPEC_CONFIG)

Spec.before_each do
  SPEC_CONTAINER.db.conn.exec("DELETE FROM clicks")
  SPEC_CONTAINER.db.conn.exec("DELETE FROM links")
  SPEC_CONTAINER.create_limiter.reset
  SPEC_CONTAINER.api_limiter.reset
end

Spec.after_suite do
  SPEC_CONTAINER.db.close
  {SPEC_DB_PATH, "#{SPEC_DB_PATH}-wal", "#{SPEC_DB_PATH}-shm"}.each do |path|
    File.delete(path) if File.exists?(path)
  end
end

# Drives a request through the full Kemal handler chain in-process.
def request(method : String, path : String, body : String? = nil, headers : HTTP::Headers = HTTP::Headers.new) : HTTP::Client::Response
  headers["Content-Type"] ||= "application/json" if body
  req = HTTP::Request.new(method, path, headers, body)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(req, response)

  Kemal.config.setup
  handlers = Kemal.config.handlers
  handlers.each_cons_pair { |a, b| a.next = b }
  handlers.first.call(context)
  response.close

  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def create_link(url = "https://example.com/very/long/url", custom_alias : String? = nil, expires_at : String? = nil) : HTTP::Client::Response
  request("POST", "/api/links", {url: url, custom_alias: custom_alias, expires_at: expires_at}.to_json)
end

def json_body(response : HTTP::Client::Response) : JSON::Any
  JSON.parse(response.body)
end
