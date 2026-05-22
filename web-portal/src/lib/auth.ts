export const auth = {
  getToken: () => typeof window !== 'undefined' ? localStorage.getItem('access_token') : null,
  getRefreshToken: () => typeof window !== 'undefined' ? localStorage.getItem('refresh_token') : null,
  setTokens: (access: string, refresh: string) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('access_token', access)
      localStorage.setItem('refresh_token', refresh)
    }
  },
  clearTokens: () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('access_token')
      localStorage.removeItem('refresh_token')
    }
  },
  isAuthenticated: () => typeof window !== 'undefined' ? !!localStorage.getItem('access_token') : false,
}
