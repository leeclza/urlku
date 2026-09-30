import { describe, expect, it } from "vitest";
import { validateAlias, validateUrl } from "./validation";

describe("validateUrl", () => {
  it("accepts http(s) URLs", () => {
    expect(validateUrl("https://example.com/very/long/url")).toBeNull();
    expect(validateUrl("  http://example.co.id  ")).toBeNull();
  });

  it("rejects empty, schemeless and dangerous URLs", () => {
    expect(validateUrl("")).toMatch(/Tempel URL/);
    expect(validateUrl("example.com")).toMatch(/http:\/\/ atau https:\/\//);
    expect(validateUrl("javascript:alert(1)")).toMatch(/Hanya link http/);
    expect(validateUrl("data:text/html,hi")).toMatch(/Hanya link http/);
    expect(validateUrl("ftp://example.com")).toMatch(/Hanya link http/);
    expect(validateUrl("https://exa mple.com")).toMatch(/spasi/);
    expect(validateUrl(`https://example.com/${"a".repeat(2100)}`)).toMatch(/terlalu panjang/);
  });
});

describe("validateAlias", () => {
  it("allows empty (optional) and valid aliases", () => {
    expect(validateAlias("")).toBeNull();
    expect(validateAlias("toko-kamu_1")).toBeNull();
  });

  it("enforces length, charset and reserved words", () => {
    expect(validateAlias("ab")).toMatch(/3–32/);
    expect(validateAlias("a".repeat(33))).toMatch(/3–32/);
    expect(validateAlias("toko!")).toMatch(/huruf, angka/);
    expect(validateAlias("Dashboard")).toMatch(/tidak bisa dipakai/);
  });
});
