import { useEffect, useState } from 'react';
import { BrowserRouter as Router } from 'react-router-dom';
import AppRoutes from './routes/AppRoutes'; // Import your new routes
import './App.css';

function App() {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 1000);
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
      <AppRoutes />
    </Router>
  );
}

export default App;