module Urlku
  class LinkService
    MAX_GENERATE_ATTEMPTS = 6
    MAX_EXPIRATION        = 3650.days
    STATS_DAYS            = 30

    def initialize(
      @links : LinkRepository,
      @clicks : ClickRepository,
      @url_validator : UrlValidator,
      @generator : ShortCodeGenerator = ShortCodeGenerator.new,
    )
    end

    # Returns the created link plus the plain management token (shown once).
    def create(url : String?, custom_alias : String?, expires_at : String?, now : Time = Time.utc) : {Link, String}
      original_url = @url_validator.validate!(url || "")
      expiry = parse_expiration(expires_at, now)
      token = Random::Secure.urlsafe_base64(24)
      token_hash = hash_token(token)

      custom = custom_alias.try(&.strip)
      link = if custom && !custom.empty?
               create_with_alias(custom, original_url, expiry, token_hash, now)
             else
               create_with_random_code(original_url, expiry, token_hash, now)
             end
      {link, token}
    end

    def find(code : String) : Link?
      return nil unless AliasValidator.plausible_code?(code)
      @links.find_by_code(code)
    end

    def find!(code : String) : Link
      find(code) || raise AppError.not_found
    end

    def find_many(codes : Array(String)) : Array(Link)
      valid = codes.map(&.strip).select { |c| AliasValidator.plausible_code?(c) }.uniq.first(100)
      @links.find_many(valid)
    end

    def delete(code : String, token : String?) : Nil
      link = find!(code)
      stored = @links.manage_token_hash(code)
      if token.nil? || token.empty? || stored.nil? || !Crypto::Subtle.constant_time_compare(stored, hash_token(token))
        raise AppError.new("FORBIDDEN", "Kamu tidak punya akses untuk menghapus link ini.", 403)
      end
      @links.delete(link.id)
    end

    def record_click(link : Link, referrer : String?, user_agent : String?, now : Time = Time.utc) : Nil
      @clicks.record(link.id, now, ClientInfo.referrer_host(referrer), ClientInfo.device_category(user_agent))
    end

    def stats(code : String, now : Time = Time.utc) : LinkStats
      link = find!(code)
      today = now.to_utc.at_beginning_of_day
      since = today - (STATS_DAYS - 1).days

      counts = Hash(String, Int64).new(0_i64)
      @clicks.clicked_times_since(link.id, since).each do |t|
        counts[t.to_utc.to_s("%F")] += 1
      end
      daily = (0...STATS_DAYS).map do |i|
        date = (since + i.days).to_s("%F")
        DailyClicks.new(date, counts[date])
      end

      referrers = @clicks.top_referrers(link.id).map do |b|
        CountBucket.new(b.name.empty? ? "Langsung" : b.name, b.clicks)
      end

      LinkStats.new(link, daily, referrers, @clicks.devices(link.id))
    end

    private def create_with_alias(custom : String, url : String, expiry : Time?, token_hash : String, now : Time) : Link
      AliasValidator.validate!(custom)
      raise alias_taken if @links.exists?(custom)
      @links.create(custom, url, expiry, token_hash, now)
    rescue DuplicateShortCode
      raise alias_taken
    end

    private def create_with_random_code(url : String, expiry : Time?, token_hash : String, now : Time) : Link
      MAX_GENERATE_ATTEMPTS.times do
        code = @generator.generate
        next if AliasValidator.reserved?(code) || @links.exists?(code)
        begin
          return @links.create(code, url, expiry, token_hash, now)
        rescue DuplicateShortCode
          next
        end
      end
      raise AppError.internal
    end

    private def parse_expiration(raw : String?, now : Time) : Time?
      return nil if raw.nil? || raw.strip.empty?
      time = begin
        Time.parse_rfc3339(raw.strip).to_utc
      rescue Time::Format::Error | ArgumentError
        raise AppError.new("INVALID_EXPIRATION", "Format tanggal kedaluwarsa tidak valid.")
      end
      raise AppError.new("INVALID_EXPIRATION", "Tanggal kedaluwarsa harus di masa depan.") if time <= now
      raise AppError.new("INVALID_EXPIRATION", "Masa berlaku maksimal 10 tahun.") if time > now + MAX_EXPIRATION
      time
    end

    private def alias_taken : AppError
      AppError.new("CUSTOM_ALIAS_TAKEN", "Alias tersebut sudah digunakan.", 409)
    end

    private def hash_token(token : String) : String
      Digest::SHA256.hexdigest(token)
    end
  end
end
