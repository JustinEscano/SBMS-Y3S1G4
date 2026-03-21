import { useState, useEffect, useCallback, useRef } from "react";
import { jwtDecode } from "jwt-decode";
import { userService } from "../services/userService";
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
    const cached = localStorage.getItem("userProfile");
    return cached ? JSON.parse(cached) : null;
  });
  const [loading, setLoading] = useState(!localStorage.getItem("userProfile"));
  const [error, setError] = useState<string | null>(null);

  // BUG FIX: Use a ref for the cache instead of state.
  // Previously `cache` was state — updating it caused a re-render, which
  // re-created `fetchUser` (not memoized), which re-triggered the useEffect.
  // A ref update does NOT cause a re-render, breaking the loop.
  const cacheRef = useRef<{ data: UserData; timestamp: number } | null>(null);

  const getUserIdFromToken = useCallback((t: string): string | null => {
    try {
      const decoded = jwtDecode<TokenPayload>(t);
      return decoded.user_id || null;
    } catch {
      return null;
    }
  }, []);

  // BUG FIX: Wrap fetchUser in useCallback so its reference is stable.
  // Previously it was a plain async function recreated every render — the
  // useEffect([token]) saw it as a new dep on each render and re-ran.
  const fetchUser = useCallback(async (userId: string) => {
    // Use cached data if fresh (TTL: 30s) — read from ref, not state
    if (cacheRef.current && Date.now() - cacheRef.current.timestamp < 30000) {
      setUser(cacheRef.current.data);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const [userInfo, profileInfo] = await Promise.all([
        userService.getById(userId),
        userService.getProfile(),
      ]);

      const combinedData: UserData = {
        ...userInfo,
        ...profileInfo,
      };

      setUser(combinedData);
      // Write to ref — no re-render triggered
      cacheRef.current = { data: combinedData, timestamp: Date.now() };
      localStorage.setItem("userProfile", JSON.stringify(combinedData));
    } catch (err: any) {
      console.error("Failed to fetch user:", err);
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
  }, [token]); // token is needed for the fallback decode only

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
  }, [token, fetchUser, getUserIdFromToken]);

  const refetch = useCallback(() => {
    if (token) {
      const userId = getUserIdFromToken(token);
      if (userId) {
        cacheRef.current = null; // Invalidate cache
        fetchUser(userId);
      }
    }
  }, [token, fetchUser, getUserIdFromToken]);

  const clearUser = useCallback(() => {
    localStorage.removeItem("userProfile");
    setUser(null);
    cacheRef.current = null;
  }, []);

  return { user, loading, error, refetch, clearUser };
};
