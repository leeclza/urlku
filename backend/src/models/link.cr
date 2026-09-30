module Urlku
  struct Link
    include DB::Serializable

    getter id : Int64
    getter short_code : String
    getter original_url : String
    getter created_at : Time
    getter expires_at : Time?
    getter click_count : Int64
    getter last_clicked_at : Time?

    def expired?(now : Time = Time.utc) : Bool
      if expires = expires_at
        expires <= now
      else
        false
      end
    end
  end

  record DailyClicks, date : String, clicks : Int64
  record CountBucket, name : String, clicks : Int64

  record LinkStats,
    link : Link,
    clicks_by_date : Array(DailyClicks),
    referrers : Array(CountBucket),
    devices : Array(CountBucket)
end
