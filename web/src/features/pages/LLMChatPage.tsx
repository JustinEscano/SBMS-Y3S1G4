import React, { useState, useEffect, useRef } from "react";
import PageLayout from "./PageLayout";
import LLMService from "../../service/LLMService";
import type { ChatMessage } from "../../service/LLMService";
import "./LLMChatPage.css";

// Define API endpoint types
type QueryType = "general" | "maintenance" | "anomalies" | "energy" | "utilization" | "summary" | "context" | "billing";

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

  // Call energy report endpoint
  const callEnergyReport = async (period: 'daily' | 'monthly' | 'yearly', roomId?: string) => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: `Generating ${period} energy report...`,
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/energy/report", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ period, room_id: roomId })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();

      const totals = data.totals || { total_energy: 0, total_cost: 0 };
      const groups: any[] = Array.isArray(data.groups) ? data.groups : [];
      const lines: string[] = [];
      lines.push(`📊 ${period.charAt(0).toUpperCase() + period.slice(1)} Energy Report`);
      lines.push(`Totals: energy=${totals.total_energy?.toFixed?.(2) ?? totals.total_energy} kWh, cost=₱${totals.total_cost?.toFixed?.(2) ?? totals.total_cost}`);
      if (groups.length > 0) {
        lines.push("\nTop Buckets:");
        groups.slice(0, 5).forEach((g, i) => {
          lines.push(`- ${i + 1}. ${g.period} • ${g.room_name}: ${g.total_energy} kWh, ₱${g.total_cost}`);
        });
      } else {
        lines.push("\nNo summary data available in the selected window.");
      }

      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: lines.join("\n"), isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
    } finally {
      setIsLoading(false);
    }
  };

  // Call billing rates endpoint
  const callBillingRates = async (roomId?: string) => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Fetching billing rates...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/billing/rates", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ room_id: roomId })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      const rates: any[] = Array.isArray(data.rates) ? data.rates : [];
      const suggestions: string[] = Array.isArray(data.suggestions) ? data.suggestions : [];

      const lines: string[] = [];
      lines.push("💱 Billing Rates (effective PHP/kWh)\n");
      if (rates.length > 0) {
        const byRoom = new Map<string, any[]>();
        rates.forEach((r) => {
          const room = r.room_name || 'Global';
          if (!byRoom.has(room)) byRoom.set(room, []);
          byRoom.get(room)!.push(r);
        });
        const roomNames = Array.from(byRoom.keys()).sort();
        roomNames.forEach((room) => {
          lines.push(`- ${room}:`);
          const roomRates = byRoom.get(room)!
            .sort((a, b) => (b.effective_rate_php ?? 0) - (a.effective_rate_php ?? 0));
          roomRates.forEach((r) => {
            const php = Number(r.effective_rate_php).toFixed(2);
            const orig = `${r.rate_per_kwh} ${r.currency}`;
            const window = (r.start_time && r.end_time) ? `, window ${r.start_time}-${r.end_time}` : '';
            const valid = (r.valid_from || r.valid_to) ? `, valid ${r.valid_from || 'open'} → ${r.valid_to || 'open'}` : '';
            lines.push(`  • ₱${php}/kWh (${orig}/kWh${window}${valid})`);
          });
          lines.push("");
        });
        if (lines[lines.length - 1] === "") lines.pop();
      } else {
        lines.push("No rates found. Create a PHP/kWh rate to enable cost calculations.");
      }

      if (suggestions.length > 0) {
        const uniq = Array.from(new Set(suggestions));
        lines.push("\nSuggestions:");
        uniq.forEach((s) => lines.push(`- ${s}`));
      }

      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: lines.join("\n"), isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
    } finally {
      setIsLoading(false);
    }
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
    } else if (/\b(billing|bill|rate|rates|pricing)\b/.test(lowerQuery)) {
      return "billing";
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

  // Function to determine user role based on query type
  const determineUserRole = (queryType: QueryType): UserRole => {
    switch (queryType) {
      case "maintenance":
      case "anomalies":
        return "facility_manager";
      case "energy":
        return "energy_analyst";
      case "billing":
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

  // Render an energy insights result with trends
  const renderEnergyInsights = (data: any): string => {
    const ea = data.energy_analysis || {};
    const trend = ea.trend || {};
    const lines: string[] = [];
    lines.push("🔋 Energy Insights\n");
    if (trend.summary) {
      const s = trend.summary;
      const delta = (s.last7_vs_prev7_delta_pct !== null && s.last7_vs_prev7_delta_pct !== undefined)
        ? `${s.last7_vs_prev7_delta_pct.toFixed ? s.last7_vs_prev7_delta_pct.toFixed(1) : s.last7_vs_prev7_delta_pct}%`
        : "n/a";
      lines.push(`Last 7d: ${s.last7_total_kwh ?? 0} kWh, Prev 7d: ${s.prev7_total_kwh ?? 0} kWh (Δ ${delta})`);
    }
    const top = Array.isArray(trend.top_rooms_last7) ? trend.top_rooms_last7 : [];
    if (top.length > 0) {
      lines.push("\nTop rooms (last 7d):");
      top.slice(0, 5).forEach((r: any, i: number) => {
        lines.push(`- ${i + 1}. ${r.room_name}: ${r.energy_kwh} kWh`);
      });
    }
    const peaks = Array.isArray(trend.peak_days) ? trend.peak_days : [];
    if (peaks.length > 0) {
      lines.push("\nPeak days:");
      peaks.forEach((p: any) => lines.push(`- ${p.date}: ${p.energy_kwh} kWh`));
    }
    return lines.join("\n");
  };

  // Call the dedicated anomalies endpoint to leverage alerts + next_steps
  const callAnomaliesDetect = async (userRole: UserRole, sensitivity: number = 0.8) => {
    try {
      const response = await fetch("http://localhost:5000/anomalies/detect", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-User-Role": userRole
        },
        body: JSON.stringify({
          sensitivity,
          user_id: "web_user"
        })
      });

      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error("Anomalies detect failed:", error);
      throw error;
    }
  };

  // Call weekly summary endpoint
  const callWeeklySummary = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Generating weekly summary...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/reports/weekly", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "viewer" },
        body: JSON.stringify({ type: "executive", user_id: "web_user" })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      const summary = data.executive_summary || data.answer || "Weekly summary generated.";
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `📊 Weekly Summary\n\n${summary}`, isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
    } finally {
      setIsLoading(false);
    }
  };

  const handleSendMessage = async (query?: string) => {
    const messageText = query || inputValue.trim();
    if (!messageText || isLoading) return;

    try {
      setInputValue("");
      const userMessage: ChatMessage = {
        id: Date.now().toString(),
        type: "user",
        content: messageText,
        timestamp: new Date(),
      };

      const queryType = determineQueryType(messageText);
      const userRole = determineUserRole(queryType);

      // For billing and weekly summary, use dedicated flows (they manage their own loader/output)
      if (queryType === "billing") {
        setMessages((prev) => [...prev, userMessage]);
        await callBillingRates();
        return;
      }
      if (queryType === "summary") {
        setMessages((prev) => [...prev, userMessage]);
        await callWeeklySummary();
        return;
      }

      const loadingMessage: ChatMessage = {
        id: (Date.now() + 1).toString(),
        type: "assistant",
        content: "Thinking...",
        timestamp: new Date(),
        isLoading: true,
      };
      setMessages((prev) => [...prev, userMessage, loadingMessage]);
      setIsLoading(true);

      const response = queryType === "anomalies"
        ? await callAnomaliesDetect(userRole)
        : await callLLMQuery(messageText, userRole);
      
      let answer = "";
      
      // Check if there's an error in the response
      if (response.error) {
        answer = `Sorry, I encountered an error: ${response.error}`;
      } else if (queryType === "anomalies" && response.status === "success") {
        // Format anomalies/alerts/next_steps from /anomalies/detect
        const summary = response.summary || {};
        const anomalies: any[] = Array.isArray(response.anomalies) ? response.anomalies : [];
        const alerts: any[] = Array.isArray(response.alerts) ? response.alerts : [];
        const nextSteps: string[] = Array.isArray(response.next_steps) ? response.next_steps : [];

        const lines: string[] = [];
        lines.push("⚠️ Anomaly Detection:\n");
        lines.push(
          `Summary: total=${summary.total_anomalies ?? anomalies.length}, critical=${summary.critical ?? 0}, high=${summary.high ?? 0}, medium=${summary.medium ?? 0}`
        );

        if (anomalies.length > 0) {
          lines.push("\nTop Anomalies:");
          anomalies.slice(0, 5).forEach((a: any, idx: number) => {
            const type = a.type || "Unknown";
            const sev = a.severity || "Medium";
            const desc = a.description || "Anomaly detected";
            const loc = a.location ? ` @ ${a.location}` : "";
            lines.push(`- ${idx + 1}. [${sev}] ${type}${loc} — ${desc}`);
          });
        } else {
          lines.push("\nNo model-detected anomalies in this window.");
        }

        if (alerts.length > 0) {
          lines.push("\nRecent Alerts (from core_alert):");
          alerts.slice(0, 5).forEach((al: any, idx: number) => {
            const sev = al.severity || "";
            const t = al.type || "alert";
            const msg = al.message || "";
            const room = al.room_name ? `, room=${al.room_name}` : "";
            const eq = al.equipment_name ? `, eq=${al.equipment_name}` : "";
            const resolved = al.is_resolved ? "resolved" : "unresolved";
            lines.push(`- ${idx + 1}. [${sev}] ${t}: ${msg}${room}${eq} (${resolved})`);
          });
        }

        if (nextSteps.length > 0) {
          lines.push("\nNext Steps:");
          nextSteps.forEach((s: string) => lines.push(`- ${s}`));
        }

        answer = lines.join("\n");
      } else if (response.answer) {
        // Format the answer based on query type for better presentation
        answer = response.answer;
        // Attach enhanced rendering when energy analysis payload is present
        if (queryType === "energy" && response.energy_analysis) {
          const rendered = renderEnergyInsights(response);
          if (rendered && rendered.trim().length > 0) {
            answer = `${rendered}\n\n${answer}`;
          }
        }
        
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
          case "billing":
            // Billing endpoint prints its own message; keep fallback label
            answer = `💱 Billing Rates:\n\n${response.answer || "See above for listed rates."}`;
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
      "Show billing rates",
      "What's the current room status?",
      "Show me key performance indicators",
      "Analyze energy usage patterns"
    ];
  };

  // Format greeting items with consistent emojis
  const greetingItems = [
    { emoji: "📊", text: "Energy consumption and trends" },
    { emoji: "🏢", text: "Room utilization and occupancy" },
    { emoji: "🔧", text: "Maintenance suggestions" },
    { emoji: "⚠️", text: "Anomaly detection" },
    { emoji: "📈", text: "Weekly summaries and KPIs" },
    { emoji: "🌡️", text: "Current building status" }
  ];

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
              <h2>Hello, I am Orb! 👋</h2>
              <p>I can help you analyze your building's sensor data and energy consumption.</p>
              <p>Ask me questions about:</p>
              <ul>
                {greetingItems.map((item, index) => (
                  <li key={index}>
                    <span className="orb-emoji">{item.emoji}</span>
                    {item.text}
                  </li>
                ))}
              </ul>
            </div>
            <div className="orb-suggestions">
              <h3>💡 Try asking:</h3>
              <div className="orb-suggestion-buttons">
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
            </div>
          </>
        ) : (
          <div className="orb-messages">
            {messages.map((message: ChatMessage) => (
              <div key={message.id} className={`orb-message orb-message-${message.type}`}>
                <div className="orb-message-content">
                  {/* Logo only for assistant responses (not loading) */}
                  {message.type === "assistant" && !message.isLoading && (
                    <img
                      src="/logo.png"
                      alt="Orb Assistant Logo"
                      className="orb-message-logo"
                    />
                  )}
                  {message.isLoading ? (
                    <div className="orb-loading">
                      <div className="orb-loading-dots">
                        <span></span>
                        <span></span>
                        <span></span>
                      </div>
                      <span className="orb-loading-text">Thinking...</span>
                    </div>
                  ) : (
                    <pre className="orb-response-text">{message.content}</pre>
                  )}
                </div>
                <div className="orb-message-time">
                  {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
              </div>
            ))}
            <div ref={messagesEndRef} />
          </div>
        )}

        {messages.length > 0 && (
          <div className="orb-chat-actions">
            <button onClick={clearChat} className="orb-clear-button">
              🗑️ Clear Chat
            </button>
          </div>
        )}
      </div>

      <div className="orb-input-floating">
        <div className="orb-input-row">
          <input
            ref={inputRef}
            type="text"
            placeholder="💭 Ask Orb about your building data..."
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
              disabled={isLoading}
            >
              🔍
            </button>
            <button
              title="Clear Chat"
              className="orb-icon-button"
              onClick={clearChat}
              disabled={isLoading}
            >
              🗑️
            </button>
            <button
              title="Detect anomalies"
              className="orb-icon-button"
              onClick={() => handleSendMessage("Detect any anomalies")}
              disabled={isLoading}
            >
              ⚠️
            </button>
            <button
              title="Daily energy report"
              className="orb-icon-button"
              onClick={() => callEnergyReport('daily')}
              disabled={isLoading}
            >
              📅
            </button>
            <button
              title="Monthly energy report"
              className="orb-icon-button"
              onClick={() => callEnergyReport('monthly')}
              disabled={isLoading}
            >
              🗓️
            </button>
            <button
              title="Yearly energy report"
              className="orb-icon-button"
              onClick={() => callEnergyReport('yearly')}
              disabled={isLoading}
            >
              📆
            </button>
            <button
              title="Billing rates"
              className="orb-icon-button"
              onClick={() => callBillingRates()}
              disabled={isLoading}
            >
              💱
            </button>
          </div>
          <div className="orb-right-button">
            <button
              title="Send prompt"
              className="orb-send-button"
              onClick={() => handleSendMessage()}
              disabled={isLoading || !inputValue.trim()}
            >
              {isLoading ? (
                <>
                  <span className="orb-send-loading">⏳</span>
                  Sending...
                </>
              ) : (
                <>
                  <span className="orb-send-icon">➤</span>
                  Send
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </PageLayout>
  );
};

export default LLMChatPage;