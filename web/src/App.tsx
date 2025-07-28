import { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import LoginScreen from './pages/LoginScreen.tsx';
import DashboardScreen from './pages/DashboardScreen.tsx';
import { useAuth } from './context/AuthContext';
import './App.css';

function App() {
  const [isLoading, setIsLoading] = useState(true);
  const { isAuthenticated } = useAuth(); // role removed

  useEffect(() => {
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 1000); // Simulated loading delay
    return () => clearTimeout(timer);
  }, []);

  if (isLoading) {
    return (
      <div style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <Router>
      <Routes>
        {/* Root: auto redirect based on authentication */}
        <Route path="/" element={<Navigate to={isAuthenticated ? "/dashboard" : "/login"} replace />} />

        {/* Login: redirect if already logged in */}
        <Route
          path="/login"
          element={isAuthenticated ? <Navigate to="/dashboard" replace /> : <LoginScreen />}
        />

        {/* Dashboard: any authenticated user */}
        <Route
          path="/dashboard"
          element={
            isAuthenticated
              ? <DashboardScreen />
              : <Navigate to="/login" replace />
          }
        />
      </Routes>
    </Router>
  );
}

export default App;