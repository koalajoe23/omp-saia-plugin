export interface SaiaModelEntry {
  id: string;
  name: string;
  input: string[];
  output: string[];
  status: string;
}

export interface SaiaModelResponse {
  object: string;
  data: SaiaModelEntry[];
}

export interface ModelDef {
  id: string;
  name: string;
  reasoning: boolean;
  vision: boolean;
  contextWindow: number;
  maxTokens: number;
}

export interface StoredCapabilities {
  reasoning?: boolean;
  vision?: boolean;
  contextWindow?: number;
  maxTokens?: number;
  probedAt?: string;
  probeFailures?: number;
  contextScrapedAt?: string;
}

export interface ModelStore {
  version: 1;
  updatedAt: string;
  contextScrapedAt?: string;
  models: Record<string, StoredCapabilities>;
}
