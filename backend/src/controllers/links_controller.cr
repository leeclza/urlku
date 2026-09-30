module Urlku
  struct CreateLinkRequest
    include JSON::Serializable

    getter url : String?
    getter custom_alias : String?
    getter expires_at : String?
  end

  class LinksController
    def initialize(@service : LinkService, @config : Config)
    end

    # POST /api/links
    def create(env : HTTP::Server::Context) : String
      Http.guard(env) do
        request = parse_request(Http.read_body(env))
        link, token = @service.create(request.url, request.custom_alias, request.expires_at)
        Http.json(env, 201, LinkPresenter.render(link, @config.base_url).merge({manage_token: token}))
      end
    end

    # GET /api/links?codes=a,b,c
    def index(env : HTTP::Server::Context) : String
      Http.guard(env) do
        codes = (env.params.query["codes"]? || "").split(',')
        links = @service.find_many(codes)
        now = Time.utc
        Http.json(env, 200, {links: links.map { |l| LinkPresenter.render(l, @config.base_url, now) }})
      end
    end

    # GET /api/links/:code
    def show(env : HTTP::Server::Context) : String
      Http.guard(env) do
        link = @service.find!(env.params.url["code"])
        Http.json(env, 200, LinkPresenter.render(link, @config.base_url))
      end
    end

    # GET /api/links/:code/stats
    def stats(env : HTTP::Server::Context) : String
      Http.guard(env) do
        stats = @service.stats(env.params.url["code"])
        Http.json(env, 200, LinkPresenter.stats(stats, @config.base_url))
      end
    end

    # DELETE /api/links/:code  (requires X-Manage-Token)
    def destroy(env : HTTP::Server::Context) : String
      Http.guard(env) do
        @service.delete(env.params.url["code"], env.request.headers["X-Manage-Token"]?)
        env.response.status_code = 204
        ""
      end
    end

    private def parse_request(body : String) : CreateLinkRequest
      CreateLinkRequest.from_json(body)
    rescue JSON::ParseException
      raise AppError.new("INVALID_JSON", "Format request tidak valid.")
    end
  end
end
