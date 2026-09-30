require "./spec_helper"

describe Urlku::ShortCodeGenerator do
  it "generates codes of the configured length from the safe alphabet" do
    gen = Urlku::ShortCodeGenerator.new
    100.times do
      code = gen.generate
      code.size.should eq 7
      code.each_char { |c| Urlku::ShortCodeGenerator::ALPHABET.includes?(c).should be_true }
    end
  end

  it "is collision-resistant in practice" do
    gen = Urlku::ShortCodeGenerator.new
    codes = Set(String).new
    10_000.times { codes << gen.generate }
    codes.size.should eq 10_000
  end
end

describe Urlku::AliasValidator do
  it "accepts valid aliases" do
    ["toko", "abc", "youtube", "my-link", "my_link", "A1b2C3", "a" * 32].each do |a|
      Urlku::AliasValidator.validate!(a)
    end
  end

  it "rejects invalid aliases" do
    ["ab", "a" * 33, "has space", "emoji😀", "slash/x", "dot.x", "%20x"].each do |a|
      expect_raises(Urlku::AppError) { Urlku::AliasValidator.validate!(a) }
    end
  end

  it "rejects reserved routes case-insensitively" do
    %w(api login register dashboard settings about admin docs health API Admin).each do |a|
      ex = expect_raises(Urlku::AppError) { Urlku::AliasValidator.validate!(a) }
      ex.code.should eq "RESERVED_ALIAS"
    end
  end
end

describe Urlku::MemoryRateLimiter do
  it "allows up to the limit then blocks until the window resets" do
    now = Time.utc(2026, 9, 30, 12, 0, 0)
    limiter = Urlku::MemoryRateLimiter.new(3, 1.minute, ->{ now })

    3.times { limiter.hit("a").allowed.should be_true }
    blocked = limiter.hit("a")
    blocked.allowed.should be_false
    blocked.remaining.should eq 0

    limiter.hit("b").allowed.should be_true

    now += 61.seconds
    limiter.hit("a").allowed.should be_true
  end
end

describe Urlku::ClientInfo do
  it "categorizes user agents" do
    Urlku::ClientInfo.device_category("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148").should eq "mobile"
    Urlku::ClientInfo.device_category("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)").should eq "tablet"
    Urlku::ClientInfo.device_category("Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120").should eq "desktop"
    Urlku::ClientInfo.device_category("Googlebot/2.1").should eq "bot"
    Urlku::ClientInfo.device_category(nil).should eq "lainnya"
  end

  it "keeps only the referrer host" do
    Urlku::ClientInfo.referrer_host("https://www.twitter.com/some/path?x=1").should eq "twitter.com"
    Urlku::ClientInfo.referrer_host("not a url").should be_nil
    Urlku::ClientInfo.referrer_host(nil).should be_nil
  end
end
