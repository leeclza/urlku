module Urlku
  # Housekeeping queries used by the background CleanupJob.
  class MaintenanceService
    def initialize(@db : Database)
    end

    # Deletes links whose expiration is older than `grace` (and their clicks).
    # Returns the number of links removed.
    def prune_expired(grace : Time::Span = 0.seconds, now : Time = Time.utc) : Int64
      cutoff = (now - grace).to_utc
      matched = count("SELECT COUNT(*) FROM links WHERE expires_at IS NOT NULL AND expires_at <= ?", cutoff)
      return matched if matched == 0

      @db.conn.transaction do |tx|
        conn = tx.connection
        conn.exec(@db.sql("DELETE FROM clicks WHERE link_id IN (SELECT id FROM links WHERE expires_at IS NOT NULL AND expires_at <= ?)"), cutoff)
        conn.exec(@db.sql("DELETE FROM links WHERE expires_at IS NOT NULL AND expires_at <= ?"), cutoff)
      end
      matched
    end

    # Drops per-click analytics rows older than `days`. Totals on `links`
    # (click_count, last_clicked_at) are kept.
    def prune_clicks(days : Int32, now : Time = Time.utc) : Int64
      raise ArgumentError.new("days must be >= 1") if days < 1
      cutoff = (now - days.days).to_utc
      matched = count("SELECT COUNT(*) FROM clicks WHERE clicked_at < ?", cutoff)
      return matched if matched == 0

      @db.conn.exec(@db.sql("DELETE FROM clicks WHERE clicked_at < ?"), cutoff)
      matched
    end

    private def count(sql : String, *args) : Int64
      case value = @db.conn.scalar(@db.sql(sql), *args)
      when Int64 then value
      when Int32 then value.to_i64
      else            0_i64
      end
    end
  end

  record CleanupResult, expired_links : Int64, old_clicks : Int64

  # Periodically removes long-expired links and old click rows, so a deployed
  # instance stays tidy without anyone running manual commands.
  class CleanupJob
    def initialize(
      @maintenance : MaintenanceService,
      @interval : Time::Span,
      @expired_retention_days : Int32,
      @click_retention_days : Int32,
    )
    end

    def enabled? : Bool
      @interval > 0.seconds
    end

    def run_once(now : Time = Time.utc) : CleanupResult
      links = @maintenance.prune_expired(grace: @expired_retention_days.days, now: now)
      clicks = @click_retention_days > 0 ? @maintenance.prune_clicks(@click_retention_days, now: now) : 0_i64
      CleanupResult.new(links, clicks)
    end

    def start : Nil
      return unless enabled?
      spawn(name: "urlku-cleanup") do
        loop do
          begin
            result = run_once
            if result.expired_links > 0 || result.old_clicks > 0
              Log.info { "Cleanup: #{result.expired_links} expired link(s), #{result.old_clicks} old click row(s) removed" }
            end
          rescue ex
            Log.error(exception: ex) { "Cleanup job failed" }
          end
          sleep @interval
        end
      end
    end
  end
end
