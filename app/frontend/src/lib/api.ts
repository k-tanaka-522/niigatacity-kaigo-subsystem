import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api';

export const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// リクエストインターセプター（JWT トークン追加）
api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

// レスポンスインターセプター（エラーハンドリング）
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// 認証API
export const authAPI = {
  login: (email: string, password: string) =>
    api.post('/auth/login', { email, password }),

  register: (data: {
    email: string;
    password: string;
    name: string;
    role?: string;
    officeId?: number;
  }) => api.post('/auth/register', data),
};

// 申請API
export const applicationsAPI = {
  getAll: (params?: { status?: string; page?: number; pageSize?: number }) =>
    api.get('/applications', { params }),

  getById: (id: number) =>
    api.get(`/applications/${id}`),

  create: (data: {
    applicationType: string;
    title: string;
    content?: string;
    status?: string;
  }) => api.post('/applications', data),

  update: (id: number, data: {
    applicationType?: string;
    title?: string;
    content?: string;
  }) => api.put(`/applications/${id}`, data),

  delete: (id: number) =>
    api.delete(`/applications/${id}`),

  submit: (id: number) =>
    api.post(`/applications/${id}/submit`),

  review: (id: number, data: { approved: boolean; comment?: string }) =>
    api.post(`/applications/${id}/review`, data),
};
