require "./spec_helper"

describe "POST /api/links" do
  it "creates a link with a random short code" do
    res = create_link
    res.status_code.should eq 201
    res.content_type.should eq "application/json"

    body = json_body(res)
    code = body["short_code"].as_s
    code.size.should eq 7
    body["short_url"].as_s.should eq "https://urlku.test/#{code}"
    body["original_url"].as_s.should eq "https://example.com/very/long/url"
    body["expires_at"].raw.should be_nil
    body["click_count"].as_i.should eq 0
    body["status"].as_s.should eq "active"
    body["manage_token"].as_s.size.should be > 20
    body["id"].as_i64.should be > 0
    Time.parse_rfc3339(body["created_at"].as_s)
  end

  it "creates a link with a custom alias" do
    res = create_link(custom_alias: "toko")
    res.status_code.should eq 201
    json_body(res)["short_url"].as_s.should eq "https://urlku.test/toko"
  end

  it "rejects a duplicate alias with a clear error" do
    create_link(custom_alias: "toko").status_code.should eq 201
    res = create_link(custom_alias: "toko")
    res.status_code.should eq 409
    body = json_body(res)
    body["error"].as_s.should eq "CUSTOM_ALIAS_TAKEN"
    body["message"].as_s.should eq "Alias tersebut sudah digunakan."
  end

  it "rejects reserved and invalid aliases" do
    json_body(create_link(custom_alias: "dashboard"))["error"].as_s.should eq "RESERVED_ALIAS"
    json_body(create_link(custom_alias: "a b"))["error"].as_s.should eq "INVALID_ALIAS"
  end

  it "rejects invalid URLs and bad JSON consistently" do
    res = create_link(url: "javascript:alert(1)")
    res.status_code.should eq 400
    json_body(res)["error"].as_s.should eq "UNSUPPORTED_SCHEME"

    res = request("POST", "/api/links", "{not json")
    res.status_code.should eq 400
    json_body(res)["error"].as_s.should eq "INVALID_JSON"
    res.body.should_not contain("Exception")
  end

  it "validates expiration" do
    json_body(create_link(expires_at: "kemarin"))["error"].as_s.should eq "INVALID_EXPIRATION"
    json_body(create_link(expires_at: (Time.utc - 1.hour).to_rfc3339))["error"].as_s.should eq "INVALID_EXPIRATION"

    future = (Time.utc + 1.day).to_rfc3339
    res = create_link(expires_at: future)
    res.status_code.should eq 201
    json_body(res)["expires_at"].as_s.should eq future
  end

  it "rate limits link creation per client" do
    5.times { create_link.status_code.should eq 201 }
    res = create_link
    res.status_code.should eq 429
    res.headers["Retry-After"]?.should_not be_nil
    json_body(res)["error"].as_s.should eq "RATE_LIMITED"
  end

  it "rejects oversized payloads" do
    res = request("POST", "/api/links", {url: "https://example.com/#{"a" * 20_000}"}.to_json)
    res.status_code.should eq 413
    json_body(res)["error"].as_s.should eq "PAYLOAD_TOO_LARGE"
  end
end

describe "GET /:code (redirect)" do
  it "redirects and increments the click counter" do
    create_link(custom_alias: "github", url: "https://github.com/crystal-lang")

    res = request("GET", "/github", headers: HTTP::Headers{"User-Agent" => "Mozilla/5.0 (iPhone) Mobile", "Referer" => "https://twitter.com/x"})
    res.status_code.should eq 302
    res.headers["Location"].should eq "https://github.com/crystal-lang"
    res.headers["Cache-Control"].should eq "no-store"

    request("GET", "/github")

    body = json_body(request("GET", "/api/links/github"))
    body["click_count"].as_i.should eq 2
    body["last_clicked_at"].as_s.should_not be_empty
  end

  it "shows a 404 page for unknown codes" do
    res = request("GET", "/nope-nope")
    res.status_code.should eq 404
    res.body.should contain("Link tidak ditemukan.")
  end

  it "does not redirect expired links" do
    create_link(custom_alias: "old-link")
    SPEC_CONTAINER.db.conn.exec("UPDATE links SET expires_at = ? WHERE short_code = ?", Time.utc - 1.minute, "old-link")

    res = request("GET", "/old-link")
    res.status_code.should eq 410
    res.headers["Location"]?.should be_nil
    res.body.should contain("Link ini sudah kedaluwarsa.")

    body = json_body(request("GET", "/api/links/old-link"))
    body["status"].as_s.should eq "expired"
    body["click_count"].as_i.should eq 0
  end
end

describe "link management API" do
  it "returns link details" do
    create_link(custom_alias: "detail")
    res = request("GET", "/api/links/detail")
    res.status_code.should eq 200
    body = json_body(res)
    body["short_code"].as_s.should eq "detail"
    body["manage_token"]?.should be_nil
  end

  it "returns 404 JSON for unknown links" do
    res = request("GET", "/api/links/unknown")
    res.status_code.should eq 404
    json_body(res)["error"].as_s.should eq "LINK_NOT_FOUND"
  end

  it "lists several links by code" do
    create_link(custom_alias: "satu")
    create_link(custom_alias: "dua")
    body = json_body(request("GET", "/api/links?codes=satu,dua,tidak-ada,bad%20code"))
    body["links"].as_a.map(&.["short_code"].as_s).sort.should eq ["dua", "satu"]
  end

  it "returns statistics" do
    create_link(custom_alias: "statsy")
    request("GET", "/statsy", headers: HTTP::Headers{"User-Agent" => "Mozilla/5.0 (Windows NT 10.0)", "Referer" => "https://t.co/abc"})

    res = request("GET", "/api/links/statsy/stats")
    res.status_code.should eq 200
    body = json_body(res)
    body["total_clicks"].as_i.should eq 1
    days = body["clicks_by_date"].as_a
    days.size.should eq 30
    days.last["date"].as_s.should eq Time.utc.to_s("%F")
    days.last["clicks"].as_i.should eq 1
    body["referrers"][0]["name"].as_s.should eq "t.co"
    body["devices"][0]["name"].as_s.should eq "desktop"
  end

  it "deletes a link only with the manage token" do
    token = json_body(create_link(custom_alias: "hapus"))["manage_token"].as_s

    res = request("DELETE", "/api/links/hapus")
    res.status_code.should eq 403
    request("DELETE", "/api/links/hapus", headers: HTTP::Headers{"X-Manage-Token" => "wrong"}).status_code.should eq 403

    request("GET", "/hapus")
    res = request("DELETE", "/api/links/hapus", headers: HTTP::Headers{"X-Manage-Token" => token})
    res.status_code.should eq 204
    request("GET", "/api/links/hapus").status_code.should eq 404
  end
end

describe "CORS and misc" do
  it "answers preflight for allowed origins only" do
    res = request("OPTIONS", "/api/links", headers: HTTP::Headers{"Origin" => "http://localhost:5173"})
    res.status_code.should eq 204
    res.headers["Access-Control-Allow-Origin"].should eq "http://localhost:5173"

    res = request("OPTIONS", "/api/links", headers: HTTP::Headers{"Origin" => "https://evil.example"})
    res.headers["Access-Control-Allow-Origin"]?.should be_nil
  end

  it "reports health" do
    res = request("GET", "/health")
    res.status_code.should eq 200
    json_body(res)["status"].as_s.should eq "ok"
  end

  it "returns JSON 404 for unknown API routes" do
    res = request("GET", "/api/nothing/here/at-all")
    res.status_code.should eq 404
    json_body(res)["error"].as_s.should eq "NOT_FOUND"
  end
end
