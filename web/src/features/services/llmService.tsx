import axiosInstance from "../../service/AppService.tsx";
import type { LLMQueryRequest, LLMQueryResponse, LLMHealthResponse } from "../types/llmTypes";

class LLMService {
  /**
   * Send a query to the LLM
   */
  async queryLLM(request: LLMQueryRequest): Promise<LLMQueryResponse> {
    try {
      const response = await axiosInstance.post<LLMQueryResponse>("/api/llm/query/", request);
      console.log("Query LLM Response:", response.data);
      return response.data;
    } catch (error: any) {
      console.error("LLM Query Error:", error.response || error.message || error);
      throw new Error(
        error.response?.data?.error ||
        error.message ||
        "Failed to query LLM"
      );
    }
  }

  /**
   * Check LLM health status
   */
  async checkHealth(): Promise<LLMHealthResponse> {
    try {
      const response = await axiosInstance.get<LLMHealthResponse>("/api/llm/health/");
      console.log("Health Check Response:", response.data);
      return response.data;
    } catch (error: any) {
      console.error("LLM Health Check Error:", error.response || error.message || error);
      throw new Error(
        error.response?.data?.error ||
        error.message ||
        "Failed to check LLM health"
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
   * Generate a unique ID for messages
   */
  generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

export default new LLMService();
