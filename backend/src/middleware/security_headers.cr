module Urlku
  class SecurityHeadersHandler
    include HTTP::Handler

    def call(context : HTTP::Server::Context)
      headers = context.response.headers
      headers["X-Content-Type-Options"] = "nosniff"
      headers["X-Frame-Options"] = "DENY"
      headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
      headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
      call_next(context)
    end
  end
end
