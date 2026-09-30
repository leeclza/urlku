require "./urlku"

Urlku::Dotenv.load
Log.setup_from_env(default_level: :info)

config = Urlku::Config.from_env
Urlku.boot(config)

Kemal.config.env = ENV.fetch("KEMAL_ENV", "production")
Kemal.config.host_binding = config.host
Kemal.config.shutdown_message = false

Log.info { "URLKU API #{Urlku::VERSION} → #{config.base_url} (listening on #{config.host}:#{config.port})" }
Kemal.run(config.port)
