module Urlku
  module LinkPresenter
    def self.render(link : Link, base_url : String, now : Time = Time.utc)
      {
        id:              link.id,
        short_code:      link.short_code,
        short_url:       "#{base_url}/#{link.short_code}",
        original_url:    link.original_url,
        created_at:      iso(link.created_at),
        expires_at:      link.expires_at.try { |t| iso(t) },
        click_count:     link.click_count,
        last_clicked_at: link.last_clicked_at.try { |t| iso(t) },
        status:          link.expired?(now) ? "expired" : "active",
      }
    end

    def self.stats(stats : LinkStats, base_url : String, now : Time = Time.utc)
      link = stats.link
      {
        short_code:      link.short_code,
        short_url:       "#{base_url}/#{link.short_code}",
        total_clicks:    link.click_count,
        created_at:      iso(link.created_at),
        expires_at:      link.expires_at.try { |t| iso(t) },
        last_clicked_at: link.last_clicked_at.try { |t| iso(t) },
        status:          link.expired?(now) ? "expired" : "active",
        clicks_by_date:  stats.clicks_by_date.map { |d| {date: d.date, clicks: d.clicks} },
        referrers:       stats.referrers.map { |b| {name: b.name, clicks: b.clicks} },
        devices:         stats.devices.map { |b| {name: b.name, clicks: b.clicks} },
      }
    end

    def self.iso(time : Time) : String
      time.to_utc.to_rfc3339
    end
  end
end
