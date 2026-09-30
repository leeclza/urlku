module Urlku
  # Small server-rendered pages for the redirect flow (expired / not found).
  # All dynamic values are HTML-escaped.
  module Pages
    def self.expired(frontend_url : String) : String
      render(
        title: "Link kedaluwarsa",
        emoji: "⏳",
        heading: "Link ini sudah kedaluwarsa.",
        body: "Pemilik link sudah mengatur masa berlakunya dan waktunya sudah habis.",
        frontend_url: frontend_url,
      )
    end

    def self.not_found(frontend_url : String) : String
      render(
        title: "Link tidak ditemukan",
        emoji: "🔍",
        heading: "Link tidak ditemukan.",
        body: "Mungkin salah ketik, atau link ini sudah dihapus oleh pemiliknya.",
        frontend_url: frontend_url,
      )
    end

    private def self.render(title : String, emoji : String, heading : String, body : String, frontend_url : String) : String
      home = HTML.escape(frontend_url)
      <<-HTML
      <!doctype html>
      <html lang="id">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="robots" content="noindex">
        <title>#{HTML.escape(title)} · URLKU</title>
        <style>
          :root { --bg:#f7f8fb; --card:#fff; --text:#0f172a; --muted:#64748b; --primary:#4f46e5; --border:#e2e8f0; }
          @media (prefers-color-scheme: dark) { :root { --bg:#0b0f19; --card:#121826; --text:#e2e8f0; --muted:#94a3b8; --primary:#818cf8; --border:#1e293b; } }
          * { box-sizing:border-box; }
          body { margin:0; min-height:100vh; display:grid; place-items:center; padding:16px; background:var(--bg); color:var(--text);
                 font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
          .card { max-width:420px; width:100%; background:var(--card); border:1px solid var(--border); border-radius:20px; padding:32px 28px; text-align:center;
                  box-shadow: 0 1px 2px rgba(15,23,42,.04), 0 8px 24px rgba(15,23,42,.06); }
          .logo { font-weight:800; letter-spacing:-.02em; font-size:20px; margin-bottom:24px; }
          .logo span { color:var(--primary); }
          .emoji { font-size:40px; }
          h1 { font-size:22px; margin:12px 0 8px; letter-spacing:-.01em; }
          p { color:var(--muted); line-height:1.6; margin:0 0 24px; }
          a { display:inline-block; background:var(--primary); color:#fff; text-decoration:none; font-weight:600; padding:12px 20px; border-radius:12px; }
        </style>
      </head>
      <body>
        <main class="card">
          <div class="logo">URL<span>KU</span></div>
          <div class="emoji" aria-hidden="true">#{emoji}</div>
          <h1>#{HTML.escape(heading)}</h1>
          <p>#{HTML.escape(body)}</p>
          <a href="#{home}">Bikin link baru di URLKU</a>
        </main>
      </body>
      </html>
      HTML
    end
  end
end
