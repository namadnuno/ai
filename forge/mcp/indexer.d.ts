interface SyncStats {
  indexed: number;
  skipped: number;
  deleted: number;
  cached?: boolean;
}

interface ContextSummary {
  scope: string;
  key: string;
  updated: number;
}
