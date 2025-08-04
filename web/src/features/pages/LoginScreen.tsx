import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { loginUser } from '../services/authService'; // use your axios instance here
import { Link } from 'react-router-dom';
import '../pages/LoginScreen.css';

function LoginScreen() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const data = await loginUser(username, password); // calls authService
      login(data.access); // store the access token
      navigate('/dashboard');
    } catch (err) {
      console.error(err);
      alert('Login failed. Please check your credentials.');
    }
  };

  return (
    <div className="login-container">
      <div className="logo">
        <img src="/orbit-logo.png" alt="Orbit Logo" className="logo-img" />
        <span className="logo-text">Orbit</span>
      </div>

      <form className="login-card" onSubmit={handleSubmit}>
        <h2 className="login-title">Login To Continue</h2>

        <label>Email</label>
        <input
          type="text"
          placeholder="example@gmail.com"
          className="input-field"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
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

        <button type="submit" className="login-button">Login</button>

        <div className="separator">
          <hr />
          <span>OR</span>
          <hr />
        </div>

        <div className="social-buttons">
          <button type="button" className="social-btn google">
            <img src="https://www.svgrepo.com/show/475656/google-color.svg" alt="Google" />
            Login Via Google
          </button>
          <button type="button" className="social-btn facebook">
            <img src="https://www.svgrepo.com/show/157817/facebook.svg" alt="Facebook" />
            Login Via Facebook
          </button>
        </div>

        <p className="signup-text">
          Don’t have an account? <Link to="/registration">Sign Up</Link>
        </p>
      </form>
    </div>
  );
}

export default LoginScreen;