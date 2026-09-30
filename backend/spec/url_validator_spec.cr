require "./spec_helper"

private def validator
  Urlku::UrlValidator.new("urlku.test")
end

private def error_code(url : String) : String?
  validator.validate!(url)
  nil
rescue ex : Urlku::AppError
  ex.code
end

describe Urlku::UrlValidator do
  it "accepts http and https URLs" do
    validator.validate!("https://example.com/products?id=1").should eq "https://example.com/products?id=1"
    validator.validate!("http://sub.example.co.id/path#frag").should eq "http://sub.example.co.id/path#frag"
    validator.validate!("  https://example.com  ").should eq "https://example.com"
    validator.validate!("https://8.8.8.8/dns").should eq "https://8.8.8.8/dns"
  end

  it "rejects dangerous schemes" do
    error_code("javascript:alert(1)").should eq "UNSUPPORTED_SCHEME"
    error_code("JaVaScRiPt:alert(1)").should eq "UNSUPPORTED_SCHEME"
    error_code("data:text/html,<script>alert(1)</script>").should eq "UNSUPPORTED_SCHEME"
    error_code("file:///etc/passwd").should eq "UNSUPPORTED_SCHEME"
    error_code("ftp://example.com/file").should eq "UNSUPPORTED_SCHEME"
    error_code("vbscript:msgbox").should eq "UNSUPPORTED_SCHEME"
  end

  it "rejects malformed input" do
    error_code("").should eq "INVALID_URL"
    error_code("example.com").should eq "INVALID_URL"
    error_code("https://").should eq "INVALID_URL"
    error_code("https:example.com").should eq "INVALID_URL"
    error_code("https://exa mple.com").should eq "INVALID_URL"
    error_code("https://example.com/\r\nSet-Cookie: x").should eq "INVALID_URL"
    error_code("https://nodot").should eq "INVALID_URL"
    error_code("https://user:pass@example.com").should eq "INVALID_URL"
  end

  it "rejects excessively long URLs" do
    error_code("https://example.com/#{"a" * 2100}").should eq "URL_TOO_LONG"
  end

  it "blocks local and private hosts" do
    %w(
      http://localhost:8080 http://app.localhost http://127.0.0.1 http://10.0.0.5
      http://192.168.1.1 http://172.16.0.1 http://169.254.169.254/latest
      http://0.0.0.0 http://[::1]/ http://printer.local
    ).each do |url|
      error_code(url).should eq("BLOCKED_HOST"), "expected #{url} to be blocked"
    end
    error_code("http://127.1").should eq "INVALID_URL"
  end

  it "blocks URLKU's own domain to avoid redirect loops" do
    error_code("https://urlku.test/abc").should eq "BLOCKED_HOST"
  end
end
