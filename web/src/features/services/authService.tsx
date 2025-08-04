import axiosInstance from '../../service/AppService';

interface LoginResponse {
  access: string;
  refresh?: string;
}

export const loginUser = async (
  username: string,
  password: string
): Promise<LoginResponse> => {
  const res = await axiosInstance.post('/api/token/', {
    username,
    password,
  });
  return res.data as LoginResponse;
};