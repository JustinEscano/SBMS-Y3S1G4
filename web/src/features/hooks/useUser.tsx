import { useState, useEffect } from "react";
import { jwtDecode } from "jwt-decode";
import { userService } from "../services/userService"; // Adjust path
import type { User, Profile } from "../types/dashboardTypes";

type TokenPayload = {
  user_id: string;
  username?: string;
  email?: string;
  role?: string;
  role_display?: string;
  exp: number;
  token_type: string;
};

type UserData = User & Partial<Profile>;

export const useUser = (token?: string | null) => {
  const [user, setUser] = useState<UserData | null>(() => {
    // Load from localStorage on mount
    const cached = localStorage.getItem("userProfile");
    return cached ? JSON.parse(cached) : null;
  });
  const [loading, setLoading] = useState(!user);
  const [error, setError] = useState<string | null>(null);
  const [cache, setCache] = useState<{ data: UserData; timestamp: number } | null>(null);

  const getUserIdFromToken = (t: string): string | null => {
    try {
      const decoded = jwtDecode<TokenPayload>(t);
      return decoded.user_id || null;
    } catch {
      return null;
    }
  };

  const fetchUser = async (userId: string) => {
    // Use cached data if fresh (TTL: 30s)
    if (cache && Date.now() - cache.timestamp < 30000) {
      setUser(cache.data);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Get base user + profile info
      const [userInfo, profileInfo] = await Promise.all([
        userService.getById(userId),
        userService.getProfile(),
      ]);

      const combinedData: UserData = {
        ...userInfo,
        ...profileInfo,
      };

      setUser(combinedData);
      setCache({ data: combinedData, timestamp: Date.now() });
      localStorage.setItem("userProfile", JSON.stringify(combinedData));
    } catch (err: any) {
      console.error("❌ Failed to fetch user:", err);
      setError(err.message || "Failed to load user data.");

      // Fallback: decode from token
      if (token) {
        try {
          const decoded = jwtDecode<TokenPayload>(token);
          const fallbackUser: UserData = {
            id: decoded.user_id || "",
            username: decoded.username || "Unknown",
            email: decoded.email || "",
            role: decoded.role || "user",
            role_display: decoded.role_display || "User",
            created_at: new Date().toISOString(),
            last_login: null,
          };
          setUser(fallbackUser);
          localStorage.setItem("userProfile", JSON.stringify(fallbackUser));
        } catch {
          setUser(null);
        }
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (token) {
      const userId = getUserIdFromToken(token);
      if (userId) {
        fetchUser(userId);
      } else {
        setError("Invalid token.");
        setLoading(false);
      }
    } else {
      setUser(null);
      setLoading(false);
    }
  }, [token]);

  const refetch = () => {
    if (token) {
      const userId = getUserIdFromToken(token);
      if (userId) {
        setCache(null); // Invalidate cache
        fetchUser(userId);
      }
    }
  };

  const clearUser = () => {
    localStorage.removeItem("userProfile");
    setUser(null);
    setCache(null);
  };

  return { user, loading, error, refetch, clearUser };
};
