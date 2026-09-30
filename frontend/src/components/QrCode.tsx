import { useState } from "react";
import { qrCodeUrl } from "../services/api";

interface Props {
  code: string;
  size?: "sm" | "md";
}

/** QR image rendered by the backend (pure Crystal encoder), plus a download link. */
export function QrCode({ code, size = "md" }: Props) {
  const [failed, setFailed] = useState(false);
  const dim = size === "sm" ? "h-28 w-28" : "h-40 w-40";

  return (
    <div className="flex flex-col items-center gap-2">
      <div className={`${dim} overflow-hidden rounded-xl border border-slate-200 bg-white p-1 dark:border-night-line`}>
        {failed ? (
          <div className="grid h-full place-items-center text-center text-xs text-slate-500">QR tidak tersedia</div>
        ) : (
          <img
            src={qrCodeUrl(code)}
            alt={`QR code untuk /${code}`}
            className="h-full w-full"
            loading="lazy"
            onError={() => setFailed(true)}
          />
        )}
      </div>
      {!failed && (
        <a href={qrCodeUrl(code, true)} className="text-xs font-semibold text-brand-700 hover:underline dark:text-brand-300">
          Unduh QR
        </a>
      )}
    </div>
  );
}
