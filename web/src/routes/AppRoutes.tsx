import { Routes, Route, Navigate } from "react-router-dom";
import LoginScreen from "../features/pages/LoginScreen";
import DashboardScreen from "../features/pages/DashboardScreen";
import RegSignUpForm from "../features/pages/SignUpForm";
import { useAuth } from "../features/context/authContext";
import type { JSX } from "react";
import GenericEquipmentPage from "../features/pages/EquipmentPage";
import UsagePage from "../features/pages/UsagePage";
import MaintenancePage from "../features/pages/MaintenancePage";
import NotificationPage from "../features/pages/NotificationPage";
import LLMChatPage from "../features/pages/LLMChatPage";
import AboutPage from "../features/pages/AboutPage";


// ✅ Reusable wrapper for route protection
const ProtectedRoute = ({ children }: { children: JSX.Element }) => {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" replace />;
};

const AppRoutes = () => {
  const { isAuthenticated } = useAuth();

  return (
    <Routes>
      {/* Default redirect */}
      <Route
        path="/"
        element={
          <Navigate to={isAuthenticated ? "/dashboard" : "/login"} replace />
        }
      />

      {/* Login */}
      <Route
        path="/login"
        element={
          isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen />
        }
      />

      {/* Registration */}
      <Route
        path="/registration"
        element={
          isAuthenticated ? <Navigate to="/dashboard" replace /> : <RegSignUpForm />
        }
      />

      {/* Protected routes */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <DashboardScreen />
          </ProtectedRoute>
        }
      />

      <Route path="/dashboard/hvac" element={<ProtectedRoute><GenericEquipmentPage mode="hvac" icon="❄️" /></ProtectedRoute>} />
      <Route path="/dashboard/lighting" element={<ProtectedRoute><GenericEquipmentPage mode="lighting" icon="💡" /></ProtectedRoute>} />
      <Route path="/dashboard/security" element={<ProtectedRoute><GenericEquipmentPage mode="security" icon="🔒" /></ProtectedRoute>} />
      <Route path="/dashboard/maintenance" element={<ProtectedRoute><MaintenancePage /></ProtectedRoute>} />

      <Route path="/usage" element={<ProtectedRoute><UsagePage /></ProtectedRoute>} />
      <Route path="/notifications" element={<ProtectedRoute><NotificationPage /></ProtectedRoute>} />
      <Route path="/llm" element={<ProtectedRoute><LLMChatPage /></ProtectedRoute>} />
      <Route path="/about" element={<ProtectedRoute><AboutPage /></ProtectedRoute>} />
    </Routes>
  );
};

export default AppRoutes;
