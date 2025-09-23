import axiosInstance from '../../service/AppService.tsx';

interface LoginResponse {
  access: string;
  refresh: string;
}

export const loginUser = async (
  email: string,
  password: string
): Promise<LoginResponse> => {
  const res = await axiosInstance.post('/api/token/', {
    email,
    password,
  });

  const data = res.data as LoginResponse;

  // ✅ Save tokens so interceptors can attach them immediately
  localStorage.setItem('access_token', data.access);
  localStorage.setItem('refresh_token', data.refresh);

  return data;
};
