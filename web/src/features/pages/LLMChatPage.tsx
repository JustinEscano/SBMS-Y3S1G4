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
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
    }, 100);
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

      const lines: string[] = [];
      lines.push("💱 Billing Rates Analysis\n");

      if (rates.length > 0) {
        const byRoom = new Map<string, any[]>();
        rates.forEach((r) => {
          const room = r.room_name || 'Global';
          if (!byRoom.has(room)) byRoom.set(room, []);
          byRoom.get(room)!.push(r);
        });

        const roomNames = Array.from(byRoom.keys()).sort();
        roomNames.forEach((room, roomIdx) => {
          if (roomIdx > 0) lines.push(""); // Add spacing between rooms
          lines.push(`📍 ${room}:`);

          const roomRates = byRoom.get(room)!
            .sort((a, b) => (b.effective_rate_php ?? 0) - (a.effective_rate_php ?? 0));

          roomRates.forEach((r, idx) => {
            const php = Number(r.effective_rate_php).toFixed(2);
            const startTime = r.start_time || '00:00:00';
            const endTime = r.end_time || '23:59:59';
            const validFrom = r.valid_from ? new Date(r.valid_from).toLocaleDateString() : 'Now';
            const validTo = r.valid_to ? new Date(r.valid_to).toLocaleDateString() : 'Ongoing';

            // Calculate rate tier and emoji
            const rate = Number(php);
            let tier, emoji;
            if (rate >= 12) {
              tier = "Premium";
              emoji = "💎";
            } else if (rate >= 10) {
              tier = "High";
              emoji = "🔴";
            } else if (rate >= 8) {
              tier = "Medium";
              emoji = "🟡";
            } else {
              tier = "Economy";
              emoji = "🟢";
            }

            // Main rate line
            lines.push(`\n${idx + 1}. ${emoji} ₱${php}/kWh`);
            lines.push(`   ⏰ Active: ${startTime} - ${endTime}`);
            lines.push(`   📅 Valid: ${validFrom} → ${validTo}`);
            lines.push(`   🏷️  ${tier} Rate`);
          });
        });

        // Enhanced summary statistics
        const allPhpRates = rates.map(r => Number(r.effective_rate_php)).filter(r => !isNaN(r));
        if (allPhpRates.length > 0) {
          const avgRate = (allPhpRates.reduce((a, b) => a + b, 0) / allPhpRates.length).toFixed(2);
          const minRate = Math.min(...allPhpRates).toFixed(2);
          const maxRate = Math.max(...allPhpRates).toFixed(2);

          // Calculate savings potential
          const savings = (Number(maxRate) - Number(minRate)).toFixed(2);

          lines.push("\n\n📊 **Rate Analysis:**");
          lines.push(`• Total Configurations: ${rates.length}`);
          lines.push(`• Peak Rate: ₱${maxRate}/kWh`);
          lines.push(`• Base Rate: ₱${minRate}/kWh`);
          lines.push(`• Average Rate: ₱${avgRate}/kWh`);
          lines.push(`• Potential Savings: ₱${savings}/kWh (by choosing optimal times)`);

          // Find best and worst times
          const cheapest = rates.find(r => Number(r.effective_rate_php) === Number(minRate));
          const mostExpensive = rates.find(r => Number(r.effective_rate_php) === Number(maxRate));

          if (cheapest) {
            lines.push(`• Best Time: ${cheapest.start_time || 'All Day'} - ${cheapest.end_time || 'All Day'} (₱${minRate}/kWh)`);
          }
          if (mostExpensive) {
            lines.push(`• Peak Time: ${mostExpensive.start_time || 'All Day'} - ${mostExpensive.end_time || 'All Day'} (₱${maxRate}/kWh)`);
          }
        }

        // Enhanced recommendations
        const hasTimeWindows = rates.some(r => r.start_time && r.end_time);
        const rateRange = allPhpRates.length > 1 ? (Math.max(...allPhpRates) - Math.min(...allPhpRates)) : 0;

        lines.push("\n💡 **Optimization Tips:**");
        if (hasTimeWindows && rateRange > 2) {
          lines.push("• ⏰ **Time-of-Use Strategy**: Schedule energy-intensive tasks during lowest rate periods");
          lines.push(`• 💰 **Potential Savings**: Up to ₱${rateRange.toFixed(2)}/kWh by choosing optimal timing`);
        }
        if (rates.some(r => r.room_name && r.room_name !== 'Global')) {
          lines.push("• 🏢 **Room-Specific Rates**: Consider custom rates for high-usage areas");
        }
        lines.push("• 📈 **Monitor Trends**: Track rate changes and seasonal variations");
        lines.push("• 🔄 **Review Quarterly**: Reassess billing strategy every 3 months for best rates");

      } else {
        lines.push("No billing rates configured.");
        lines.push("\n💡 Tip: Configure billing rates to enable cost calculations and optimization.");
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

  // Determine report period from query
  const determineReportPeriod = (query: string): 'daily' | 'monthly' | 'yearly' | 'weekly' => {
    const lowerQuery = query.toLowerCase();
    if (lowerQuery.includes('daily') || lowerQuery.includes('day')) return 'daily';
    if (lowerQuery.includes('monthly') || lowerQuery.includes('month')) return 'monthly';
    if (lowerQuery.includes('yearly') || lowerQuery.includes('year') || lowerQuery.includes('annual')) return 'yearly';
    return 'weekly';
  };

  // Call room utilization endpoint
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

    try {
      const response = await fetch("http://localhost:5000/rooms/utilization", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-User-Role": "facility_manager" },
        body: JSON.stringify({ user_id: "web_user" })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      const lines: string[] = [];
      const metrics = data.detailed_metrics || {};
      const recommendations: string[] = Array.isArray(data.recommendations) ? data.recommendations : [];
      
      lines.push("🏢 Room Utilization Analysis\n");
      
      if (data.status === "success" && metrics.status === "success") {
        // Quick answer for simple queries
        lines.push(`📊 Total Rooms in System: ${metrics.unique_rooms || 0}`);
        lines.push(`📈 Total Events Recorded: ${(metrics.total_events || 0).toLocaleString()}\n`);
        
        // Most used room section
        lines.push("📍 Most Utilized Room:");
        lines.push(`   ${metrics.most_used_room || "Unknown"}`);
        lines.push(`   • Events: ${(metrics.most_used_count || 0).toLocaleString()}`);
        if (metrics.usage_percentage) {
          lines.push(`   • Usage: ${metrics.usage_percentage.toFixed(1)}% of total activity`);
        }
        
        // Overall statistics
        lines.push("\n📊 Overall Statistics:");
        lines.push(`   • Total Rooms: ${metrics.unique_rooms || 0}`);
        lines.push(`   • Total Events: ${(metrics.total_events || 0).toLocaleString()}`);
        if (metrics.avg_events_per_room) {
          lines.push(`   • Average Events/Room: ${metrics.avg_events_per_room.toFixed(1)}`);
        }
        
        // Utilization distribution
        if (metrics.utilization_distribution) {
          const dist = metrics.utilization_distribution;
          lines.push("\n📈 Utilization Distribution:");
          lines.push(`   • 🔴 High Usage: ${dist.high_usage || 0} rooms`);
          lines.push(`   • 🟡 Medium Usage: ${dist.medium_usage || 0} rooms`);
          lines.push(`   • 🟢 Low Usage: ${dist.low_usage || 0} rooms`);
        }
        
        // Room breakdown if available
        if (metrics.room_details && Array.isArray(metrics.room_details)) {
          lines.push("\n🏠 Room Breakdown:");
          metrics.room_details.slice(0, 10).forEach((room: any, idx: number) => {
            const usage = room.usage_level || "medium";
            const emoji = usage === "high" ? "🔴" : usage === "low" ? "🟢" : "🟡";
            lines.push(`   ${idx + 1}. ${emoji} ${room.room_name || "Unknown"}`);
            lines.push(`      Events: ${(room.event_count || 0).toLocaleString()}`);
            if (room.percentage) {
              lines.push(`      Share: ${room.percentage.toFixed(1)}%`);
            }
          });
        }
        
        // Recommendations
        if (recommendations.length > 0) {
          lines.push("\n💡 Recommendations:");
          recommendations.forEach(rec => lines.push(`   • ${rec}`));
        }
      } else {
        lines.push("No room utilization data available.");
        lines.push("\n💡 Tip: Ensure room sensors are properly configured and reporting data.");
      }
      
      const formattedContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: formattedContent, isLoading: false }) : m));
    } catch (err: any) {
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: `Error: ${err.message || 'Unknown error'}`, isLoading: false }) : m));
    } finally {
      setIsLoading(false);
    }
  };

  // Call maintenance prediction endpoint
  const callMaintenancePredict = async () => {
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
          query: "Analyze equipment and suggest maintenance",
          user_id: "web_user",
          username: "Web User"
        })
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      const data = await response.json();
      
      // Format the maintenance response
      const lines: string[] = [];
      const summary = data.summary || {};
      const suggestions: any[] = Array.isArray(data.maintenance_suggestions) ? data.maintenance_suggestions : [];
      const requestedBy = data.requested_by || {};
      
      lines.push("🔧 Maintenance Analysis");
      if (requestedBy.username) {
        lines.push(`Requested by: ${requestedBy.username}\n`);
      }
      
      lines.push("📊 Summary:");
      lines.push(`• Total Items: ${summary.total_maintenance_items || 0}`);
      lines.push(`• 🤖 AI Predictions: ${summary.ai_predictions || 0}`);
      lines.push(`• 👤 User Requests: ${summary.user_requests || 0}`);
      if (summary.critical_count > 0) {
        lines.push(`• 🔴 Critical: ${summary.critical_count}`);
      }
      if (summary.high_count > 0) {
        lines.push(`• 🟠 High Priority: ${summary.high_count}`);
      }
      if (summary.medium_count > 0) {
        lines.push(`• 🟡 Medium Priority: ${summary.medium_count}`);
      }
      if (summary.low_count > 0) {
        lines.push(`• ⚪ Low Priority: ${summary.low_count}`);
      }
      lines.push(`\n📈 Request Status:`);
      lines.push(`• Pending: ${summary.pending_requests || 0}`);
      lines.push(`• In Progress: ${summary.in_progress_requests || 0}`);
      lines.push(`• Resolved: ${summary.resolved_requests || 0}`);
      lines.push(`• Data Points Analyzed: ${summary.data_points || 0}`);
      
      if (suggestions.length > 0) {
        lines.push("\n🔧 Top Maintenance Items:");
        suggestions.slice(0, 10).forEach((s: any, idx: number) => {
          const urgency = s.urgency || "Medium";
          const source = s.source || "UNKNOWN";
          const sourceIcon = source === "AI_PREDICTION" ? "🤖" : "👤";
          const urgencyEmoji = urgency === "Critical" ? "🔴" : urgency === "High" ? "🟠" : urgency === "Medium" ? "🟡" : "⚪";
          
          lines.push(`\n${idx + 1}. ${sourceIcon} ${urgencyEmoji} ${s.equipment || "Equipment"} (${s.room || "Unknown Room"})`);
          lines.push(`   Issue: ${s.issue || "Maintenance needed"}`);
          lines.push(`   Requested by: ${s.requested_by || "System"}`);
          lines.push(`   Action: ${s.action || "Inspect and maintain"}`);
          lines.push(`   Timeline: ${s.timeline || "Schedule soon"}`);
          
          if (source === "USER_REQUEST") {
            lines.push(`   Status: ${(s.status || "pending").toUpperCase()}`);
            if (s.assigned_to && s.assigned_to !== "Unassigned") {
              lines.push(`   Assigned to: ${s.assigned_to}`);
            }
          } else if (s.confidence) {
            lines.push(`   Confidence: ${(s.confidence * 100).toFixed(0)}%`);
          }
        });
      } else {
        lines.push("\n✅ No maintenance issues detected.");
        lines.push("All equipment is operating within normal parameters.");
      }
      
      const formattedContent = lines.join("\n");
      setMessages((prev) => prev.map((m) => m.id === loadingId ? ({ ...m, content: formattedContent, isLoading: false }) : m));
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

      // For billing, weekly summary, and maintenance, use dedicated flows
      if (queryType === "billing") {
        setMessages((prev) => [...prev, userMessage]);
        await callBillingRates();
        return;
      }
      if (queryType === "summary") {
        setMessages((prev) => [...prev, userMessage]);
        const period = determineReportPeriod(messageText);
        if (period === 'daily' || period === 'monthly' || period === 'yearly') {
          await callEnergyReport(period);
        } else {
          await callWeeklySummary();
        }
        return;
      }
      if (queryType === "maintenance") {
        setMessages((prev) => [...prev, userMessage]);
        await callMaintenancePredict();
        return;
      }
      if (queryType === "utilization") {
        setMessages((prev) => [...prev, userMessage]);
        await callRoomUtilization();
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

        {/* Clear chat button moved to input area */}
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