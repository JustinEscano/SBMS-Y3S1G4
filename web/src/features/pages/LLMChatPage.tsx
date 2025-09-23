import React, { useState, useEffect, useRef } from "react";
import PageLayout from "./PageLayout";
<<<<<<< HEAD
import LLMService from "../../service/LLMService"; // Import the value (class instance)
import type { ChatMessage } from "../../service/LLMService"; // Import the type (interface)
=======
import LLMService from "../services/llmService"; // Import the value (class instance)
import type { ChatMessage } from "../types/llmTypes"; // Import the type (interface)
>>>>>>> web-only
import "./LLMChatPage.css";

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
      const health = await LLMService.checkHealth();
      setLlmHealth(health.status);
    } catch (error) {
      console.error("Health check failed:", error);
      setLlmHealth("unhealthy");
    }
  };

  const handleSendMessage = async (query?: string) => {
    const messageText = query || inputValue.trim();
    if (!messageText || isLoading) return;

    // Clear input
    setInputValue("");

    // Add user message
    const userMessage: ChatMessage = {
      id: LLMService.generateMessageId(),
      type: "user",
      content: messageText,
      timestamp: new Date(),
    };

    // Add loading assistant message
    const loadingMessage: ChatMessage = {
      id: LLMService.generateMessageId(),
      type: "assistant",
      content: "Thinking...",
      timestamp: new Date(),
      isLoading: true,
    };

    setMessages(prev => [...prev, userMessage, loadingMessage]);
    setIsLoading(true);

    try {
      // Get user ID from localStorage if available
      const userId = localStorage.getItem("userId");
      
      const response = await LLMService.queryLLM({
        query: messageText,
        user_id: userId || undefined,
      });

      // Replace loading message with actual response
      setMessages(prev => 
        prev.map(msg => 
          msg.id === loadingMessage.id
            ? {
                ...msg,
                content: response.answer,
                sources: response.sources,
                isLoading: false,
              }
            : msg
        )
      );
    } catch (error: any) {
      // Replace loading message with error
      setMessages(prev => 
        prev.map(msg => 
          msg.id === loadingMessage.id
            ? {
                ...msg,
                content: `Sorry, I encountered an error: ${error.message}`,
                isLoading: false,
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

  const renderMessage = (message: ChatMessage) => (
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
          <>
            <p>{message.content}</p>
            {message.sources && message.sources.length > 0 && (
              <div className="orb-sources">
                <h4>Sources:</h4>
                <div className="orb-sources-list">
                  {message.sources.slice(0, 3).map((source, index) => (
                    <div key={index} className="orb-source-item">
                      <div className="orb-source-metadata">
                        <span className="orb-source-time">
                          {LLMService.formatTimestamp(source.metadata.timestamp)}
                        </span>
                        <span className="orb-source-temp">
                          {source.metadata.temperature}°C
                        </span>
                        <span className="orb-source-energy">
                          {source.metadata.energy_kwh} kWh
                        </span>
                      </div>
                      <p className="orb-source-content">
                        {source.page_content.substring(0, 150)}...
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
      <div className="orb-message-time">
        {message.timestamp.toLocaleTimeString()}
      </div>
    </div>
  );

  return (
    <PageLayout initialSection={{ parent: "LLM" }}>
      <div className="orb-chat-container">
        {/* Health Status */}
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
              <p>Ask me questions about temperature, humidity, energy usage, and more!</p>
            </div>

            <div className="orb-suggestions">
              <h3>Try asking:</h3>
              {LLMService.getSuggestedQueries().slice(0, 6).map((text, index) => (
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
            {messages.map(renderMessage)}
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

      {/* Floating input bar outside scrollable container */}
      <div className="orb-input-floating">
        {/* First row: full-width input */}
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

        {/* Second row: buttons */}
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