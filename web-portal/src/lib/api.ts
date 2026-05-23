import axios from 'axios'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api'

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor - add auth token
api.interceptors.request.use(
  (config) => {
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('access_token')
      if (token) {
        config.headers.Authorization = `Bearer ${token}`
      }
    }
    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor - handle token refresh
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true

      const refreshToken = typeof window !== 'undefined' ? localStorage.getItem('refresh_token') : null
      if (refreshToken) {
        try {
          const response = await axios.post(`${API_BASE_URL}/auth/refresh`, {
            refresh_token: refreshToken,
          })

          const { access_token, refresh_token } = response.data
          if (typeof window !== 'undefined') {
            localStorage.setItem('access_token', access_token)
            localStorage.setItem('refresh_token', refresh_token)
          }

          originalRequest.headers.Authorization = `Bearer ${access_token}`
          return api(originalRequest)
        } catch (refreshError) {
          if (typeof window !== 'undefined') {
            localStorage.removeItem('access_token')
            localStorage.removeItem('refresh_token')
            window.location.href = '/login'
          }
          return Promise.reject(refreshError)
        }
      }
    }

    return Promise.reject(error)
  }
)

// Auth API
export const authApi = {
  login: (email: string, password: string) =>
    api.post('/auth/login', { email, password }),
  register: (data: { email: string; full_name: string; password: string; role: string }) =>
    api.post('/auth/register', data),
  getMe: () => api.get('/auth/me'),
  updateMe: (data: { full_name?: string; password?: string }) =>
    api.patch('/auth/me', data),
  refresh: (refresh_token: string) =>
    api.post('/auth/refresh', { refresh_token }),
}

// Students API
export const studentsApi = {
  list: (params?: { skip?: number; limit?: number; search?: string }) =>
    api.get('/students/', { params }),
  get: (id: string) => api.get(`/students/${id}`),
  create: (data: { full_name: string; phone?: string; parent_phone?: string; grade_level?: string; pin?: string }) =>
    api.post('/students/', data),
  update: (id: string, data: { full_name?: string; phone?: string; parent_phone?: string; grade_level?: string; pin?: string }) =>
    api.patch(`/students/${id}`, data),
  delete: (id: string) => api.delete(`/students/${id}`),
  count: () => api.get('/students/count'),
  analyze: (data: { student_id: string; subject: string; grades: any[] }) =>
    api.post('/students/analyze', data),
  exportPdf: (id: string) =>
    api.get(`/students/${id}/report/pdf`, { responseType: 'blob' }),
}

// Groups API
export const groupsApi = {
  list: (params?: { skip?: number; limit?: number }) =>
    api.get('/groups/', { params }),
  get: (id: string) => api.get(`/groups/${id}`),
  create: (data: { name: string; subject: string; level: string; day_of_week: string; time_slot: string }) =>
    api.post('/groups/', data),
  update: (id: string, data: { name?: string; subject?: string; level?: string; day_of_week?: string; time_slot?: string }) =>
    api.patch(`/groups/${id}`, data),
  delete: (id: string) => api.delete(`/groups/${id}`),
}

// Attendance API
export const attendanceApi = {
  list: (params?: { student_id?: string; group_id?: string; from_date?: string; to_date?: string }) =>
    api.get('/attendance/', { params }),
  mark: (data: { student_id: string; group_id?: string; status: string; date?: string; notes?: string }) =>
    api.post('/attendance/', data),
  bulk: (data: { group_id?: string; date?: string; records: { student_id: string; status: string; notes?: string }[] }) =>
    api.post('/attendance/bulk', data),
  stats: (params?: { group_id?: string; date?: string }) =>
    api.get('/attendance/stats', { params }),
}

// Grades API
export const gradesApi = {
  list: (params?: { student_id?: string; subject?: string; skip?: number; limit?: number }) =>
    api.get('/grades/', { params }),
  create: (data: { student_id: string; exam_name: string; subject: string; score: number; max_score?: number; wrong_questions?: number[]; notes?: string }) =>
    api.post('/grades/', data),
  bulk: (data: { subject: string; exam_name: string; grades: { student_code: string; score: number; max_score?: number }[] }) =>
    api.post('/grades/bulk', data),
  stats: (params?: { subject?: string }) =>
    api.get('/grades/stats', { params }),
  delete: (id: string) => api.delete(`/grades/${id}`),
}

// Invoices API
export const invoicesApi = {
  list: (params?: { student_id?: string; paid?: boolean; skip?: number; limit?: number }) =>
    api.get('/invoices/', { params }),
  create: (data: { student_id: string; amount: number; description?: string; paid?: boolean; payment_date?: string; signature?: string }) =>
    api.post('/invoices/', data),
  update: (id: string, data: { amount?: number; description?: string; paid?: boolean; payment_date?: string; signature?: string }) =>
    api.patch(`/invoices/${id}`, data),
  delete: (id: string) => api.delete(`/invoices/${id}`),
  stats: () => api.get('/invoices/stats'),
}

// QR API
export const qrApi = {
  generate: (teacherId: string) => api.get(`/qr/generate/${teacherId}`),
  verify: (data: { teacher_id: string; teacher_code: string }) =>
    api.post('/qr/verify', data),
}

// Sync API
export const syncApi = {
  push: (data: { payload_type: string; ciphertext: string; iv: string; auth_tag: string }) =>
    api.post('/sync/push', data),
  pull: (params?: { since?: string; limit?: number }) =>
    api.get('/sync/pull', { params }),
  ack: (data: { acked_ids: string[] }) =>
    api.post('/sync/ack', data),
}

// Subscriptions API
export const subscriptionsApi = {
  plans: () => api.get('/subscriptions/plans'),
  my: () => api.get('/subscriptions/my'),
  activate: (code: string) => api.post('/subscriptions/activate', { code }),
  check: (feature: string) => api.post('/subscriptions/check', { feature }),
}
