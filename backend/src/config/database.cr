module Urlku
  enum Dialect
    Sqlite
    Postgres
  end

  # Thin wrapper around a crystal-db pool that hides dialect differences.
  # Repositories write SQL with `?` placeholders; `#sql` rewrites them to
  # `$1, $2, ...` for PostgreSQL.
  class Database
    SQLITE_SCHEMA   = {{ read_file("#{__DIR__}/../../db/schema.sqlite.sql") }}
    POSTGRES_SCHEMA = {{ read_file("#{__DIR__}/../../db/schema.postgres.sql") }}

    getter conn : DB::Database
    getter dialect : Dialect

    def initialize(@conn : DB::Database, @dialect : Dialect)
    end

    def self.connect(url : String) : Database
      if url.starts_with?("postgres://") || url.starts_with?("postgresql://")
        new(DB.open(url), Dialect::Postgres)
      else
        path = url.lchop("sqlite3://")
        dir = File.dirname(path)
        Dir.mkdir_p(dir) unless dir.empty? || dir == "." || Dir.exists?(dir)
        params = "journal_mode=wal&busy_timeout=5000&foreign_keys=true&synchronous=normal"
        new(DB.open("sqlite3://#{path}?#{params}"), Dialect::Sqlite)
      end
    end

    def sql(query : String) : String
      return query if @dialect.sqlite?
      index = 0
      query.gsub("?") { index += 1; "$#{index}" }
    end

    def migrate! : Nil
      schema = @dialect.postgres? ? POSTGRES_SCHEMA : SQLITE_SCHEMA
      statements = schema.lines.reject(&.strip.starts_with?("--")).join('\n').split(';')
      statements.each do |statement|
        stmt = statement.strip
        @conn.exec(stmt) unless stmt.empty?
      end
    end

    def healthy? : Bool
      @conn.scalar("SELECT 1")
      true
    rescue
      false
    end

    def close : Nil
      @conn.close
    end

    def self.unique_violation?(ex : Exception) : Bool
      msg = ex.message || ""
      msg.includes?("UNIQUE constraint failed") || msg.includes?("duplicate key value")
    end
  end
end
