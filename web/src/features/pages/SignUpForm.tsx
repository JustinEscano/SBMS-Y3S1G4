import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import '../pages/SignUpForm.css';
import axios from 'axios';

const SignUp: React.FC = () => {
  const navigate = useNavigate();

  const [form, setForm] = useState({
    email: '',
    username: '',
    password: '',
    confirmPassword: '',
    role: 'admin'
  });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (form.password !== form.confirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    try {
      await axios.post('http://localhost:8000/api/register/', {
        email: form.email,
        username: form.username,
        password: form.password,
        role: form.role,
      });

      alert("Registration successful. Please log in.");
      navigate('/login');
    } catch (err: any) {
      console.error(err.response || err);
      setError('Signup failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="signup-container">
      {/* Overlay spinner */}
      {loading && (
        <div className="loading-overlay">
          <div className="spinner"></div>
        </div>
      )}

      <div className="star" style={{ top: '200px', left: '300px' }}></div>
      <div className="star" style={{ top: '800px', left: '400px' }}></div>
      <div className="star" style={{ top: '500px', left: '600px' }}></div>
      <div className="star" style={{ top: '590px', left: '1200px' }}></div>
      <div className="star" style={{ top: '600px', left: '1400px' }}></div>
      <div className="star" style={{ top: '300px', left: '1500px' }}></div>
      <div className="star" style={{ top: '800px', left: '1800px' }}></div>

      <div className="logo">
        <div className="logo-img"/>
        <span className="logo-text">Orbit</span>
      </div>

      <form onSubmit={handleSubmit} className="signup-form">
        <h2 className="signup-title">Sign Up</h2>
        <input
          type="email"
          name="email"
          placeholder="Email Address"
          value={form.email}
          onChange={handleChange}
          required
        />

        <input
          type="text"
          name="username"
          placeholder="Username"
          value={form.username}
          onChange={handleChange}
          required
        />

        <input
          type="password"
          name="password"
          placeholder="Enter your Password"
          value={form.password}
          onChange={handleChange}
          required
          autoComplete="new-password"
        />

        <input
          type="password"
          name="confirmPassword"
          placeholder="Confirm your Password"
          value={form.confirmPassword}
          onChange={handleChange}
          required
          autoComplete="new-password"
        />
        {error && <div className="error-message">* {error}</div>}

        <button type="submit" className="signup-button" disabled={loading}>
          Sign Up
        </button>

        <p className="login-link">
          Already have an account? <a href="/login">Login</a>
        </p>
      </form>
    </div>
  );
};

export default SignUp;
