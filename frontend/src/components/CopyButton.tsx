import { useCopy } from "../hooks/useCopy";
import { CheckIcon, CopyIcon } from "./Icons";

interface Props {
  text: string;
  variant?: "primary" | "ghost";
  compact?: boolean;
}

export function CopyButton({ text, variant = "primary", compact = false }: Props) {
  const { copied, copy } = useCopy();
  const cls = variant === "primary" ? "btn-primary" : "btn-ghost";

  return (
    <button
      type="button"
      onClick={() => void copy(text)}
      className={`${cls} ${copied && variant === "primary" ? "!bg-emerald-600" : ""} ${compact ? "!px-3 !py-2" : ""}`}
      aria-live="polite"
    >
      {copied ? <CheckIcon /> : <CopyIcon />}
      <span>{copied ? "Tersalin!" : "Salin"}</span>
    </button>
  );
}
