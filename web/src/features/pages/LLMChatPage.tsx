import React, { useState, useEffect, useRef } from "react";
import PageLayout from "./PageLayout";
import type { ChatMessage } from "../../service/LLMService";
import "./LLMChatPage.css";

// Define API endpoint types
type QueryType = "general" | "maintenance" | "anomalies" | "energy" | "utilization" | "summary" | "context" | "billing" | "kpi";

// Define possible user roles
type UserRole = "viewer" | "technician" | "energy_analyst" | "facility_manager" | "admin";

const LLMChatPage: React.FC = () => {
  // Generate or retrieve session ID for chat persistence
  const [sessionId] = useState(() => {
    let id = sessionStorage.getItem("chat_session_id");
    if (!id) {
      id = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      sessionStorage.setItem("chat_session_id", id);
    }
    return id;
  });
  
  const [messages, setMessages] = useState<ChatMessage[]>(() => {
    // Load messages from localStorage on mount
    try {
      const saved = localStorage.getItem('llm_chat_messages');
      if (saved) {
        const parsed = JSON.parse(saved);
        // Convert timestamp strings back to Date objects
        return parsed.map((msg: any) => ({
          ...msg,
          timestamp: new Date(msg.timestamp)
        }));
      }
    } catch (error) {
      console.error("Failed to load messages from localStorage:", error);
    }
    return [];
  });
  const [inputValue, setInputValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [llmHealth, setLlmHealth] = useState<string>("checking");
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Scroll to bottom when new messages are added
  const scrollToBottom = () => {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
    }, 100);
  };

  // Call billing rates endpoint with LLM analysis
  const callBillingRates = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Analyzing billing rates with AI...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/billing/rates", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      const lines: string[] = [];
      lines.push("💱 Billing Rates Analysis\n");
      
      // Add billing data summary
      if (data.billing_data) {
        const bd = data.billing_data;
        lines.push("📊 Rate Summary:");
        lines.push(`• Total Configurations: ${bd.total_rates}`);
        lines.push(`• Average Rate: ${bd.average_rate?.toFixed(4)} ${bd.currency}/kWh`);
        lines.push(`• Lowest Rate: ${bd.min_rate?.toFixed(4)} ${bd.currency}/kWh`);
        lines.push(`• Highest Rate: ${bd.max_rate?.toFixed(4)} ${bd.currency}/kWh\n`);
        
        // Show rate details
        if (bd.rates && bd.rates.length > 0) {
          lines.push("⏰ Rate Schedule:");
          bd.rates.forEach((rate: any, idx: number) => {
            lines.push(`${idx + 1}. ${rate.rate?.toFixed(4)} ${rate.currency}/kWh`);
            if (rate.start_time && rate.end_time) {
              lines.push(`   Time: ${rate.start_time} - ${rate.end_time}`);
            }
            if (rate.valid_from && rate.valid_to) {
              const from = new Date(rate.valid_from).toLocaleDateString();
              const to = new Date(rate.valid_to).toLocaleDateString();
              lines.push(`   Valid: ${from} → ${to}`);
            }
          });
          lines.push("");
        }
      }
      
      // Add LLM analysis
      if (data.answer) {
        lines.push("🤖 **AI ANALYSIS**\n");
        lines.push(data.answer);
      }

      const finalContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: finalContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB("Show billing rates", finalContent, "billing", "energy_analyst");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      
      // Save error to MongoDB
      await saveChatToMongoDB("Show billing rates", errorMsg, "billing", "energy_analyst", undefined, true);
    } finally {
      setIsLoading(false);
    }
  };

  // Call KPI heartbeat endpoint with LLM analysis
  const callKPIHeartbeat = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Analyzing system health KPIs with AI...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/kpi/heartbeat", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "facility_manager" },
        body: JSON.stringify({ 
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      const lines: string[] = [];
      lines.push("📊 System Health KPI Analysis\n");
      
      // Add KPI data summary
      if (data.kpi_data) {
        const kpi = data.kpi_data;
        lines.push("🔍 Performance Metrics:");
        lines.push(`• Success Rate: ${kpi.success_rate?.toFixed(2)}%`);
        lines.push(`• WiFi Signal: ${kpi.wifi_signal?.toFixed(1)} dBm`);
        lines.push(`• Average Uptime: ${kpi.uptime_hours?.toFixed(1)} hours`);
        lines.push(`• Voltage Stability: ${kpi.voltage_stability?.toFixed(2)}`);
        lines.push(`• Failed Readings: ${kpi.total_failed_readings}`);
        lines.push(`• PZEM Errors: ${kpi.total_pzem_errors}\n`);
        
        // Show sensor health
        if (kpi.sensor_health) {
          lines.push("🔧 Sensor Health:");
          lines.push(`• DHT22 (Temp/Humidity): ${kpi.sensor_health.dht22?.toFixed(1)}% operational`);
          lines.push(`• PZEM (Power Meter): ${kpi.sensor_health.pzem?.toFixed(1)}% operational`);
          lines.push(`• Photoresistor (Light): ${kpi.sensor_health.photoresistor?.toFixed(1)}% operational`);
          lines.push(`• Data Points Analyzed: ${kpi.data_points}\n`);
        }
      }
      
      // Add LLM analysis
      if (data.answer) {
        lines.push("🤖 **AI ANALYSIS**\n");
        lines.push(data.answer);
      }

      const finalContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: finalContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB("Show system health KPI", finalContent, "kpi", "facility_manager");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      
      // Save error to MongoDB
      await saveChatToMongoDB("Show system health KPI", errorMsg, "kpi", "facility_manager", undefined, true);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);
  
  // Save messages to localStorage whenever they change
  useEffect(() => {
    try {
      localStorage.setItem('llm_chat_messages', JSON.stringify(messages));
    } catch (error) {
      console.error("Failed to save messages to localStorage:", error);
    }
  }, [messages]);

  // Check LLM health on component mount
  useEffect(() => {
    checkLLMHealth();
  }, []);
  
  // Load chat history from MongoDB on component mount
  useEffect(() => {
    const loadChatHistory = async () => {
      try {
        const response = await fetch("http://localhost:5000/chat/history/get", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            user_id: "web_user",
            session_id: sessionId,
            limit: 50
          })
        });
        
        if (response.ok) {
          const data = await response.json();
          if (data.chats && data.chats.length > 0) {
            // Convert MongoDB chats to ChatMessage format
            const loadedMessages: ChatMessage[] = data.chats.reverse().map((chat: any) => ([
              {
                id: `${chat._id}_user`,
                type: "user" as const,
                content: chat.user_message,
                timestamp: new Date(chat.timestamp)
              },
              {
                id: `${chat._id}_assistant`,
                type: "assistant" as const,
                content: chat.assistant_response,
                timestamp: new Date(chat.timestamp)
              }
            ])).flat();
            
            setMessages(loadedMessages);
            console.log(`✅ Loaded ${loadedMessages.length} messages from history`);
          }
        }
      } catch (error) {
        console.error("Failed to load chat history:", error);
      }
    };
    
    loadChatHistory();
  }, [sessionId]);

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

  // Save chat to MongoDB
  const saveChatToMongoDB = async (userMessage: string, assistantResponse: string, queryType: QueryType, userRole: string, responseTimeMs?: number, hasError: boolean = false) => {
    try {
      await fetch("http://localhost:5000/chat/history/save", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: "web_user",
          username: "Web User",
          session_id: `web_session_${Date.now()}`,
          user_message: userMessage,
          assistant_response: assistantResponse,
          query_type: queryType,
          user_role: userRole,
          response_time_ms: responseTimeMs,
          has_error: hasError
        })
      });
      console.log("✅ Chat saved to MongoDB");
    } catch (error) {
      console.error("Failed to save chat to MongoDB:", error);
      // Don't throw - we don't want to break the UI if MongoDB save fails
    }
  };

  // Function to determine query type based on content
  const determineQueryType = (query: string): QueryType => {
    const lowerQuery = query.toLowerCase();
    
    // Check for maintenance first (more specific)
    if (lowerQuery.includes("maintenance") || lowerQuery.includes("repair") || 
        lowerQuery.includes("fix") || lowerQuery.includes("broken") ||
        lowerQuery.includes("check for maintenance")) {
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
    } else if (lowerQuery.includes("report") || lowerQuery.includes("summary") ||
               lowerQuery.includes("weekly") || lowerQuery.includes("daily") ||
               lowerQuery.includes("monthly") || lowerQuery.includes("yearly") ||
               lowerQuery.includes("week") || lowerQuery.includes("overview")) {
      return "summary";
    } else if (lowerQuery.includes("context") || lowerQuery.includes("situation") || 
               lowerQuery.includes("current state")) {
      return "context";
    } else if (lowerQuery.includes("kpi") || lowerQuery.includes("heartbeat") || 
               lowerQuery.includes("sensor health") || lowerQuery.includes("system health") ||
               lowerQuery.includes("device health") || lowerQuery.includes("iot health")) {
      return "kpi";
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
      case "kpi":
        return "facility_manager";
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
<<<<<<< HEAD
      content: "Generating weekly summary with timestamps...",
=======
      content: "📊 Generating weekly energy report with timestamps...",
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/energy/report", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          period: "weekly",
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
<<<<<<< HEAD
      const summary = data.executive_summary || data.answer || "Weekly summary generated.";
      const period = data.period || {};
      const periodInfo = period.description ? `\n📅 Period: ${period.description}\n` : "";
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `📊 Weekly Summary${periodInfo}\n${summary}`, isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
=======
      
      // Format the response with energy data
      const lines: string[] = [];
      lines.push("📅 **WEEKLY ENERGY REPORT**\n");
      
      if (data.energy_data) {
        const ed = data.energy_data;
        lines.push("📊 Energy Summary:");
        lines.push(`• Total: ${ed.total_kwh?.toFixed(2)} kWh`);
        lines.push(`• Average: ${ed.average_kwh?.toFixed(2)} kWh`);
        lines.push(`• Peak: ${ed.peak_kwh?.toFixed(2)} kWh`);
        if (ed.period_start && ed.period_end) {
          lines.push(`• Period: ${new Date(ed.period_start).toLocaleDateString()} - ${new Date(ed.period_end).toLocaleDateString()}\n`);
        }
      }
      
      // Add LLM analysis
      if (data.answer) {
        lines.push("🤖 **AI ANALYSIS**\n");
        lines.push(data.answer);
      }
      
      const finalContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: finalContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB("Weekly energy report", finalContent, "energy", "energy_analyst");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      await saveChatToMongoDB("Weekly energy report", errorMsg, "energy", "energy_analyst", undefined, true);
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
    } finally {
      setIsLoading(false);
    }
  };

  // Call daily summary endpoint
  const callDailySummary = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
