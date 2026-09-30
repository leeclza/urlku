import { useEffect, useState } from "react";
import { loadSavedLinks, type SavedLink } from "../lib/storage";

/** Reactive view of the links saved in this browser (syncs across tabs). */
export function useSavedLinks(): SavedLink[] {
  const [links, setLinks] = useState<SavedLink[]>(loadSavedLinks);

  useEffect(() => {
    const refresh = () => setLinks(loadSavedLinks());
    window.addEventListener("urlku:links-changed", refresh);
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener("urlku:links-changed", refresh);
      window.removeEventListener("storage", refresh);
    };
  }, []);

  return links;
}
