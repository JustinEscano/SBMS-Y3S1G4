import { useState, useEffect } from "react";
import { jwtDecode } from "jwt-decode";
import { userService } from "../services/userService"; // Adjust path
import type { User } from "../types/dashboardTypes";

type TokenPayload = {
  user_id: string;
  username?: string;
  email?: string;
  role?: string;
  role_display?: string;
  exp: number;
  token_type: string;
};

export const useUser = (token?: string | null) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cache, setCache] = useState<{ data: User; timestamp: number } | null>(null);

  // Extract userId from token
  const getUserIdFromToken = (t: string): string | null => {
    try {
      const decoded = jwtDecode<TokenPayload>(t);
      return decoded.user_id || null;
    } catch {
      return null;
    }
  };

  const fetchUser = async (userId: string) => {
    // Check cache (simple TTL: 30s)
    if (cache && Date.now() - cache.timestamp < 30000) {
      setUser(cache.data);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const fetchedUser = await userService.getById(userId);
      setUser(fetchedUser);
      setCache({ data: fetchedUser, timestamp: Date.now() });
    } catch (err: any) {
      console.error("Failed to fetch user:", err);
      setError(err.message || "Failed to load user data.");

      // Fallback to token decode
      if (token) {
        try {
          const decoded = jwtDecode<TokenPayload>(token);
          setUser({
            id: decoded.user_id || "",
            username: decoded.username || "Unknown",
            email: decoded.email || "",
            role: decoded.role || "user",
            role_display: decoded.role_display || "User",
            created_at: new Date().toISOString(), // Dummy
            last_login: null,
          } as User);
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

  return { user, loading, error, refetch };
};