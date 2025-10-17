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
      "Show me all rooms",
      "List all available rooms",
      "Check for maintenance",
      "Show energy report for this week",
      "What is the average temperature?",
      "Show me the highest energy consumption",
      "How many sensor records do we have?",
      "Which rooms have motion detected?",
      "Compare energy usage between different rooms",
      "Show me temperature trends over time"
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

  /**
   * Get list of all rooms with detailed information
   */
  async getRoomsList(): Promise<any> {
    try {
      // Call the LLM server's /rooms/list endpoint
      const response = await fetch('http://localhost:5000/rooms/list', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      console.log("Rooms List Response:", data);
      return data;
    } catch (error: any) {
      console.error("Rooms List Error:", error);
      throw new Error(error.message || "Failed to fetch rooms list");
    }
  }
}

export default new LLMService();
