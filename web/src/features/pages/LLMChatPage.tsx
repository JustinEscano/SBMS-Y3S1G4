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
               lowerQuery.includes("kwh") || lowerQuery.includes("consumption") ||
               lowerQuery.includes("watt")) {
      return "energy";
    } else if (lowerQuery.includes("room") || lowerQuery.includes("utilization") || 
               lowerQuery.includes("usage") || lowerQuery.includes("occupied") ||
               lowerQuery.includes("most used")) {
      return "utilization";
    } else if (lowerQuery.includes("summary") || lowerQuery.includes("report") || 
               lowerQuery.includes("week") || lowerQuery.includes("overview")) {
      return "summary";
    } else if (lowerQuery.includes("context") || lowerQuery.includes("situation") || 
               lowerQuery.includes("current state") || lowerQuery.includes("status")) {
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

  // Function to call the LLM query API
  const callLLMQuery = async (query: string, userRole: UserRole) => {
    try {
      const response = await fetch("http://localhost:5000/llmquery", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-User-Role": userRole
        },
        body: JSON.stringify({
          query: query,
          user_id: "web_user",
          username: "Web User",
          session_id: "web_session",
          client_ip: "127.0.0.1"
        })
      });
      
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error(`LLM query failed:`, error);
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
      const userRole = determineUserRole(queryType);
      const response = await callLLMQuery(messageText, userRole);
      
      let answer = "";
      
      // Check if there's an error in the response
      if (response.error) {
        answer = `Sorry, I encountered an error: ${response.error}`;
      } else if (response.answer) {
        // Format the answer based on query type for better presentation
        answer = response.answer;
        
        // Add some formatting for specific query types
        switch (queryType) {
          case "energy":
            if (response.answer.includes("Energy Analysis:")) {
              // Already formatted, use as is
              answer = response.answer;
            } else {
              answer = `🔋 Energy Analysis:\n\n${response.answer}`;
            }
            break;
          case "maintenance":
            answer = `🔧 Maintenance Analysis:\n\n${response.answer}`;
            break;
          case "anomalies":
            answer = `⚠️ Anomaly Detection:\n\n${response.answer}`;
            break;
          case "utilization":
            answer = `🏢 Room Utilization:\n\n${response.answer}`;
            break;
          case "summary":
            answer = `📊 Weekly Summary:\n\n${response.answer}`;
            break;
          case "context":
            answer = `🌡️ Current Status:\n\n${response.answer}`;
            break;
          default:
            answer = response.answer;
        }
      } else {
        answer = "I received an empty response. Please try again.";
      }

      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === loadingMessage.id
            ? { ...msg, content: answer, isLoading: false }
            : msg
        )
      );
    } catch (error: any) {
      console.error("Error in handleSendMessage:", error);
      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === loadingMessage.id
            ? { 
                ...msg, 
                content: `Sorry, I encountered an error: ${error.message || "Unknown error"}. Please check if the LLM server is running.`, 
                isLoading: false 
              }
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
      "Show me energy consumption trends",
      "Generate weekly summary",
      "Check for maintenance issues",
      "Detect any anomalies",
      "What's the current room status?",
      "Show me key performance indicators",
      "Analyze energy usage patterns"
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
              <p>Ask me questions about:</p>
              <ul>
                <li>📊 Energy consumption and trends</li>
                <li>🏢 Room utilization and occupancy</li>
                <li>🔧 Maintenance suggestions</li>
                <li>⚠️ Anomaly detection</li>
                <li>📈 Weekly summaries and KPIs</li>
                <li>🌡️ Current building status</li>
              </ul>
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
                    <pre style={{ 
                      whiteSpace: 'pre-wrap', 
                      fontFamily: 'inherit',
                      margin: 0,
                      padding: 0
                    }}>{message.content}</pre>
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