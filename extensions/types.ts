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
