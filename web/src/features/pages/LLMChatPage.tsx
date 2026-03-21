import React, { useState, useEffect, useRef } from "react";
import PageLayout from "./PageLayout";
import "./LLMChatPage.css";

export interface ChatMessage {
  id: string;
  type: "user" | "assistant";
  content: string;
  timestamp: Date;
  isLoading?: boolean;
}

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
  const [currentUser, setCurrentUser] = useState<{id: string, username: string} | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Get user info helper
  const getUserInfo = () => {
    if (currentUser) {
      return { user_id: currentUser.id, username: currentUser.username };
    }
    // Fallback to localStorage
    const userId = localStorage.getItem('user_id');
    return {
      user_id: userId || 'anonymous',
      username: userId || 'User'
    };
  };

  // Scroll to bottom when new messages are added
  const scrollToBottom = () => {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
    }, 100);
  };

  // Call billing rates endpoint with LLM analysis
  const callBillingRates = async (userQuery?: string) => {
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
      const { user_id, username } = getUserInfo();
      const response = await fetch("http://localhost:5000/billing/rates", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          query: userQuery || '',  // ✅ Pass the full user message for personality extraction!
          user_id: user_id,
          username: username
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
  const callKPIHeartbeat = async (userQuery?: string) => {
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
      const { user_id, username } = getUserInfo();
      const response = await fetch("http://localhost:5000/kpi/heartbeat", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "facility_manager" },
        body: JSON.stringify({ 
          query: userQuery || '',
          user_id: user_id,
          username: username
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

  // Load user info on component mount
  useEffect(() => {
    const loadUserInfo = async () => {
      try {
        const userId = localStorage.getItem('user_id');
        if (userId) {
          // Try to fetch full user details
          const response = await fetch(`http://localhost:8000/api/users/${userId}/`, {
            headers: {
              'Authorization': `Bearer ${localStorage.getItem('access_token')}`
            }
          });
          if (response.ok) {
            const userData = await response.json();
            setCurrentUser({
              id: userId,
              username: userData.username || userData.email || userId
            });
          } else {
            // Fallback to just user ID
            setCurrentUser({ id: userId, username: userId });
          }
        }
      } catch (error) {
        console.error('Failed to load user info:', error);
      }
    };
    loadUserInfo();
  }, []);

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
            user_id: getUserInfo().user_id,
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
          user_id: getUserInfo().user_id,
          username: getUserInfo().username,
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
               lowerQuery.includes("strange") || lowerQuery.includes("weird") ||
               lowerQuery.includes("alert") || lowerQuery.includes("warning")) {
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
          user_id: getUserInfo().user_id,
          username: getUserInfo().username,
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
  const callAnomaliesDetect = async (userRole: UserRole, sensitivity: number = 0.8, userQuery?: string) => {
    try {
      const { user_id, username } = getUserInfo();
      const response = await fetch("http://localhost:5000/anomalies/detect", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-User-Role": userRole
        },
        body: JSON.stringify({
          query: userQuery || '', // ✅ Pass full query for personality
          sensitivity,
          user_id: user_id,
          username: username
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
      content: "📊 Generating weekly energy report with timestamps...",
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
      content: "📊 Generating daily energy report with timestamps...",
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
          period: "daily",
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
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
      content: "📊 Generating monthly energy report with timestamps...",
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
          period: "monthly",
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
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
          user_id: getUserInfo().user_id,
          username: getUserInfo().username,
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

  // Call room utilization endpoint with AI analysis
  const callRoomUtilization = async (userQuery: string = "") => {
    const loadingId = (Date.now() + Math.random()).toString();
    const loadingMessage: ChatMessage = {
      id: loadingId,
      type: "assistant",
      content: "🏢 Loading room directory with AI insights...",
      timestamp: new Date(),
      isLoading: true,
    };
    setMessages((prev) => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      const response = await fetch("http://localhost:5000/rooms/list", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: getUserInfo().user_id,
          username: getUserInfo().username,
          query: userQuery
        })
      });
      
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      // Use the formatted summary_text from the backend (includes LLM analysis)
      const formattedContent = data.summary_text || "No rooms found.";
      
      // Log statistics if available
      if (data.statistics) {
        console.log("Room Statistics:", data.statistics);
        console.log("Total Rooms:", data.total_rooms);
        console.log("LLM Analysis Generated:", !!data.llm_analysis);
      }
      
      setMessages((prev) => prev.map((m) => 
        m.id === loadingId ? ({ ...m, content: formattedContent, isLoading: false }) : m
      ));
      
      // Save to MongoDB
      await saveChatToMongoDB("Show me rooms", formattedContent, "utilization", "viewer");
      
    } catch (error) {
      console.error("Room list error:", error);
      const errorMessage = "❌ Failed to load rooms. Please ensure the LLM server is running on port 5000.";
      setMessages((prev) => prev.map((m) => 
        m.id === loadingId ? ({ ...m, content: errorMessage, isLoading: false }) : m
      ));
      
      // Save error to MongoDB
      await saveChatToMongoDB("Show me rooms", errorMessage, "utilization", "viewer", undefined, true);
    } finally {
      setIsLoading(false);
    }
  };

  // Call energy report endpoint with LLM analysis
    const callEnergyReportWithLLM = async (period: 'daily' | 'weekly' | 'monthly' | 'yearly', userQuery?: string) => {
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
      const { user_id, username } = getUserInfo();
      const response = await fetch("http://localhost:5000/energy/report", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "energy_analyst" },
        body: JSON.stringify({ 
          period: period,
          query: userQuery || '',  // ✅ Pass the full user message for personality extraction!
          user_id: user_id,
          username: username
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
          user_id: getUserInfo().user_id,
          username: getUserInfo().username
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
        await callBillingRates(messageText);  // ✅ Pass the full message!
        return;
      }
      
      if (queryType === "kpi") {
        setMessages((prev) => [...prev, userMessage]);
        await callKPIHeartbeat(messageText);
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
        await callEnergyReportWithLLM(period, messageText);  // ✅ Pass the full message!
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
        await callRoomUtilization(messageText);
        return;
      }
      
      if (queryType === "anomalies") {
        const loadingMessage: ChatMessage = {
          id: (Date.now() + 1).toString(),
          type: "assistant",
          content: "Detecting anomalies...",
          timestamp: new Date(),
          isLoading: true,
        };
        setMessages((prev) => [...prev, userMessage, loadingMessage]);
        setIsLoading(true);

        try {
          const response = await callAnomaliesDetect(userRole, 0.8, messageText); // ✅ Pass full message
          
          // Use the formatted answer from backend (includes everything)
          const formattedContent = response.answer || "No anomalies detected.";
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === loadingMessage.id
                ? { ...msg, content: formattedContent, isLoading: false }
                : msg
            )
          );
          
          // Save to MongoDB
          await saveChatToMongoDB(messageText, formattedContent, "anomalies", userRole); // ✅ Save actual message
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
      "check for maintenance",
      "show anomalies",
      "show billing rates",
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