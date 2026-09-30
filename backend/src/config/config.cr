module Urlku
  # Application configuration, read from environment variables only.
  class Config
    getter port : Int32
    getter host : String
    getter database_url : String
    getter base_url : String
    getter frontend_url : String
    getter cors_origins : Array(String)
    getter rate_limit_create : Int32
    getter rate_limit_api : Int32
    getter rate_limit_window : Time::Span
    getter? trust_proxy : Bool
    getter cleanup_interval : Time::Span
    getter expired_retention_days : Int32
    getter click_retention_days : Int32

    def initialize(
      @database_url : String,
      @base_url : String,
      @cors_origins : Array(String),
      @frontend_url : String = "",
      @port : Int32 = 3000,
      @host : String = "0.0.0.0",
      @rate_limit_create : Int32 = 20,
      @rate_limit_api : Int32 = 120,
      @rate_limit_window : Time::Span = 1.minute,
      @trust_proxy : Bool = false,
      @cleanup_interval : Time::Span = 60.minutes,
      @expired_retention_days : Int32 = 30,
      @click_retention_days : Int32 = 365,
    )
      @base_url = @base_url.rstrip('/')
      @frontend_url = @frontend_url.rstrip('/')
      @frontend_url = @cors_origins.first? || @base_url if @frontend_url.empty?
    end

    def base_host : String?
      URI.parse(base_url).host.try(&.downcase)
    end

    def self.from_env : Config
      cors = ENV.fetch("CORS_ORIGIN", "http://localhost:5173")
        .split(',')
        .map(&.strip.rstrip('/'))
        .reject(&.empty?)

      new(
        port: int_env("PORT", 3000),
        host: ENV.fetch("HOST", "0.0.0.0"),
        database_url: ENV.fetch("DATABASE_URL", "./db/urlku.db"),
        base_url: ENV.fetch("BASE_URL", "http://localhost:3000"),
        frontend_url: ENV.fetch("FRONTEND_URL", ""),
        cors_origins: cors,
        rate_limit_create: int_env("RATE_LIMIT_CREATE_PER_MINUTE", 20),
        rate_limit_api: int_env("RATE_LIMIT_API_PER_MINUTE", 120),
        trust_proxy: ENV.fetch("TRUST_PROXY", "false").downcase.in?("1", "true", "yes"),
        cleanup_interval: Math.max(int_env("CLEANUP_INTERVAL_MINUTES", 60), 0).minutes,
        expired_retention_days: Math.max(int_env("EXPIRED_LINK_RETENTION_DAYS", 30), 0),
        click_retention_days: Math.max(int_env("CLICK_RETENTION_DAYS", 365), 0),
      )
    end

    private def self.int_env(key : String, default : Int32) : Int32
      ENV[key]?.try(&.to_i?) || default
    end
  end
end
