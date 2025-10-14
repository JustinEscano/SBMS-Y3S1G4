import axiosInstance from "../../service/AppService.tsx";
import { jwtDecode } from "jwt-decode";

interface LoginResponse {
  access: string;
  refresh: string;
  userId: string;
}

interface TokenPayload {
  user_id: string;
  exp: number;
  token_type: string;
}

export const loginUser = async (
  email: string,
  password: string
): Promise<LoginResponse> => {
  const res = await axiosInstance.post("/api/token/", { email, password });

  const { access, refresh } = res.data as { access: string; refresh: string };

  // ✅ Decode JWT payload to extract user_id
  const decoded = jwtDecode<TokenPayload>(access);

  // ✅ Save tokens and user_id to localStorage
  localStorage.setItem("access_token", access);
  localStorage.setItem("refresh_token", refresh);
  localStorage.setItem("user_id", decoded.user_id);

  return {
    access,
    refresh,
    userId: decoded.user_id,
  };
};
