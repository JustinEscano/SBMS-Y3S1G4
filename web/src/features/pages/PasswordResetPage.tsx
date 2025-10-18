// PasswordResetPage.tsx - Fixed TypeScript errors: Use verifyOTPUnauthenticated for unauth flow, cast response to OTPResponse
// + Anti-spam: Submit lock, email validation, clear messages on step change
// + Full Reset on Change Email: Clears ALL fields and messages for fresh start
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { requestOTPPasswordReset, verifyOTPUnauthenticated, verifyOTPPasswordReset } from '../services/authService.tsx';
import { Link } from 'react-router-dom';
import '../pages/LoginScreen.css'; // Reuse the same CSS

type Star = { x: number; y: number };

// Define the step type as union of string literals (consistent camelCase)
type ResetStep = 'enterEmail' | 'enterOTP' | 'enterNewPassword';

// Define response interface
interface ResetResponse {
  access?: string;
  refresh?: string;
  detail: string;
}

interface OTPResponse {
  detail: string;
}

function PasswordResetScreen() {
  const [step, setStep] = useState<ResetStep>('enterEmail');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmNewPassword, setConfirmNewPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false); // NEW: Lock to prevent spam submits
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [stars, setStars] = useState<Star[]>([]);
  const navigate = useNavigate();
  const location = useLocation();

  // Generate stars randomly on mount (reuse from LoginScreen)
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

  // Optional: Pre-fill email from query params if redirected from login
  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const emailParam = params.get('email');
    if (emailParam) {
      setEmail(emailParam);
      setStep('enterOTP');
    }
  }, [location.search]);

  // NEW: Simple email validation helper
  const isValidEmail = useCallback((emailStr: string) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailStr.trim());
  }, []);

  // ENHANCED: Full reset when switching to email step (clears EVERYTHING for fresh start)
  const goToEmailStep = useCallback(() => {
    setEmail(''); // Clear email too
    setOtp('');
    setNewPassword('');
    setConfirmNewPassword('');
    setError('');
    setSuccess('');
    setStep('enterEmail');
  }, []);

  const handleRequestOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isSubmitting || !isValidEmail(email)) {
      setError('Please enter a valid email.');
      return;
    }
    setIsSubmitting(true);
    setLoading(true);
    setError('');

    try {
      await requestOTPPasswordReset(email);
      setSuccess('OTP sent to your email! Check your inbox.');
      setStep('enterOTP');
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to send OTP. Please try again.');
    } finally {
      setLoading(false);
      setIsSubmitting(false); // Unlock submit
    }
  };

  const handleVerifyOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isSubmitting || otp.length !== 6) {
      setError('OTP must be 6 digits.');
      return;
    }
    setIsSubmitting(true);
    setLoading(true);
    setError('');

    try {
      // Use unauth version (sends email + otp)
      const response = await verifyOTPUnauthenticated(email, otp) as OTPResponse;
      setSuccess(response.detail);  // Use the response detail for success message
      setStep('enterNewPassword');
    } catch (err: any) {
      setError(err.response?.data?.otp?.[0] || err.response?.data?.detail || 'Invalid OTP. Please try again.');
    } finally {
      setLoading(false);
      setIsSubmitting(false); // Unlock submit
    }
  };

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isSubmitting || newPassword.length < 6 || newPassword !== confirmNewPassword) {
      setError(newPassword.length < 6 ? 'New password must be at least 6 characters.' : 'Passwords do not match.');
      return;
    }
    setIsSubmitting(true);
    setLoading(true);
    setError('');

    try {
      // Now reset with verified OTP and new password
      const response = await verifyOTPPasswordReset(email, otp, newPassword) as ResetResponse;
      setSuccess('Password reset successfully! You can now log in.');
      setOtp('');
      setTimeout(() => navigate('/login'), 2000);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to reset password. Please try again.');
    } finally {
      setLoading(false);
      setIsSubmitting(false); // Unlock submit
    }
  };

  const renderStep = () => {
    switch (step) {
      case 'enterEmail':
        return (
          <>
            <h2 className="login-title">Reset Password</h2>
            <p className="reset-subtitle">Enter your email to receive a reset code.</p>
            <label>Email</label>
            <input
              type="email"
              placeholder="example@gmail.com"
              className="input-field"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
            <button 
              type="submit" 
              className="login-button" 
              disabled={loading || isSubmitting || !isValidEmail(email)} // Disable if invalid
            >
              {loading ? 'Sending...' : 'Send Reset Code'}
            </button>
          </>
        );
      case 'enterOTP':
        return (
          <>
            <h2 className="login-title">Verify OTP</h2>
            <p className="reset-subtitle">Enter the 6-digit code sent to {email}</p>
            <label>OTP Code</label>
            <input
              type="text"
              placeholder="123456"
              maxLength={6}
              className="input-field"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))} // Only digits
              required
            />
            <button
              type="button"
              className="login-button secondary"
              onClick={goToEmailStep} // Use helper for full reset
              disabled={loading || isSubmitting}
            >
              Change Email
            </button>
            <button 
              type="submit" 
              className="login-button" 
              disabled={loading || isSubmitting || otp.length !== 6}
            >
              {loading ? 'Verifying...' : 'Continue'}
            </button>
          </>
        );
      case 'enterNewPassword':
        return (
          <>
            <h2 className="login-title">New Password</h2>
            <p className="reset-subtitle">Enter your new password.</p>
            <label>New Password</label>
            <input
              type="password"
              placeholder="Enter new password"
              className="input-field"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              required
            />
            <label>Confirm New Password</label>
            <input
              type="password"
              placeholder="Confirm new password"
              className="input-field"
              value={confirmNewPassword}
              onChange={(e) => setConfirmNewPassword(e.target.value)}
              required
            />
            <button
              type="button"
              className="login-button secondary"
              onClick={() => setStep('enterOTP')}
              disabled={loading || isSubmitting}
            >
              Back
            </button>
            <button 
              type="submit" 
              className="login-button" 
              disabled={loading || isSubmitting || newPassword.length < 6 || newPassword !== confirmNewPassword}
            >
              {loading ? 'Resetting...' : 'Reset Password'}
            </button>
          </>
        );
      default:
        return null;
    }
  };

  // Dynamic onSubmit based on step
  const getOnSubmit = () => {
    switch (step) {
      case 'enterEmail':
        return handleRequestOTP;
      case 'enterOTP':
        return handleVerifyOTP;
      case 'enterNewPassword':
        return handleResetPassword;
      default:
        return undefined;
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

      <form className="login-card" onSubmit={getOnSubmit()}>
        {renderStep()}
        {error && <div className="error-message">* {error}</div>}
        {success && <div className="success-message">* {success}</div>}
        <p className="signup-text">
          <Link to="/login">Back to Login</Link>
        </p>
      </form>
    </div>
  );
}

export default PasswordResetScreen;