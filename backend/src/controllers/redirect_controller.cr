module Urlku
  class RedirectController
    def initialize(@service : LinkService, @config : Config)
    end

    # GET /:code
    def show(env : HTTP::Server::Context) : String?
      env.response.headers["Cache-Control"] = "no-store"
      env.response.headers["X-Robots-Tag"] = "noindex"

      link = @service.find(env.params.url["code"])
      return Http.html(env, 404, Pages.not_found(@config.frontend_url)) if link.nil?
      return Http.html(env, 410, Pages.expired(@config.frontend_url)) if link.expired?

      begin
        @service.record_click(link, env.request.headers["Referer"]?, env.request.headers["User-Agent"]?)
      rescue ex
        # Analytics must never block a redirect.
        Log.warn(exception: ex) { "Failed to record click for #{link.short_code}" }
      end

      env.redirect(link.original_url, 302, close: false)
      nil
    rescue ex
      Log.error(exception: ex) { "Redirect failed" }
      Http.html(env, 500, Pages.not_found(@config.frontend_url))
    end
  end
end
