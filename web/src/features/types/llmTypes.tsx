export interface LLMQueryRequest {
  query: string;
  user_id?: string;
}

export interface LLMQueryResponse {
  success: boolean;
  query: string;
  answer: string;
  sources: Array<{
    page_content: string;
    metadata: {
      timestamp: string;
      occupancy_count: number;
      energy_kwh: number;
      power_total: number;
      temperature: number;
      humidity: number;
      doc_hash: string;
    };
  }>;
  timestamp: string;
}

export interface LLMHealthResponse {
  status: string;
  message: string;
  database_connected?: boolean;
  timestamp: string;
  error?: string;
}

// Add export keyword here
export interface ChatMessage {
  id: string;
  type: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  sources?: LLMQueryResponse['sources'];
  isLoading?: boolean;
}