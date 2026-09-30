module Urlku
  # Cryptographically random short codes. Visually ambiguous characters
  # (0/O, 1/l/I) are removed. 7 chars over 56 symbols ≈ 1.7 × 10¹² codes.
  class ShortCodeGenerator
    ALPHABET       = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    DEFAULT_LENGTH = 7

    def initialize(@length : Int32 = DEFAULT_LENGTH)
    end

    def generate : String
      String.build(@length) do |io|
        @length.times { io << ALPHABET[Random::Secure.rand(ALPHABET.size)] }
      end
    end
  end
end
