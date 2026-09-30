module Urlku
  # Domain error with a stable machine-readable code and a user-facing
  # (Bahasa Indonesia) message. Rendered as `{"error": code, "message": msg}`.
  class AppError < Exception
    getter code : String
    getter status : Int32

    def initialize(@code : String, message : String, @status : Int32 = 400)
      super(message)
    end

    def user_message : String
      message || ""
    end

    def self.not_found : AppError
      new("LINK_NOT_FOUND", "Link tidak ditemukan.", 404)
    end

    def self.internal : AppError
      new("INTERNAL_ERROR", "Terjadi kesalahan di server. Coba lagi nanti.", 500)
    end
  end

  # Raised by repositories when a UNIQUE constraint is violated.
  class DuplicateShortCode < Exception
  end
end
