import { createContext, useContext, useState, useEffect } from "react";
import { registerLogout } from "../services/logoutUser";

interface User {
  id: string;
  username: string;
  role: string;
  // Add other fields from your User type if needed, e.g., email: string;
}

interface AuthContextType {
  token: string | null;
  currentUser: User | null;
  isAuthenticated: boolean;
  login: (token: string) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType>({
  token: null,
  currentUser: null,
  isAuthenticated: false,
  login: () => {},
  logout: () => {},
});

// Simple JWT decode function (client-side, no verification—assume backend is trusted)
const decodeJWT = (token: string): User | null => {
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    const id = payload.sub || payload.user_id;
    if (!id) return null;
    return {
      id,
      username: payload.username || payload.sub || "Unknown",
      role: payload.role || "user",
      // Add more: email: payload.email, etc.
    };
  } catch (error) {
    console.error("Failed to decode token:", error);
    return null;
  }
};

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [token, setToken] = useState<string | null>(
    localStorage.getItem("access_token")
  );
  const [currentUser, setCurrentUser] = useState<User | null>(null);

  // Decode token on mount or token change
  useEffect(() => {
    if (token) {
      const user = decodeJWT(token);
      setCurrentUser(user);
    } else {
      setCurrentUser(null);
    }
  }, [token]);

  const login = (newToken: string) => {
    setToken(newToken);
    localStorage.setItem("access_token", newToken);
  };

  const logout = () => {
    setToken(null);
    setCurrentUser(null);
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    window.location.href = "/login";
  };

  // ✅ Register logout so interceptors can use it
  useEffect(() => {
    registerLogout(logout);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        token,
        currentUser,
        isAuthenticated: !!token,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);