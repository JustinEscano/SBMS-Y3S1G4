import axios from 'axios';

const axiosInstance = axios.create({
  baseURL: 'http://localhost:8000/', // Your Django root API URL
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
});

export default axiosInstance;