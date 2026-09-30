module Urlku
  record RateLimitResult, allowed : Bool, limit : Int32, remaining : Int32, reset_in : Time::Span

  # Abstraction so the in-memory implementation can be swapped for Redis
  # (e.g. INCR + EXPIRE per key) without touching the middleware.
  abstract class RateLimiter
    abstract def hit(key : String) : RateLimitResult
    abstract def reset : Nil
  end

  # Fixed-window counter kept in process memory. Good for a single instance.
  class MemoryRateLimiter < RateLimiter
    private record Window, started_at : Time, count : Int32

    SWEEP_EVERY = 1_000

    def initialize(@limit : Int32, @window : Time::Span, @clock : Proc(Time) = ->{ Time.utc })
      @buckets = {} of String => Window
      @mutex = Mutex.new
      @hits = 0
    end

    def hit(key : String) : RateLimitResult
      @mutex.synchronize do
        now = @clock.call
        sweep(now)

        window = @buckets[key]?
        window = Window.new(now, 0) if window.nil? || now - window.started_at >= @window
        count = window.count + 1
        @buckets[key] = Window.new(window.started_at, count)

        RateLimitResult.new(
          allowed: count <= @limit,
          limit: @limit,
          remaining: Math.max(@limit - count, 0),
          reset_in: @window - (now - window.started_at),
        )
      end
    end

    def reset : Nil
      @mutex.synchronize { @buckets.clear }
    end

    private def sweep(now : Time) : Nil
      @hits += 1
      return if @hits < SWEEP_EVERY
      @hits = 0
      @buckets.reject! { |_, w| now - w.started_at >= @window }
    end
  end
end
