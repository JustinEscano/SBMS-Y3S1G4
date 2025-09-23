// service/AppService.tsx
import axios from "axios";

const axiosInstance = axios.create({
  baseURL: "http://localhost:8000/",
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

// --- Refresh handling state ---
let isRefreshing = false;
let refreshSubscribers: ((token: string) => void)[] = [];

function onRefreshed(token: string) {
  refreshSubscribers.forEach((cb) => cb(token));
  refreshSubscribers = [];
}

function addSubscriber(callback: (token: string) => void) {
  refreshSubscribers.push(callback);
}

// 🔥 Request interceptor - add auth header
axiosInstance.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("access_token");

    if (token) {
      config.headers = {
        ...config.headers,
        Authorization: `Bearer ${token}`,
      };
    }

    // 🚀 Debug logger
    console.log("📡 [REQUEST]", {
      method: config.method?.toUpperCase(),
      url: config.baseURL + config.url,
      headers: config.headers,
    });

    return config;
  },
  (error) => Promise.reject(error)
);

// 🔥 Response interceptor - handle 401
axiosInstance.interceptors.response.use(
  (response) => {
    console.log("✅ [RESPONSE]", {
      status: response.status,
      url: response.config.url,
    });
    return response;
  },
  async (error) => {
    console.error("❌ [RESPONSE ERROR]", {
      status: error.response?.status,
      url: error.config?.url,
      data: error.response?.data,
    });

    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      if (!isRefreshing) {
        isRefreshing = true;
        const refreshToken = localStorage.getItem("refresh_token");

        if (refreshToken) {
          try {
            const { data } = await axios.post(
              "http://localhost:8000/api/token/refresh/",
              { refresh: refreshToken }
            );

            const { access } = data as { access: string };
            localStorage.setItem("access_token", access);

            isRefreshing = false;
            onRefreshed(access);

            originalRequest.headers.Authorization = `Bearer ${access}`;
            return axiosInstance(originalRequest);
          } catch (refreshError) {
            isRefreshing = false;
            refreshSubscribers = [];
            localStorage.removeItem("access_token");
            localStorage.removeItem("refresh_token");
            window.location.href = "/login";
            return Promise.reject(refreshError);
          }
        }
      }

      return new Promise((resolve) => {
        addSubscriber((token: string) => {
          originalRequest.headers.Authorization = `Bearer ${token}`;
          resolve(axiosInstance(originalRequest));
        });
      });
    }

    return Promise.reject(error);
  }
);

export default axiosInstance;
