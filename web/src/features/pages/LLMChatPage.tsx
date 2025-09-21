import React, { useState, useEffect, useRef } from "react";
import PageLayout from "./PageLayout";
import LLMService from "../../service/LLMService";
import type { ChatMessage } from "../../service/LLMService";
import "./LLMChatPage.css";

// Define API endpoint types
type QueryType = "general" | "maintenance" | "anomalies" | "energy" | "utilization" | "summary" | "context";

// Define possible user roles
type UserRole = "viewer" | "technician" | "energy_analyst" | "facility_manager" | "admin";

const LLMChatPage: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [llmHealth, setLlmHealth] = useState<string>("checking");
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Scroll to bottom when new messages are added
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // Check LLM health on component mount
  useEffect(() => {
    checkLLMHealth();
  }, []);

  const checkLLMHealth = async () => {
    try {
      const response = await fetch("http://localhost:5000/health");
      const health = await response.json();
      setLlmHealth(health.status);
    } catch (error) {
      console.error("Health check failed:", error);
      setLlmHealth("unhealthy");
    }
  };

  // Function to determine query type based on content
  const determineQueryType = (query: string): QueryType => {
    const lowerQuery = query.toLowerCase();
    
    if (lowerQuery.includes("maintenance") || lowerQuery.includes("repair") || 
        lowerQuery.includes("fix") || lowerQuery.includes("broken")) {
      return "maintenance";
    } else if (lowerQuery.includes("anomal") || lowerQuery.includes("unusual") || 
               lowerQuery.includes("strange") || lowerQuery.includes("weird")) {
      return "anomalies";
    } else if (lowerQuery.includes("energy") || lowerQuery.includes("power") || 
               lowerQuery.includes("kwh") || lowerQuery.includes("consumption")) {
      return "energy";
    } else if (lowerQuery.includes("room") || lowerQuery.includes("utilization") || 
               lowerQuery.includes("usage") || lowerQuery.includes("occupied")) {
      return "utilization";
    } else if (lowerQuery.includes("summary") || lowerQuery.includes("report") || 
               lowerQuery.includes("week") || lowerQuery.includes("overview")) {
      return "summary";
    } else if (lowerQuery.includes("context") || lowerQuery.includes("situation") || 
               lowerQuery.includes("current state")) {
      return "context";
    }
    
    return "general";
  };

  // Function to determine user role based on query content
  const determineUserRole = (queryType: QueryType): UserRole => {
    switch (queryType) {
      case "maintenance":
      case "anomalies":
        return "facility_manager";
      case "energy":
        return "energy_analyst";
      case "summary":
        return "viewer";
      case "utilization":
      case "context":
      case "general":
      default:
        return "viewer";
    }
  };

  // Function to call appropriate API endpoint
  const callAPIEndpoint = async (query: string, type: QueryType) => {
    let endpoint = "/llmquery";
    let body = { query, type };
    
    switch (type) {
      case "maintenance":
        endpoint = "/maintenance/predict";
        body = { query: query || "Analyze logs for maintenance suggestions" };
        break;
      case "anomalies":
        endpoint = "/anomalies/detect";
        body = { sensitivity: 0.8 };
        break;
      case "energy":
        endpoint = "/insights/energy";
        body = { analysis_type: "trends" };
        break;
      case "utilization":
        endpoint = "/rooms/utilization";
        body = {};
        break;
      case "summary":
        endpoint = "/reports/weekly";
        body = { type: "executive" };
        break;
      case "context":
        endpoint = "/context/analyze";
        body = { query: query || "Analyze current situation" };
        break;
    }
    
    try {
      const userRole = determineUserRole(type);
      const response = await fetch(`http://localhost:5000${endpoint}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-User-Role": userRole
        },
        body: JSON.stringify(body)
      });
      
      if (!response.ok) {
        if (response.status === 401 || response.status === 403) {
          throw new Error(`Permission denied. Inferred role (${userRole}) doesn't have access to this feature.`);
        }
        throw new Error(`API error: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error(`API call failed for ${endpoint}:`, error);
      throw error;
    }
  };

  const handleSendMessage = async (query?: string) => {
    const messageText = query || inputValue.trim();
    if (!messageText || isLoading) return;

    setInputValue("");
    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      type: "user",
      content: messageText,
      timestamp: new Date(),
    };
    const loadingMessage: ChatMessage = {
      id: (Date.now() + 1).toString(),
      type: "assistant",
      content: "Thinking...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, userMessage, loadingMessage]);
    setIsLoading(true);

    try {
      const queryType = determineQueryType(messageText);
      const response = await callAPIEndpoint(messageText, queryType);
      let answer = "";

      switch (queryType) {
        case "maintenance":
          answer = `Maintenance Analysis:\n\n${response.maintenance_suggestions.length} maintenance suggestions found.\n${response.anomalies.length} anomalies detected.\n\nKey suggestions:\n${response.maintenance_suggestions.slice(0, 3).map((m: any) => `• ${m.equipment}: ${m.issue} (${m.urgency})`).join("\n")}`;
          break;
        case "anomalies":
          answer = `Anomaly Detection:\n\n${response.anomalies.length} anomalies found (${response.summary.critical} critical).\n\nCritical issues:\n${response.anomalies.filter((a: any) => a.severity === "Critical").slice(0, 3).map((a: any) => `• ${a.type} at ${a.location}`).join("\n")}`;
          break;
        case "energy":
          answer = `Energy Analysis:\n\n${response.insights || "No specific energy insights available."}`;
          break;
        case "utilization":
          answer = `Room Utilization:\n\n${response.summary || "Room utilization data not available."}`;
          break;
        case "summary":
          answer = `Weekly Summary:\n\n${response.executive_summary || "No summary available."}`;
          break;
        case "context":
          answer = `Context Analysis:\n\n${response.context_analysis || "No context analysis available."}`;
          break;
        default:
          answer = response.answer || "No response received.";
      }

      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === loadingMessage.id
            ? { ...msg, content: answer, isLoading: false }
            : msg
        )
      );
    } catch (error: any) {
      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === loadingMessage.id
            ? { ...msg, content: `Sorry, I encountered an error: ${error.message}`, isLoading: false }
            : msg
        )
      );
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const handleSuggestionClick = (suggestion: string) => {
    handleSendMessage(suggestion);
  };

  const clearChat = () => {
    setMessages([]);
  };

  const getSuggestions = () => {
    return [
      "What's the most used room?",
      "Any energy consumption trends?",
      "Show me weekly summary",
      "Check for maintenance issues",
      "Detect anomalies",
      "Analyze energy usage patterns",
    ];
  };

  return (
    <PageLayout initialSection={{ parent: "LLM" }}>
      <div className="orb-chat-container">
        <div className={`orb-health-status orb-health-${llmHealth}`}>
          <span className="orb-health-indicator"></span>
          LLM Status: {llmHealth}
          {llmHealth !== "healthy" && (
            <button onClick={checkLLMHealth} className="orb-retry-button">
              Retry
            </button>
          )}
        </div>

        {messages.length === 0 ? (
          <>
            <div className="orb-greeting">
              <h2>Hello, I am Orb!</h2>
              <p>I can help you analyze your building's sensor data and energy consumption.</p>
              <p>Your role will be automatically determined based on your question.</p>
              <p>Ask me questions about temperature, humidity, energy usage, and more!</p>
            </div>
            <div className="orb-suggestions">
              <h3>Try asking:</h3>
              {getSuggestions().map((text, index) => (
                <button
                  key={index}
                  className="orb-suggestion-button"
                  onClick={() => handleSuggestionClick(text)}
                  disabled={isLoading}
                >
                  {text}
                </button>
              ))}
            </div>
          </>
        ) : (
          <div className="orb-messages">
            {messages.map((message: ChatMessage) => (
              <div key={message.id} className={`orb-message orb-message-${message.type}`}>
                <div className="orb-message-content">
                  {message.isLoading ? (
                    <div className="orb-loading">
                      <div className="orb-loading-dots">
                        <span></span>
                        <span></span>
                        <span></span>
                      </div>
                    </div>
                  ) : (
                    <p>{message.content}</p>
                  )}
                </div>
                <div className="orb-message-time">
                  {message.timestamp.toLocaleTimeString()}
                </div>
              </div>
            ))}
            <div ref={messagesEndRef} />
          </div>
        )}

        {messages.length > 0 && (
          <div className="orb-chat-actions">
            <button onClick={clearChat} className="orb-clear-button">
              Clear Chat
            </button>
          </div>
        )}
      </div>

      <div className="orb-input-floating">
        <div className="orb-input-row">
          <input
            ref={inputRef}
            type="text"
            placeholder="Ask Orb about your building data..."
            className="orb-input"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={handleKeyPress}
            disabled={isLoading}
          />
        </div>
        <div className="orb-button-row">
          <div className="orb-left-buttons">
            <button
              title="Check LLM Health"
              className="orb-icon-button"
              onClick={checkLLMHealth}
            >
              🔍
            </button>
            <button
              title="Clear Chat"
              className="orb-icon-button"
              onClick={clearChat}
            >
              🗑️
            </button>
          </div>
          <div className="orb-right-button">
            <button
              title="Send prompt"
              className="orb-send-button"
              onClick={() => handleSendMessage()}
              disabled={isLoading || !inputValue.trim()}
            >
              {isLoading ? "⏳" : "➤"}
            </button>
          </div>
        </div>
      </div>
    </PageLayout>
  );
};

export default LLMChatPage;