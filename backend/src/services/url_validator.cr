module Urlku
  # Syntax-only URL validation. We never make network requests to the
  # destination (no SSRF surface); we only look at scheme and host.
  class UrlValidator
    MAX_LENGTH      = 2048
    ALLOWED_SCHEMES = {"http", "https"}
    BLOCKED_SUFFIXES = {".localhost", ".local", ".internal", ".lan", ".home.arpa"}
    HOST_PATTERN    = /\A[\p{L}\p{N}](?:[\p{L}\p{N}-]{0,62}[\p{L}\p{N}])?(?:\.[\p{L}\p{N}](?:[\p{L}\p{N}-]{0,62}[\p{L}\p{N}])?)+\z/
    IPV4_PATTERN    = /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\z/

    def initialize(@own_host : String? = nil)
    end

    # Returns the cleaned URL or raises AppError.
    def validate!(raw : String) : String
      url = raw.strip
      raise invalid("URL wajib diisi.") if url.empty?
      raise AppError.new("URL_TOO_LONG", "URL terlalu panjang (maksimal #{MAX_LENGTH} karakter).") if url.size > MAX_LENGTH
      raise invalid("URL tidak boleh mengandung spasi atau karakter khusus.") if url.each_char.any? { |c| c.whitespace? || c.control? }

      scheme = url.match(/\A([a-zA-Z][a-zA-Z0-9+.\-]*):/).try(&.[1].downcase)
      raise invalid("URL harus diawali dengan http:// atau https://.") if scheme.nil?
      unless ALLOWED_SCHEMES.includes?(scheme)
        raise AppError.new("UNSUPPORTED_SCHEME", "Hanya link http:// dan https:// yang bisa dipendekkan.")
      end

      uri = begin
        URI.parse(url)
      rescue URI::Error
        raise invalid("Format URL tidak valid.")
      end

      raise invalid("Format URL tidak valid.") unless url.downcase.starts_with?("#{scheme}://")
      raise invalid("URL tidak boleh berisi username atau password.") if uri.user || uri.password

      host = (uri.host || "").downcase.strip('[').strip(']').rstrip('.')
      raise invalid("URL harus memiliki domain yang valid.") if host.empty?
      check_host!(host)

      url
    end

    private def check_host!(host : String) : Nil
      if host == "localhost" || BLOCKED_SUFFIXES.any? { |s| host.ends_with?(s) }
        raise blocked
      end

      if host.includes?(':')
        # IPv6 literal: block loopback, unspecified, unique-local, link-local, mapped.
        raise blocked if host.in?("::1", "::") || host.starts_with?("fc") || host.starts_with?("fd") ||
                         host.starts_with?("fe80") || host.starts_with?("::ffff:")
        return
      end

      if m = IPV4_PATTERN.match(host)
        octets = (1..4).map { |i| m[i].to_i }
        raise invalid("Alamat IP tidak valid.") if octets.any? { |o| o > 255 }
        raise blocked if private_ipv4?(octets)
        return
      end

      unless HOST_PATTERN.matches?(host)
        raise invalid("URL harus memiliki domain yang valid.")
      end

      # e.g. "127.1" or "10.0.0" — numeric TLDs are shorthand IPs, not domains.
      raise invalid("URL harus memiliki domain yang valid.") if host.split('.').last.each_char.all?(&.ascii_number?)

      if own = @own_host
        raise AppError.new("BLOCKED_HOST", "Link URLKU tidak bisa dipendekkan lagi.") if host == own
      end
    end

    private def private_ipv4?(o : Array(Int32)) : Bool
      o[0] == 0 || o[0] == 10 || o[0] == 127 ||
        (o[0] == 169 && o[1] == 254) ||
        (o[0] == 172 && (16..31).includes?(o[1])) ||
        (o[0] == 192 && o[1] == 168) ||
        (o[0] == 100 && (64..127).includes?(o[1])) ||
        o[0] >= 224
    end

    private def invalid(message : String) : AppError
      AppError.new("INVALID_URL", message)
    end

    private def blocked : AppError
      AppError.new("BLOCKED_HOST", "Alamat lokal atau jaringan internal tidak diizinkan.")
    end
  end
end
