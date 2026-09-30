module Urlku
  module AliasValidator
    MIN_LENGTH = 3
    MAX_LENGTH = 32
    PATTERN    = /\A[A-Za-z0-9_-]+\z/

    # Compared case-insensitively. Covers backend routes and frontend pages.
    RESERVED = Set{
      "api", "login", "logout", "register", "signup", "dashboard", "settings",
      "about", "admin", "docs", "health", "static", "assets", "public",
      "favicon", "robots", "sitemap", "expired", "not-found", "404", "stats",
      "help", "privacy", "terms", "urlku", "www", "app",
    }

    def self.validate!(value : String) : Nil
      if value.size < MIN_LENGTH || value.size > MAX_LENGTH
        raise AppError.new("INVALID_ALIAS", "Alias harus terdiri dari #{MIN_LENGTH}–#{MAX_LENGTH} karakter.")
      end
      unless PATTERN.matches?(value)
        raise AppError.new("INVALID_ALIAS", "Alias hanya boleh berisi huruf, angka, tanda hubung (-), dan garis bawah (_).")
      end
      if reserved?(value)
        raise AppError.new("RESERVED_ALIAS", "Alias \"#{value}\" tidak bisa dipakai. Coba alias lain.")
      end
    end

    def self.reserved?(value : String) : Bool
      RESERVED.includes?(value.downcase)
    end

    # Loose check used for route params before hitting the database.
    def self.plausible_code?(value : String) : Bool
      value.size.in?(1..MAX_LENGTH) && PATTERN.matches?(value)
    end
  end
end
