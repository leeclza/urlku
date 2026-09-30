/**
 * URLKU wordmark. The mark is a "folded" link: a long stroke that bends and
 * gets cut short, ending in a dot — a shortened URL in one gesture.
 */
export function LogoMark({ className = "h-8 w-8" }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" className={className} aria-hidden="true">
      <rect width="32" height="32" rx="9" className="fill-brand-600" />
      <path d="M9 10.5v6.2a5 5 0 0 0 5 5h1.2" fill="none" stroke="#fff" strokeWidth="3" strokeLinecap="round" />
      <path
        d="M18 21.7h1.5a3.5 3.5 0 0 0 3.5-3.5V10.5"
        fill="none"
        stroke="#fff"
        strokeWidth="3"
        strokeLinecap="round"
        opacity=".55"
      />
      <circle cx="23" cy="23.5" r="2.2" fill="#a5b4fc" />
    </svg>
  );
}

export function Logo() {
  return (
    <span className="inline-flex items-center gap-2">
      <LogoMark />
      <span className="text-xl font-extrabold tracking-tight">
        URL<span className="text-brand-600 dark:text-brand-400">KU</span>
      </span>
    </span>
  );
}
