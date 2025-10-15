import axios from "axios";
import { logoutUser } from "../features/services/logoutUser"; // 👈 import here

const axiosInstance = axios.create({
  baseURL: "http://localhost:8000/",
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

axiosInstance.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("access_token");
    if (token) {
      if (!config.headers) config.headers = {};
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

axiosInstance.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      const refreshToken = localStorage.getItem("refresh_token");
      if (refreshToken) {
        try {
        // use base axios so we don’t recurse into interceptor
        const { data } = await axios.post<{ access: string }>(
          "http://localhost:8000/api/token/refresh/",
          { refresh: refreshToken }
        );

        const access = data.access; // ✅ now TypeScript knows 'access' exists

        // ✅ Store new token
        localStorage.setItem("access_token", access);

        console.log("✅ Token refreshed successfully");

        // Update and retry the original request
        originalRequest.headers = {
          ...originalRequest.headers,
          Authorization: `Bearer ${access}`,
        };

        return axiosInstance(originalRequest);
      } catch (refreshError) {
        console.error("❌ Token refresh failed:", refreshError);

        localStorage.removeItem("access_token");
        localStorage.removeItem("refresh_token");

        window.location.href = "/login";
        return Promise.reject(refreshError);
      }
      } else {
        logoutUser(); // ✅ use AuthContext logout
      }
    }
    return Promise.reject(error);
  }
);

export default axiosInstance;
