module Urlku
  # Response helpers. Every body we render is also stashed in the context so
  # Kemal's `error 404/500` hooks can re-emit it instead of a generic page.
  module Http
    JSON_TYPE     = "application/json; charset=utf-8"
    HTML_TYPE     = "text/html; charset=utf-8"
    MAX_BODY_SIZE = 16_384

    def self.json(env : HTTP::Server::Context, status : Int32, payload) : String
      body = payload.to_json
      write(env, status, JSON_TYPE, body)
    end

    def self.html(env : HTTP::Server::Context, status : Int32, body : String) : String
      env.response.headers["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
      write(env, status, HTML_TYPE, body)
    end

    def self.error(env : HTTP::Server::Context, err : AppError) : String
      json(env, err.status, {error: err.code, message: err.user_message})
    end

    def self.write(env : HTTP::Server::Context, status : Int32, content_type : String, body : String) : String
      env.response.status_code = status
      env.response.content_type = content_type
      env.set("urlku.body", body)
      env.set("urlku.type", content_type)
      body
    end

    # Runs a route body, converting any exception into a safe JSON error.
    def self.guard(env : HTTP::Server::Context, & : -> String) : String
      yield
    rescue ex : AppError
      error(env, ex)
    rescue ex
      Log.error(exception: ex) { "Unhandled error on #{env.request.method} #{env.request.path}" }
      error(env, AppError.internal)
    end

    def self.read_body(env : HTTP::Server::Context) : String
      body = env.request.body
      return "" if body.nil?
      content = String.build do |io|
        IO.copy(body, io, MAX_BODY_SIZE + 1)
      end
      raise AppError.new("PAYLOAD_TOO_LARGE", "Request terlalu besar.", 413) if content.bytesize > MAX_BODY_SIZE
      content
    end
  end
end
