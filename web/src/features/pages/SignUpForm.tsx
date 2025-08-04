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

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (form.password !== form.confirmPassword) {
      alert("Passwords do not match.");
      return;
    }

    try {
      await axios.post('http://localhost:8000/api/register/', {
        email: form.email,
        username: form.username,
        password: form.password,
        role: form.role,
      });

      alert("Registration successful. Please log in.");
      navigate('/login');
    } catch (error: any) {
      console.error(error.response || error);
      alert('Signup failed. Please try again.');
    }
  };

  return (
    <div className="signup-container">

      <form onSubmit={handleSubmit} className="signup-form">
        <h2 className="signup-title">Create an account</h2>
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

        <button type="submit" className="signup-button">Sign Up</button>

        <div className="divider">OR</div>

        <div className="social-login">
          <button type="button" className="google-button">
            <img src="/google-icon.svg" alt="Google" /> Login Via Google
          </button>
          <button type="button" className="facebook-button">
            <img src="/facebook-icon.svg" alt="Facebook" /> Login Via Facebook
          </button>
        </div>

        <p className="login-link">
          Already have an account? <a href="/login">Login</a>
        </p>
      </form>
    </div>
  );
};

export default SignUp;