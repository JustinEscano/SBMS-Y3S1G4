import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { loginUser } from '../services/authService';
import { Link } from 'react-router-dom';
import '../pages/LoginScreen.css';

type Star = { x: number; y: number };

function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [stars, setStars] = useState<Star[]>([]);
  const navigate = useNavigate();
  const { login } = useAuth();

  // Generate stars randomly on mount
  useEffect(() => {
    const starCount = Math.floor(Math.random() * 20) + 10; // between 10 and 30
    const newStars: Star[] = [];
    for (let i = 0; i < starCount; i++) {
      newStars.push({
        x: Math.random() * window.innerWidth,
        y: Math.random() * window.innerHeight,
      });
    }
    setStars(newStars);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await loginUser(email, password);
      login(response.access); // store JWT in context
      navigate('/dashboard');
    } catch (err) {
      setError('Invalid email or password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      {/* Overlay spinner */}
      {loading && (
        <div className="loading-overlay">
          <div className="spinner"></div>
        </div>
      )}

      {/* Random stars */}
      {stars.map((star, idx) => (
        <div
          key={idx}
          className="star"
          style={{ top: `${star.y}px`, left: `${star.x}px` }}
        />
      ))}

      <div className="logo">
        <div className="logo-img" />
        <span className="logo-text">Orbit</span>
      </div>

      <form className="login-card" onSubmit={handleSubmit}>
        <h2 className="login-title">Login</h2>

        <label>Email</label>
        <input
          type="text"
          placeholder="example@gmail.com"
          className="input-field"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />

        <div className="password-row">
          <label>Password</label>
        </div>
        <input
          type="password"
          placeholder="Enter your Password"
          className="input-field"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        <a href="#" className="forgot-password">Forget Your Password?</a>

        {error && <div className="error-message">* {error}</div>}

        <button type="submit" className="login-button" disabled={loading}>
          Login
        </button>

        <p className="signup-text">
          Don’t have an account? <Link to="/registration">Sign Up</Link>
        </p>
      </form>
    </div>
  );
}

export default LoginScreen;