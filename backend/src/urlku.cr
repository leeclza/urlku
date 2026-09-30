require "json"
require "html"
require "uri"
require "socket"
require "digest/sha256"
require "crypto/subtle"
require "log"
require "kemal"
require "db"
require "sqlite3"
require "pg"

require "./utils/errors"
require "./utils/dotenv"
require "./utils/user_agent"
require "./utils/http"
require "./utils/pages"
require "./config/config"
require "./config/database"
require "./models/link"
require "./repositories/link_repository"
require "./repositories/click_repository"
require "./services/url_validator"
require "./services/alias_validator"
require "./services/short_code_generator"
require "./services/rate_limiter"
require "./services/link_service"
require "./middleware/security_headers"
require "./middleware/cors"
require "./middleware/rate_limit"
require "./controllers/presenter"
require "./controllers/links_controller"
require "./controllers/redirect_controller"

module Urlku
  VERSION = "1.0.0"

  # Wires every dependency together. Kept explicit instead of using a DI lib.
  class Container
    getter config : Config
    getter db : Database
    getter link_service : LinkService
    getter create_limiter : RateLimiter
    getter api_limiter : RateLimiter

    def initialize(@config : Config)
      @db = Database.connect(config.database_url)
      @db.migrate!
      links = LinkRepository.new(@db)
      clicks = ClickRepository.new(@db, links)
      @link_service = LinkService.new(links, clicks, UrlValidator.new(config.base_host))
      @create_limiter = MemoryRateLimiter.new(config.rate_limit_create, config.rate_limit_window)
      @api_limiter = MemoryRateLimiter.new(config.rate_limit_api, config.rate_limit_window)
    end
  end

  @@container : Container?

  def self.container : Container
    @@container || raise "Urlku.boot has not been called"
  end

  # Configures Kemal (handlers + routes). Must be called exactly once.
  def self.boot(config : Config) : Container
    container = Container.new(config)
    @@container = container

    Kemal.config.powered_by_header = false
    Kemal.config.serve_static = false

    use SecurityHeadersHandler.new
    use CorsHandler.new(config.cors_origins)
    use RateLimitHandler.new(container.create_limiter, container.api_limiter, config.trust_proxy?)

    draw_routes(container)
    container
  end

  private def self.draw_routes(c : Container) : Nil
    links = LinksController.new(c.link_service, c.config)
    redirects = RedirectController.new(c.link_service, c.config)
    frontend_url = c.config.frontend_url

    get "/" do |env|
      env.redirect(frontend_url, 302, close: false)
      nil
    end

    get "/health" do |env|
      if c.db.healthy?
        Http.json(env, 200, {status: "ok", version: VERSION})
      else
        Http.json(env, 503, {status: "degraded", version: VERSION})
      end
    end

    post "/api/links" do |env|
      links.create(env)
    end

    get "/api/links" do |env|
      links.index(env)
    end

    get "/api/links/:code" do |env|
      links.show(env)
    end

    get "/api/links/:code/stats" do |env|
      links.stats(env)
    end

    delete "/api/links/:code" do |env|
      links.destroy(env)
    end

    get "/:code" do |env|
      redirects.show(env)
    end

    # Kemal routes any 404/500 status through these hooks. Re-emit the body a
    # route already rendered; otherwise produce a generic, stack-trace-free one.
    error 404 do |env|
      fallback_error(env, "NOT_FOUND", "Halaman atau endpoint tidak ditemukan.", frontend_url, 404)
    end

    error 405 do |env|
      fallback_error(env, "METHOD_NOT_ALLOWED", "Metode request tidak didukung.", frontend_url, 405)
    end

    error 500 do |env|
      fallback_error(env, "INTERNAL_ERROR", "Terjadi kesalahan di server. Coba lagi nanti.", frontend_url, 500)
    end
  end

  def self.fallback_error(env : HTTP::Server::Context, code : String, message : String, frontend_url : String, status : Int32) : String
    if (body = env.get?("urlku.body")) && (type = env.get?("urlku.type"))
      env.response.content_type = type.to_s
      return body.to_s
    end

    if env.request.path.starts_with?("/api/") || env.request.path == "/health"
      Http.json(env, status, {error: code, message: message})
    else
      Http.html(env, status, Pages.not_found(frontend_url))
    end
  end
end
