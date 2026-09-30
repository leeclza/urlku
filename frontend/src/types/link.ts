export type LinkStatus = "active" | "expired";

export interface Link {
  id: number;
  short_code: string;
  short_url: string;
  original_url: string;
  created_at: string;
  expires_at: string | null;
  click_count: number;
  last_clicked_at: string | null;
  status: LinkStatus;
}

export interface CreatedLink extends Link {
  manage_token: string;
}

export interface CreateLinkInput {
  url: string;
  custom_alias?: string | null;
  expires_at?: string | null;
}

export interface CountBucket {
  name: string;
  clicks: number;
}

export interface LinkStats {
  short_code: string;
  short_url: string;
  total_clicks: number;
  created_at: string;
  expires_at: string | null;
  last_clicked_at: string | null;
  status: LinkStatus;
  clicks_by_date: { date: string; clicks: number }[];
  referrers: CountBucket[];
  devices: CountBucket[];
}

export interface ApiErrorBody {
  error: string;
  message: string;
}
