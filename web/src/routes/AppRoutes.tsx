import { Routes, Route, Navigate, useNavigate } from "react-router-dom";
import LoginScreen from "../features/pages/LoginScreen";
import DashboardScreen from "../features/pages/DashboardScreen";
import RegSignUpForm from "../features/pages/SignUpForm";
import { useAuth } from "../features/context/AuthContext";
import type { JSX } from "react";
import GenericEquipmentPage from "../features/pages/EquipmentPage";
import UsagePage from "../features/pages/UsagePage";
import MaintenancePage from "../features/pages/MaintenancePage";
import NotificationPage from "../features/pages/NotificationPage";
import LLMChatPage from "../features/pages/LLMChatPage";
import AboutPage from "../features/pages/AboutPage";
import PolicyPage from "../features/pages/PolicyPage";
import SettingsPage from "../features/pages/SettingsPage";
import HelpSupportPage from "../features/pages/SupportPage";
import { PAGE_TYPES } from "../features/constants/constant";
import ProfilePage from "../features/pages/ProfilePage";
import PasswordResetScreen from "../features/pages/PasswordResetPage";
import UsersPage from "../features/pages/UserPage";

// ✅ Reusable wrapper for route protection
const ProtectedRoute = ({ children }: { children: JSX.Element }) => {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" replace />;
};

const AppRoutes = () => {
  const { isAuthenticated } = useAuth();

  const navigate = useNavigate();
  const { logout } = useAuth();

  function handleLogout(): void {
    logout();
    navigate("/login");
  }

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

      <Route path={`/dashboard/${PAGE_TYPES.HVAC}`} element={<ProtectedRoute><GenericEquipmentPage pageType={PAGE_TYPES.HVAC} icon="❄️" /></ProtectedRoute>} />
      <Route path={`/dashboard/${PAGE_TYPES.LIGHTING}`} element={<ProtectedRoute><GenericEquipmentPage pageType={PAGE_TYPES.LIGHTING} icon="💡" /></ProtectedRoute>} />
      <Route path={`/dashboard/${PAGE_TYPES.SECURITY}`} element={<ProtectedRoute><GenericEquipmentPage pageType={PAGE_TYPES.SECURITY} icon="🔒" /></ProtectedRoute>} />
      <Route path="/dashboard/maintenance" element={<ProtectedRoute><MaintenancePage /></ProtectedRoute>} />

      <Route path="/usage" element={<ProtectedRoute><UsagePage /></ProtectedRoute>} />
      <Route path="/notifications" element={<ProtectedRoute><NotificationPage /></ProtectedRoute>} />
      <Route path="/llm" element={<ProtectedRoute><LLMChatPage /></ProtectedRoute>} />
      <Route path="/about" element={<ProtectedRoute><AboutPage /></ProtectedRoute>} />
      <Route path="/profile" element={<ProtectedRoute><ProfilePage handleLogout={handleLogout} /></ProtectedRoute>} />
      <Route path="/settings" element={<ProtectedRoute><SettingsPage /></ProtectedRoute>} />
      <Route path="/policy" element={<ProtectedRoute><PolicyPage /></ProtectedRoute>} />
      <Route path="/help-support" element={<ProtectedRoute><HelpSupportPage /></ProtectedRoute>} />
      <Route path="/users" element={<ProtectedRoute><UsersPage /></ProtectedRoute>} />
      <Route path="/forgot" element={<PasswordResetScreen />} />
    </Routes>
  );
};

export default AppRoutes;
