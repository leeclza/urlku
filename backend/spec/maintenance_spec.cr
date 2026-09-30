require "./spec_helper"

private def maintenance
  Urlku::MaintenanceService.new(SPEC_CONTAINER.db)
end

private def expire!(code : String, at : Time)
  SPEC_CONTAINER.db.conn.exec("UPDATE links SET expires_at = ? WHERE short_code = ?", at, code)
end

private def link_codes : Array(String)
  codes = [] of String
  SPEC_CONTAINER.db.conn.query_each("SELECT short_code FROM links ORDER BY short_code") { |rs| codes << rs.read(String) }
  codes
end

describe Urlku::MaintenanceService do
  it "prunes expired links respecting the grace period" do
    create_link(custom_alias: "baru-habis")
    create_link(custom_alias: "sudah-lama")
    create_link(custom_alias: "masih-aktif")
    expire!("baru-habis", Time.utc - 1.hour)
    expire!("sudah-lama", Time.utc - 10.days)

    maintenance.prune_expired(grace: 7.days).should eq 1
    link_codes.should eq ["baru-habis", "masih-aktif"]

    maintenance.prune_expired.should eq 1
    link_codes.should eq ["masih-aktif"]
  end

  it "prunes old click rows but keeps link totals" do
    create_link(custom_alias: "klik")
    request("GET", "/klik")
    SPEC_CONTAINER.db.conn.exec("UPDATE clicks SET clicked_at = ?", Time.utc - 100.days)

    maintenance.prune_clicks(90).should eq 1
    json_body(request("GET", "/api/links/klik"))["click_count"].as_i.should eq 1
    expect_raises(ArgumentError) { maintenance.prune_clicks(0) }
  end
end

describe Urlku::CleanupJob do
  it "runs both cleanups in one pass" do
    create_link(custom_alias: "kadaluarsa")
    expire!("kadaluarsa", Time.utc - 40.days)

    job = Urlku::CleanupJob.new(maintenance, 60.minutes, expired_retention_days: 30, click_retention_days: 365)
    job.enabled?.should be_true
    result = job.run_once
    result.expired_links.should eq 1
    result.old_clicks.should eq 0
  end

  it "keeps clicks forever when retention is 0 and can be disabled" do
    create_link(custom_alias: "abadi")
    request("GET", "/abadi")
    SPEC_CONTAINER.db.conn.exec("UPDATE clicks SET clicked_at = ?", Time.utc - 1000.days)

    job = Urlku::CleanupJob.new(maintenance, 0.minutes, expired_retention_days: 30, click_retention_days: 0)
    job.enabled?.should be_false
    job.run_once.old_clicks.should eq 0
  end
end

describe Urlku::QrCode do
  it "picks the smallest version that fits" do
    Urlku::QrCode.encode("https://urlku.test/abc").version.should eq 2
    qr = Urlku::QrCode.encode("https://urlku.test/#{"a" * 32}")
    qr.size.should eq qr.version * 4 + 17
  end

  it "draws finder patterns in three corners" do
    qr = Urlku::QrCode.encode("https://urlku.test/toko")
    last = qr.size - 1
    {% for pos in [{0, 0}, {-1, 0}, {0, -1}] %}
      ox = {{pos[0]}} == -1 ? last - 6 : 0
      oy = {{pos[1]}} == -1 ? last - 6 : 0
      7.times { |i| qr.dark?(ox + i, oy).should be_true; qr.dark?(ox, oy + i).should be_true }
      qr.dark?(ox + 1, oy + 1).should be_false
      qr.dark?(ox + 3, oy + 3).should be_true
    {% end %}
    qr.dark?(8, qr.size - 8).should be_true # dark module
  end

  it "computes Reed-Solomon ECC over GF(256)" do
    Urlku::QrCode.gf_multiply(0x02, 0x80).should eq 0x1D
    Urlku::QrCode.gf_multiply(0x53, 0x01).should eq 0x53
    # Codeword count sanity: version 1-M has 16 data + 10 ECC codewords.
    Urlku::QrCode.num_data_codewords(1).should eq 16
    Urlku::QrCode.num_raw_data_modules(1).should eq 208
  end

  it "rejects data that cannot fit" do
    expect_raises(ArgumentError) { Urlku::QrCode.encode("x" * 3000) }
  end

  it "renders SVG" do
    svg = Urlku::QrCode.encode("https://urlku.test/toko").to_svg
    svg.should start_with("<svg")
    svg.should contain("h1v1h-1z")
  end
end

describe "GET /api/links/:code/qr.svg" do
  it "returns an SVG QR code for the short URL" do
    create_link(custom_alias: "qr-link")
    res = request("GET", "/api/links/qr-link/qr.svg")
    res.status_code.should eq 200
    res.headers["Content-Type"].should start_with("image/svg+xml")
    res.body.should start_with("<svg")
    res.headers["Content-Disposition"]?.should be_nil

    res = request("GET", "/api/links/qr-link/qr.svg?download=1")
    res.headers["Content-Disposition"].should contain("urlku-qr-link.svg")
  end

  it "returns 404 JSON for unknown links" do
    res = request("GET", "/api/links/tidak-ada/qr.svg")
    res.status_code.should eq 404
    json_body(res)["error"].as_s.should eq "LINK_NOT_FOUND"
  end
end
