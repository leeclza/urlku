module Urlku
  # Allow-list based CORS. Only origins listed in CORS_ORIGIN are reflected.
  class CorsHandler
    include HTTP::Handler

    def initialize(@origins : Array(String))
    end

    def call(context : HTTP::Server::Context)
      request = context.request
      origin = request.headers["Origin"]?

      if origin && allowed?(origin)
        headers = context.response.headers
        headers["Access-Control-Allow-Origin"] = origin
        headers["Vary"] = "Origin"
        headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type, X-Manage-Token"
        headers["Access-Control-Expose-Headers"] = "Retry-After, X-RateLimit-Limit, X-RateLimit-Remaining"
        headers["Access-Control-Max-Age"] = "600"
      end

      if request.method == "OPTIONS"
        context.response.status_code = 204
        return
      end

      call_next(context)
    end

    private def allowed?(origin : String) : Bool
      @origins.includes?("*") || @origins.includes?(origin.rstrip('/'))
    end
  end
end
