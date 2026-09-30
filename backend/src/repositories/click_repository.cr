module Urlku
  class ClickRepository
    def initialize(@db : Database, @links : LinkRepository)
    end

    # Atomically bumps the link counter and stores one analytics row.
    def record(link_id : Int64, at : Time, referrer : String?, device : String) : Nil
      @db.conn.transaction do |tx|
        conn = tx.connection
        @links.increment_clicks(link_id, at, conn)
        conn.exec(
          @db.sql("INSERT INTO clicks (link_id, clicked_at, referrer, user_agent) VALUES (?, ?, ?, ?)"),
          link_id, at.to_utc, referrer, device
        )
      end
    end

    def clicked_times_since(link_id : Int64, since : Time) : Array(Time)
      times = [] of Time
      @db.conn.query_each(
        @db.sql("SELECT clicked_at FROM clicks WHERE link_id = ? AND clicked_at >= ?"),
        link_id, since.to_utc
      ) do |rs|
        times << rs.read(Time)
      end
      times
    end

    def top_referrers(link_id : Int64, limit : Int32 = 5) : Array(CountBucket)
      grouped(link_id, "referrer", limit)
    end

    def devices(link_id : Int64) : Array(CountBucket)
      grouped(link_id, "user_agent", 10)
    end

    # `column` is always a hard-coded identifier from this class, never user input.
    private def grouped(link_id : Int64, column : String, limit : Int32) : Array(CountBucket)
      buckets = [] of CountBucket
      @db.conn.query_each(
        @db.sql("SELECT COALESCE(#{column}, '') AS name, COUNT(*) AS total FROM clicks WHERE link_id = ? GROUP BY COALESCE(#{column}, '') ORDER BY total DESC LIMIT #{limit}"),
        link_id
      ) do |rs|
        buckets << CountBucket.new(rs.read(String), rs.read(Int64))
      end
      buckets
    end
  end
end
