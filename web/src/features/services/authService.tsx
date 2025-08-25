import axiosInstance from '../../service/AppService';

interface LoginResponse {
  access: string;
  refresh?: string;
}

export const loginUser = async (
  email: string,
  password: string
): Promise<LoginResponse> => {
  const res = await axiosInstance.post('/api/token/', {
    email,
    password,
  });
  return res.data as LoginResponse;
};