<<<<<<< HEAD
      content: "Generating daily summary with timestamps...",
=======
      content: "📊 Generating daily energy report with timestamps...",
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
<<<<<<< HEAD
      const response = await fetch("http://localhost:5000/ask", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "viewer" },
        body: JSON.stringify({ 
          query: "daily energy report",
          user_id: "web_user",
          username: "Web User",
          session_id: `web_${Date.now()}`
=======
      const response = await fetch("http://localhost:5000/energy/report", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          period: "daily",
          user_id: "web_user",
          username: "Web User"
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
<<<<<<< HEAD
      const answer = data.answer || "Daily energy report generated.";
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: answer, isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
=======
      
      // Format the response with energy data
      const lines: string[] = [];
      lines.push("📅 **DAILY ENERGY REPORT**\n");
      
      if (data.energy_data) {
        const ed = data.energy_data;
        lines.push("📊 Energy Summary:");
        lines.push(`• Total: ${ed.total_kwh?.toFixed(2)} kWh`);
        lines.push(`• Average: ${ed.average_kwh?.toFixed(2)} kWh`);
        lines.push(`• Peak: ${ed.peak_kwh?.toFixed(2)} kWh`);
        if (ed.period_start && ed.period_end) {
          lines.push(`• Period: ${new Date(ed.period_start).toLocaleDateString()} - ${new Date(ed.period_end).toLocaleDateString()}\n`);
        }
      }
      
      // Add LLM analysis
      if (data.answer) {
        lines.push("🤖 **AI ANALYSIS**\n");
        lines.push(data.answer);
      }
      
      const finalContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: finalContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB("Daily energy report", finalContent, "energy", "energy_analyst");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      await saveChatToMongoDB("Daily energy report", errorMsg, "energy", "energy_analyst", undefined, true);
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
    } finally {
      setIsLoading(false);
    }
  };

  // Call monthly summary endpoint
  const callMonthlySummary = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
<<<<<<< HEAD
      content: "Generating monthly summary with timestamps...",
=======
      content: "📊 Generating monthly energy report with timestamps...",
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
<<<<<<< HEAD
      const response = await fetch("http://localhost:5000/ask", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "viewer" },
        body: JSON.stringify({ 
          query: "monthly energy report",
          user_id: "web_user",
          username: "Web User",
          session_id: `web_${Date.now()}`
=======
      const response = await fetch("http://localhost:5000/energy/report", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          period: "monthly",
          user_id: "web_user",
          username: "Web User"
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
<<<<<<< HEAD
      const answer = data.answer || "Monthly energy report generated.";
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: answer, isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
=======
      
      // Format the response with energy data
      const lines: string[] = [];
      lines.push("📅 **MONTHLY ENERGY REPORT**\n");
      
      if (data.energy_data) {
        const ed = data.energy_data;
        lines.push("📊 Energy Summary:");
        lines.push(`• Total: ${ed.total_kwh?.toFixed(2)} kWh`);
        lines.push(`• Average: ${ed.average_kwh?.toFixed(2)} kWh`);
        lines.push(`• Peak: ${ed.peak_kwh?.toFixed(2)} kWh`);
        if (ed.period_start && ed.period_end) {
          lines.push(`• Period: ${new Date(ed.period_start).toLocaleDateString()} - ${new Date(ed.period_end).toLocaleDateString()}\n`);
        }
      }
      
      // Add LLM analysis
      if (data.answer) {
        lines.push("🤖 **AI ANALYSIS**\n");
        lines.push(data.answer);
      }
      
      const finalContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: finalContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB("Monthly energy report", finalContent, "energy", "energy_analyst");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      await saveChatToMongoDB("Monthly energy report", errorMsg, "energy", "energy_analyst", undefined, true);
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
    } finally {
      setIsLoading(false);
    }
  };

  // Call yearly summary endpoint
  const callYearlySummary = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Generating yearly summary with timestamps...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/ask", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "viewer" },
        body: JSON.stringify({ 
          query: "yearly energy report",
          user_id: "web_user",
          username: "Web User",
          session_id: `web_${Date.now()}`
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      const answer = data.answer || "Yearly energy report generated.";
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: answer, isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
    } finally {
      setIsLoading(false);
    }
  };

  // Determine report period from query
  const determineReportPeriod = (query: string): 'daily' | 'monthly' | 'yearly' | 'weekly' => {
    const lowerQuery = query.toLowerCase();
    if (lowerQuery.includes('daily') || lowerQuery.includes('day')) return 'daily';
    if (lowerQuery.includes('monthly') || lowerQuery.includes('month')) return 'monthly';
    if (lowerQuery.includes('yearly') || lowerQuery.includes('year') || lowerQuery.includes('annual')) return 'yearly';
    return 'weekly';
  };

  // Fake room utilization response
  const callRoomUtilization = async () => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Analyzing room utilization...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 1500));

    const lines: string[] = [];
    lines.push("🏢 Room Utilization Analysis\n");
    lines.push("⚠️ Room-specific features are currently unavailable.\n");
    lines.push("📊 System Overview:");
    lines.push("• Total Energy Consumption: 1,250 kWh");
    lines.push("• Average Daily Usage: 89 kWh");
    lines.push("• Peak Usage Time: 14:00-16:00");
    lines.push("• Current System Status: ✅ Normal");
    lines.push("\n💡 Available Features:");
    lines.push("• Energy consumption reports");
    lines.push("• Billing rate analysis");
    lines.push("• Maintenance predictions");
    lines.push("• Anomaly detection");
    lines.push("• Weekly summaries");

    const formattedContent = lines.join("\n");
    setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: formattedContent, isLoading: false }) : m));
    setIsLoading(false);
  };

  // Call energy report endpoint with LLM analysis
    const callEnergyReportWithLLM = async (period: 'daily' | 'weekly' | 'monthly' | 'yearly') => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: `Generating ${period} energy report with AI analysis...`,
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/energy/report", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          period: period,
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      // Format the energy report response
      const lines: string[] = [];
      lines.push(`⚡ ${period.charAt(0).toUpperCase() + period.slice(1)} Energy Report\n`);
      
      if (data.energy_data) {
        const ed = data.energy_data;
        
        // Format timestamps based on period type
        const formatDate = (dateStr: string | null) => 
          dateStr ? new Date(dateStr).toLocaleDateString() : 'N/A';
        const formatTime = (dateStr: string | null) =>
          dateStr ? new Date(dateStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'N/A';

        // Show report period dates
        if (ed.period_start && ed.period_end) {
          lines.push(`📅 Period: ${formatDate(ed.period_start)} - ${formatDate(ed.period_end)}\n`);
        }

        lines.push("📊 Energy Statistics:");
        lines.push(`• Total Consumption: ${ed.total_kwh?.toFixed(2) || 0} kWh`);
        lines.push(`• Average: ${ed.average_kwh?.toFixed(2) || 0} kWh per period`);
        
        // For daily reports, show time. For others, show date
        const isDaily = period === 'daily';
        if (isDaily && ed.peak_time) {
          lines.push(`• Peak: ${ed.peak_kwh?.toFixed(2) || 0} kWh (at ${formatTime(ed.peak_time)})`);
          lines.push(`• Lowest: ${ed.lowest_kwh?.toFixed(2) || 0} kWh (at ${formatTime(ed.lowest_time)})`);
        } else if (ed.peak_time) {
          lines.push(`• Peak: ${ed.peak_kwh?.toFixed(2) || 0} kWh (on ${formatDate(ed.peak_time)})`);
          lines.push(`• Lowest: ${ed.lowest_kwh?.toFixed(2) || 0} kWh (on ${formatDate(ed.lowest_time)})`);
        } else {
          lines.push(`• Peak: ${ed.peak_kwh?.toFixed(2) || 0} kWh`);
          lines.push(`• Lowest: ${ed.lowest_kwh?.toFixed(2) || 0} kWh`);
        }
        
        lines.push(`• Data Points: ${ed.data_points || 0}\n`);
      }
      
      // Add LLM analysis
      if (data.answer) {
        lines.push("\n🤖 **AI ANALYSIS**\n");
        lines.push(data.answer);
      }
      
      const formattedContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: formattedContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB(`${period} energy report`, formattedContent, "energy", "energy_analyst");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      
      // Save error to MongoDB
      await saveChatToMongoDB(`${period} energy report`, errorMsg, "energy", "energy_analyst", undefined, true);
    } finally {
      setIsLoading(false);
    }
  };

  // Call maintenance prediction endpoint
  const callMaintenancePredict = async (userQuery?: string) => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "Analyzing equipment and generating maintenance suggestions...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/maintenance/predict", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "facility_manager" },
        body: JSON.stringify({ 
          query: userQuery || "Analyze equipment and suggest maintenance",
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      // Format the maintenance response - IMPROVED
      const lines: string[] = [];
      const suggestions: any[] = Array.isArray(data.maintenance_suggestions) ? data.maintenance_suggestions : [];
      
      lines.push("🔧 **MAINTENANCE REQUESTS**\n");
      
      if (suggestions.length > 0) {
        // Group by status
        const pending = suggestions.filter(s => s.status?.toLowerCase() === 'pending');
        const inProgress = suggestions.filter(s => s.status?.toLowerCase() === 'in_progress');
        const resolved = suggestions.filter(s => s.status?.toLowerCase() === 'resolved');
        
        // Show pending first
        if (pending.length > 0) {
          lines.push("🔴 **PENDING REQUESTS** (" + pending.length + "):\n");
          pending.slice(0, 5).forEach((s: any, idx: number) => {
            const urgencyEmoji = s.urgency === "Critical" ? "🔴" : s.urgency === "High" ? "🟠" : s.urgency === "Medium" ? "🟡" : "⚪";
            
            lines.push(`${idx + 1}. ${urgencyEmoji} **${s.equipment || "Equipment"}** - ${s.room || "Unknown Location"}`);
            lines.push(`   📝 Issue: ${s.issue || "Maintenance needed"}`);
            lines.push(`   🔧 Action: ${s.action || "Inspect and maintain"}`);
            lines.push(`   👤 Requested by: **${s.requested_by || "System"}**`);
            lines.push(`   👨‍🔧 Assigned to: **${s.assigned_to || "Unassigned"}**`);
            lines.push(`   📅 Scheduled: ${s.timeline || "TBD"}`);
            lines.push("");
          });
        }
        
        // Show in progress
        if (inProgress.length > 0) {
          lines.push("\n🟡 **IN PROGRESS** (" + inProgress.length + "):\n");
          inProgress.forEach((s: any, idx: number) => {
            lines.push(`${idx + 1}. **${s.equipment}** - ${s.room}`);
            lines.push(`   📝 ${s.issue}`);
            lines.push(`   👨‍🔧 Assigned to: **${s.assigned_to}**`);
            lines.push("");
          });
        }
        
        // Show resolved (last 3 only)
        if (resolved.length > 0) {
          lines.push("\n✅ **RECENTLY RESOLVED** (" + resolved.length + " total, showing last 3):\n");
          resolved.slice(0, 3).forEach((s: any, idx: number) => {
            lines.push(`${idx + 1}. ${s.equipment} - ${s.room}`);
            lines.push(`   ✓ ${s.action}`);
            lines.push("");
          });
        }
      } else {
        lines.push("\n✅ No maintenance issues detected.");
        lines.push("All equipment is operating within normal parameters.");
      }
      
      // Add LLM analysis if available
      if (data.llm_analysis) {
        lines.push("\n\n🤖 **AI RECOMMENDATIONS**\n");
        lines.push(data.llm_analysis);
      }
      
      const formattedContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: formattedContent, isLoading: false }) : m));
      
      // Save to MongoDB
      await saveChatToMongoDB("Check for maintenance", formattedContent, "maintenance", "facility_manager");
    } catch (err: any) {
      const errorMsg = `Error: ${err.message || 'Unknown error'}`;
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: errorMsg, isLoading: false }) : m));
      
      // Save error to MongoDB
      await saveChatToMongoDB("Check for maintenance", errorMsg, "maintenance", "facility_manager", undefined, true);
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

      // For billing, energy reports, maintenance, and KPI, use dedicated flows
      if (queryType === "billing") {
        setMessages((prev) => [...prev, userMessage]);
        await callBillingRates();
        return;
      }
      
      if (queryType === "kpi") {
        setMessages((prev) => [...prev, userMessage]);
        await callKPIHeartbeat();
        return;
      }
      
      // Check if this is an energy report query (daily/weekly/monthly/yearly)
      if (queryType === "energy" && (messageText.toLowerCase().includes("report") || 
          messageText.toLowerCase().includes("daily") ||
          messageText.toLowerCase().includes("weekly") ||
          messageText.toLowerCase().includes("monthly") ||
          messageText.toLowerCase().includes("yearly"))) {
        setMessages((prev) => [...prev, userMessage]);
        const period = determineReportPeriod(messageText);
        await callEnergyReportWithLLM(period);
        return;
      }
      
      if (queryType === "summary") {
        setMessages((prev) => [...prev, userMessage]);
        const period = determineReportPeriod(messageText);
        if (period === 'daily') {
          await callDailySummary();
        } else if (period === 'monthly') {
          await callMonthlySummary();
        } else if (period === 'yearly') {
          await callYearlySummary();
        } else {
          await callWeeklySummary();
        }
        return;
      }
      
      if (queryType === "maintenance") {
        setMessages((prev) => [...prev, userMessage]);
        await callMaintenancePredict(messageText);
        return;
      }
      
      if (queryType === "utilization") {
        setMessages((prev) => [...prev, userMessage]);
        await callRoomUtilization();
        return;
      }

      // For anomalies, use dedicated formatting
      if (queryType === "anomalies") {
        setMessages((prev) => [...prev, userMessage]);
        const loadingMessage: ChatMessage = {
          id: (Date.now() + 1).toString(),
          type: "assistant",
          content: "Detecting anomalies...",
          timestamp: new Date(),
          isLoading: true,
        };
        setMessages((prev) => [...prev, loadingMessage]);
        setIsLoading(true);

        try {
          const response = await callAnomaliesDetect(userRole);
          
          // Use the new simple format with LLM answer
          const llmAnswer = response.answer || "No analysis available";
          const alertSummary = response.alert_summary || {};
          const sampleAlerts: any[] = Array.isArray(response.sample_alerts) ? response.sample_alerts : [];

          const lines: string[] = [];
          lines.push("⚠️ **ANOMALY DETECTION**\n");
          
          // Show summary
          lines.push("📊 Alert Summary:");
          lines.push(`• Total Alerts: ${alertSummary.total_alerts || 0}`);
          lines.push(`• Unresolved: ${alertSummary.unresolved || 0}`);
          if (alertSummary.by_severity) {
            const sevCounts = alertSummary.by_severity;
            lines.push(`• Severity: High: ${sevCounts.high || 0}, Medium: ${sevCounts.medium || 0}, Low: ${sevCounts.low || 0}`);
          }
          if (alertSummary.by_type) {
            lines.push(`• Alert Types: ${Object.keys(alertSummary.by_type).length} different types\n`);
          }

          // Show sample alerts with better formatting
          if (sampleAlerts.length > 0) {
            lines.push("\n📋 Recent Alerts:\n");
            sampleAlerts.forEach((alert: any, idx: number) => {
              const type = alert.type || "unknown";
              const msg = alert.message || "Alert raised";
              const sev = alert.severity || "medium";
              const resolved = alert.is_resolved ? "✅ Resolved" : "🔴 Active";
              const equipment = alert.equipment || "Unknown";
              
              // Format timestamp nicely
              let timeStr = "Unknown time";
              if (alert.timestamp) {
                try {
                  const date = new Date(alert.timestamp);
                  timeStr = date.toLocaleString('en-US', { 
                    month: 'short', 
                    day: 'numeric', 
                    year: 'numeric',
                    hour: '2-digit', 
                    minute: '2-digit'
                  });
                } catch {
                  timeStr = String(alert.timestamp);
                }
              }
              
              lines.push(`**${idx + 1}. [${sev.toUpperCase()}] ${type}**`);
              lines.push(`   📝 ${msg}`);
              lines.push(`   🔧 Equipment: ${equipment}`);
              lines.push(`   📅 ${timeStr}`);
              lines.push(`   ${resolved}\n`);
            });
          }

          // Add LLM analysis
          lines.push("\n\n🤖 **AI ANALYSIS**\n");
          lines.push(llmAnswer);

          const formattedContent = lines.join("\n");
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === loadingMessage.id
                ? { ...msg, content: formattedContent, isLoading: false }
                : msg
            )
          );
          
          // Save to MongoDB
          await saveChatToMongoDB("Show me anomalies", formattedContent, "anomalies", userRole);
        } catch (error: any) {
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === loadingMessage.id
                ? { 
                    ...msg, 
                    content: `Error detecting anomalies: ${error.message || "Unknown error"}`, 
                    isLoading: false 
                  }
                : msg
            )
          );
        } finally {
          setIsLoading(false);
        }
        return;
      }

      // For all other queries, use general LLM
      const loadingMessage: ChatMessage = {
        id: (Date.now() + 1).toString(),
        type: "assistant",
        content: "Thinking...",
        timestamp: new Date(),
        isLoading: true,
      };
      setMessages((prev) => [...prev, userMessage, loadingMessage]);
      setIsLoading(true);

      const response = await callLLMQuery(messageText, userRole);
      
      let answer = "";
      
      if (response.error) {
        answer = `Sorry, I encountered an error: ${response.error}`;
      } else if (response.answer) {
        answer = response.answer;
        
        if (queryType === "energy" && response.energy_analysis) {
          const rendered = renderEnergyInsights(response);
          if (rendered && rendered.trim().length > 0) {
            answer = `${rendered}\n\n${answer}`;
          }
        }
        
        switch (queryType) {
          case "energy":
            if (!response.answer.includes("Energy Analysis:")) {
              answer = `🔋 Energy Analysis:\n\n${response.answer}`;
            }
            break;
          case "maintenance":
            answer = `🔧 Maintenance Analysis:\n\n${response.answer}`;
            break;
          case "billing":
            answer = `💱 Billing Rates:\n\n${response.answer || "See above for listed rates."}`;
            break;
          case "utilization":
            answer = `🏢 System Utilization:\n\n${response.answer}`;
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
      
      // Save to MongoDB
      await saveChatToMongoDB(messageText, answer, queryType, userRole);
    } catch (error: any) {
      console.error("Error in handleSendMessage:", error);
      setMessages((prev) =>
        prev.map((msg) =>
          msg.type === "assistant" && msg.isLoading
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
      "daily energy report",
      "weekly energy report",
      "monthly energy report",
      "yearly energy report",
      "check for maintenance",
      "show billing rates",
      "show me alerts",
      "show anomalies",
      "kpi performance",
    ];
  };

  const greetingItems = [
    { emoji: "📊", text: "Energy consumption and trends" },
    { emoji: "🔧", text: "Maintenance suggestions" },
    { emoji: "⚠️", text: "Anomaly detection" },
    { emoji: "📈", text: "Weekly summaries and KPIs" },
    { emoji: "💱", text: "Billing rate analysis" }
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
              <p>I can help you analyze your building's energy consumption and system data.</p>
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
              title="Maintenance predictions"
              className="orb-icon-button"
              onClick={() => callMaintenancePredict()}
              disabled={isLoading}
            >
              🔧
            </button>
            <button
              title="Weekly summary"
              className="orb-icon-button"
              onClick={() => callWeeklySummary()}
              disabled={isLoading}
            >
              📊
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
            {messages.length > 0 && (
              <button
                title="Clear Chat"
                className="orb-clear-button"
                onClick={clearChat}
                disabled={isLoading}
              >
                🗑️ Clear
              </button>
            )}
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