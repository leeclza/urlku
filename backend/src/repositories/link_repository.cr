module Urlku
  class LinkRepository
    COLUMNS = "id, short_code, original_url, created_at, expires_at, click_count, last_clicked_at"

    def initialize(@db : Database)
    end

    def find_by_code(code : String) : Link?
      rs = @db.conn.query(@db.sql("SELECT #{COLUMNS} FROM links WHERE short_code = ?"), code)
      Link.from_rs(rs).first?
    end

    def find_many(codes : Array(String)) : Array(Link)
      return [] of Link if codes.empty?
      placeholders = Array.new(codes.size, "?").join(", ")
      args = codes.map(&.as(DB::Any))
      rs = @db.conn.query(@db.sql("SELECT #{COLUMNS} FROM links WHERE short_code IN (#{placeholders}) ORDER BY created_at DESC"), args: args)
      Link.from_rs(rs)
    end

    def exists?(code : String) : Bool
      !@db.conn.query_one?(@db.sql("SELECT short_code FROM links WHERE short_code = ?"), code, as: String).nil?
    end

    def manage_token_hash(code : String) : String?
      @db.conn.query_one?(@db.sql("SELECT manage_token_hash FROM links WHERE short_code = ?"), code, as: String)
    end

    # Raises DuplicateShortCode when the short code is already taken.
    def create(short_code : String, original_url : String, expires_at : Time?, manage_token_hash : String, now : Time) : Link
      @db.conn.exec(
        @db.sql("INSERT INTO links (short_code, original_url, created_at, expires_at, click_count, manage_token_hash) VALUES (?, ?, ?, ?, 0, ?)"),
        short_code, original_url, now.to_utc, expires_at.try(&.to_utc), manage_token_hash
      )
      find_by_code(short_code) || raise AppError.internal
    rescue ex : AppError
      raise ex
    rescue ex
      raise DuplicateShortCode.new(short_code) if Database.unique_violation?(ex)
      raise ex
    end

    def increment_clicks(link_id : Int64, at : Time, connection : DB::Connection) : Nil
      connection.exec(
        @db.sql("UPDATE links SET click_count = click_count + 1, last_clicked_at = ? WHERE id = ?"),
        at.to_utc, link_id
      )
    end

    def delete(link_id : Int64) : Nil
      @db.conn.transaction do |tx|
        tx.connection.exec(@db.sql("DELETE FROM clicks WHERE link_id = ?"), link_id)
        tx.connection.exec(@db.sql("DELETE FROM links WHERE id = ?"), link_id)
      end
    end
  end
end
