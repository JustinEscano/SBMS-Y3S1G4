let logoutFn: (() => void) | null = null;

// Called inside AuthProvider to register the logout function
export const registerLogout = (fn: () => void) => {
  logoutFn = fn;
};

// Called inside axios interceptor when 401 occurs
export const logoutUser = () => {
  if (logoutFn) logoutFn();
  else {
    console.warn("logoutUser called but logoutFn not registered yet");
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    window.location.href = "/login";
  }
};
