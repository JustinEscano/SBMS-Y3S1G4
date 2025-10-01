// service/AppService.tsx
import axios from "axios";

const axiosInstance = axios.create({
  baseURL: "http://localhost:8000/",
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

// 🔥 Request interceptor - add auth header
axiosInstance.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("access_token");

    console.log("🔥 Token found:", !!token);

    if (token) {
      console.log("🔥 Adding auth header for:", config.url);
      config.headers = {
        ...config.headers,
        Authorization: `Bearer ${token}`,
      };
    } else {
      console.log("🔥 No token - unauthenticated request to:", config.url);
    }

    return config;
  },
  (error) => Promise.reject(error)
);

// 🔥 Response interceptor
axiosInstance.interceptors.response.use(
  (response) => {
    console.log("🔥 API Success:", response.status, response.config.url);
    return response;
  },
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      console.log("🔥 Attempting token refresh...");

      const refreshToken = localStorage.getItem("refresh_token");
      if (refreshToken) {
        try {
          // use base axios so we don’t recurse into interceptor
          const { data } = await axios.post(
            "http://localhost:8000/api/token/refresh/",
            { refresh: refreshToken }
          );

          const { access } = data as { access: string };

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
      }
    }

    console.error("🔥 API Error:", error.response?.status, error.config?.url);
    return Promise.reject(error);
  }
);

export default axiosInstance;
