import axiosInstance from './AppService';

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

class LLMService {
  /**
   * Send a query to the LLM
   */
  async queryLLM(request: LLMQueryRequest): Promise<LLMQueryResponse> {
    try {
      const response = await axiosInstance.post('/api/llm/query/', request);
      console.log('Query LLM Response:', response.data); // Debug log
      return response.data;
    } catch (error: any) {
      console.error('LLM Query Error:', error.response || error.message || error); // Enhanced error logging
      throw new Error(
        error.response?.data?.error || 
        error.message || 
        'Failed to query LLM'
      );
    }
  }

  /**
   * Check LLM health status
   */
  async checkHealth(): Promise<LLMHealthResponse> {
    try {
      const response = await axiosInstance.get('/api/llm/health/');
      console.log('Health Check Response:', response.data); // Debug log
      return response.data;
    } catch (error: any) {
      console.error('LLM Health Check Error:', error.response || error.message || error); // Enhanced error logging
      throw new Error(
        error.response?.data?.error || 
        error.message || 
        'Failed to check LLM health'
      );
    }
  }

  /**
   * Get suggested queries for the user
   */
  getSuggestedQueries(): string[] {
    return [
      "What is the average temperature?",
      "Show me the highest energy consumption",
      "How many sensor records do we have?",
      "What was the temperature at 2024-01-15 10:30:00?",
      "Which rooms have motion detected?",
      "Compare energy usage between different rooms",
      "Show me temperature trends over time",
      "What is the lowest humidity recorded?",
      "List all equipment that is offline",
      "What are the power consumption patterns?"
    ];
  }

  /**
   * Format timestamp for display
   */
  formatTimestamp(timestamp: string): string {
    try {
      return new Date(timestamp).toLocaleString();
    } catch {
      return timestamp;
    }
  }

  /**
   * quiet a unique ID for messages
   */
  generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

export default new LLMService();