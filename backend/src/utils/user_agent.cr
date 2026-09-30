module Urlku
  # Reduces a raw User-Agent / Referer to coarse, privacy-friendly values.
  # We never persist the full User-Agent string or the client IP.
  module ClientInfo
    BOT_PATTERN    = /bot|crawl|spider|slurp|preview|facebookexternalhit|whatsapp|telegram|curl|wget|python|httpclient|go-http|okhttp|java\//i
    TABLET_PATTERN = /ipad|tablet|kindle|silk|playbook/i
    MOBILE_PATTERN = /mobi|iphone|ipod|android|blackberry|opera mini|iemobile/i

    CATEGORIES = %w(desktop mobile tablet bot lainnya)

    def self.device_category(user_agent : String?) : String
      ua = user_agent.try(&.strip) || ""
      return "lainnya" if ua.empty?
      return "bot" if BOT_PATTERN.matches?(ua)
      return "tablet" if TABLET_PATTERN.matches?(ua)
      return "mobile" if MOBILE_PATTERN.matches?(ua)
      return "desktop" if ua.includes?("Mozilla")
      "lainnya"
    end

    # Keeps only the host of the referrer (e.g. "twitter.com").
    def self.referrer_host(referrer : String?) : String?
      return nil if referrer.nil? || referrer.empty? || referrer.size > 2048
      host = URI.parse(referrer).host
      return nil if host.nil? || host.empty?
      host.downcase.lchop("www.")[0, 255]
    rescue URI::Error
      nil
    end
  end
end
