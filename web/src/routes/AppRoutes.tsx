import { Routes, Route, Navigate } from 'react-router-dom';
import LoginScreen from '../features/pages/LoginScreen';
import DashboardScreen from '../features/pages/DashboardScreen';
import RegSignUpForm from '../features/pages/SignUpForm';
import { useAuth } from '../features/context/AuthContext';

const AppRoutes = () => {
  const { isAuthenticated } = useAuth();

  return (
    <Routes>
      <Route path="/" element={<Navigate to={isAuthenticated ? "/dashboard" : "/login"} replace />} />

      <Route
        path="/login"
        element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen />}
      />

      <Route
        path="/dashboard"
        element={isAuthenticated ? <DashboardScreen /> : <Navigate to="/login" replace />}
      />

      <Route
        path="/registration"
        element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <RegSignUpForm />}
      />
    </Routes>
  );
};

export default AppRoutes;