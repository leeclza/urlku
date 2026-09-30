module Urlku
  # Applies a strict limiter to link creation and a looser one to the rest of
  # the API (slows down alias enumeration via GET /api/links/:code).
  class RateLimitHandler
    include HTTP::Handler

    def initialize(@create_limiter : RateLimiter, @api_limiter : RateLimiter, @trust_proxy : Bool = false)
    end

    def call(context : HTTP::Server::Context)
      request = context.request
      limiter =
        if request.method == "POST" && request.path.rstrip('/') == "/api/links"
          @create_limiter
        elsif request.path.starts_with?("/api/")
          @api_limiter
        end
      return call_next(context) if limiter.nil?

      result = limiter.hit(client_key(request))
      headers = context.response.headers
      headers["X-RateLimit-Limit"] = result.limit.to_s
      headers["X-RateLimit-Remaining"] = result.remaining.to_s

      if result.allowed
        call_next(context)
      else
        headers["Retry-After"] = Math.max(result.reset_in.total_seconds.ceil.to_i, 1).to_s
        context.response.status_code = 429
        context.response.content_type = Http::JSON_TYPE
        context.response.print({error: "RATE_LIMITED", message: "Terlalu banyak permintaan. Coba lagi sebentar lagi, ya."}.to_json)
      end
    end

    private def client_key(request : HTTP::Request) : String
      if @trust_proxy
        if forwarded = request.headers["X-Forwarded-For"]?
          first = forwarded.split(',').first.strip
          return first unless first.empty?
        end
      end

      case address = request.remote_address
      when Socket::IPAddress then address.address
      else                        "unknown"
      end
    end
  end
end
