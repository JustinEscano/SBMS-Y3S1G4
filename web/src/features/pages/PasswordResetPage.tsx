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
      await verifyOTPPasswordReset(email, otp, newPassword);
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
            <div className="text-center mb-6">
              <h2 className="text-xl font-semibold text-white mb-2">Reset Password</h2>
              <p className="text-sm text-gray-400">Enter your email to receive a reset code.</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1.5">Email Address</label>
                <input
                  type="email"
                  placeholder="example@gmail.com"
                  className="w-full bg-[#1e293b]/50 border border-gray-700/50 text-white rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all placeholder-gray-500"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
              <button 
                type="submit" 
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 disabled:text-gray-400 text-white font-medium rounded-lg px-4 py-3 transition-colors shadow-lg shadow-blue-500/20 disabled:shadow-none" 
                disabled={loading || isSubmitting || !isValidEmail(email)}
              >
                {loading ? 'Sending...' : 'Send Reset Code'}
              </button>
            </div>
          </>
        );
      case 'enterOTP':
        return (
          <>
            <div className="text-center mb-6">
              <h2 className="text-xl font-semibold text-white mb-2">Verify OTP</h2>
              <p className="text-sm text-gray-400">Enter the 6-digit code sent to <span className="text-white font-medium">{email}</span></p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1.5">6-Digit Code</label>
                <input
                  type="text"
                  placeholder="123456"
                  maxLength={6}
                  className="w-full bg-[#1e293b]/50 border border-gray-700/50 text-white font-mono text-center tracking-widest text-xl rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all placeholder-gray-600"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  required
                />
              </div>
              <div className="flex gap-3">
                <button
                  type="button"
                  className="flex-1 bg-[#1e293b] hover:bg-gray-700 border border-gray-700/50 text-gray-300 font-medium rounded-lg px-4 py-3 transition-colors disabled:opacity-50"
                  onClick={goToEmailStep}
                  disabled={loading || isSubmitting}
                >
                  Change Email
                </button>
                <button 
                  type="submit" 
                  className="flex-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 disabled:text-gray-400 text-white font-medium rounded-lg px-4 py-3 transition-colors shadow-lg shadow-blue-500/20 disabled:shadow-none" 
                  disabled={loading || isSubmitting || otp.length !== 6}
                >
                  {loading ? 'Verifying...' : 'Continue'}
                </button>
              </div>
            </div>
          </>
        );
      case 'enterNewPassword':
        return (
          <>
            <div className="text-center mb-6">
              <h2 className="text-xl font-semibold text-white mb-2">New Password</h2>
              <p className="text-sm text-gray-400">Enter your new secure password.</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1.5">New Password</label>
                <input
                  type="password"
                  placeholder="••••••••"
                  className="w-full bg-[#1e293b]/50 border border-gray-700/50 text-white rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all placeholder-gray-500"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1.5">Confirm New Password</label>
                <input
                  type="password"
                  placeholder="••••••••"
                  className="w-full bg-[#1e293b]/50 border border-gray-700/50 text-white rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all placeholder-gray-500"
                  value={confirmNewPassword}
                  onChange={(e) => setConfirmNewPassword(e.target.value)}
                  required
                />
              </div>
              <div className="flex gap-3">
                <button
                  type="button"
                  className="w-24 bg-[#1e293b] hover:bg-gray-700 border border-gray-700/50 text-gray-300 font-medium rounded-lg px-4 py-3 transition-colors disabled:opacity-50"
                  onClick={() => setStep('enterOTP')}
                  disabled={loading || isSubmitting}
                >
                  Back
                </button>
                <button 
                  type="submit" 
                  className="flex-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 disabled:text-gray-400 text-white font-medium rounded-lg px-4 py-3 transition-colors shadow-lg shadow-blue-500/20 disabled:shadow-none" 
                  disabled={loading || isSubmitting || newPassword.length < 6 || newPassword !== confirmNewPassword}
                >
                  {loading ? 'Resetting...' : 'Reset Password'}
                </button>
              </div>
            </div>
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
    <div className="min-h-screen flex items-center justify-center bg-[#020617] relative overflow-hidden font-sans">
      {/* Overlay spinner */}
      {loading && (
        <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
          <div className="w-12 h-12 border-4 border-blue-500/30 border-t-blue-500 rounded-full animate-spin"></div>
        </div>
      )}

      {/* Random stars */}
      {stars.map((star, idx) => (
        <div
          key={idx}
          className="absolute w-1 h-1 bg-blue-400 rounded-full opacity-30 shadow-[0_0_10px_2px_rgba(96,165,250,0.5)]"
          style={{ top: `${star.y}px`, left: `${star.x}px` }}
        />
      ))}

      <div className="w-full max-w-md p-8 rounded-2xl bg-[#0f172a] border border-gray-700/50 shadow-2xl relative z-10 m-4">
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-full bg-gradient-to-tr from-blue-600 to-purple-600 flex items-center justify-center shadow-lg shadow-blue-500/20 mb-4">
            <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
          </div>
          <h2 className="text-2xl font-bold tracking-tight text-white mb-1">Orbit</h2>
          <p className="text-sm text-gray-400">Smart Building Management</p>
        </div>

        <form className="space-y-5" onSubmit={(e) => {
          const onSubmit = getOnSubmit();
          if (onSubmit) onSubmit(e);
        }}>
          {renderStep()}
          {error && <div className="text-sm text-red-400 bg-red-400/10 border border-red-400/20 p-3 rounded-lg text-center mb-4">{error}</div>}
          {success && <div className="text-sm text-green-400 bg-green-400/10 border border-green-400/20 p-3 rounded-lg text-center mb-4">{success}</div>}
          
          <div className="text-center mt-6">
            <Link to="/login" className="text-sm font-medium text-blue-400 hover:text-blue-300 transition-colors">
              Back to Login
            </Link>
          </div>
        </form>
      </div>
    </div>
  );
}

export default PasswordResetScreen;