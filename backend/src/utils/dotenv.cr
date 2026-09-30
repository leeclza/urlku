module Urlku
  # Minimal `.env` loader for local development. Existing environment
  # variables always win, so Docker / production config is never overridden.
  module Dotenv
    def self.load(path : String = ".env") : Nil
      return unless File.exists?(path)

      File.each_line(path) do |raw|
        line = raw.strip
        next if line.empty? || line.starts_with?('#')

        key, sep, value = line.partition('=')
        next if sep.empty?

        key = key.strip.lchop("export ").strip
        value = value.strip
        if value.size >= 2 && ((value.starts_with?('"') && value.ends_with?('"')) || (value.starts_with?('\'') && value.ends_with?('\'')))
          value = value[1..-2]
        end

        ENV[key] = value unless key.empty? || ENV.has_key?(key)
      end
    end
  end
end
