function setCookie(name: string, value: string, days: number) {
  if (typeof document === 'undefined') return
  const expires = new Date(Date.now() + days * 864e5).toUTCString()
  document.cookie = `${name}=${encodeURIComponent(value)}; path=/; expires=${expires}; Secure; SameSite=Lax`
}

function removeCookie(name: string) {
  if (typeof document === 'undefined') return
  document.cookie = `${name}=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; SameSite=Lax`
}

export const auth = {
  getToken: () => typeof window !== 'undefined' ? localStorage.getItem('access_token') : null,
  getRefreshToken: () => typeof window !== 'undefined' ? localStorage.getItem('refresh_token') : null,
  setTokens: (access: string, refresh: string) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('access_token', access)
      localStorage.setItem('refresh_token', refresh)
      setCookie('access_token', access, 1)
      setCookie('refresh_token', refresh, 30)
    }
  },
  clearTokens: () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('access_token')
      localStorage.removeItem('refresh_token')
      removeCookie('access_token')
      removeCookie('refresh_token')
    }
  },
  isAuthenticated: () => typeof window !== 'undefined' ? !!localStorage.getItem('access_token') : false,
  syncCookies: () => {
    if (typeof window === 'undefined') return
    const token = localStorage.getItem('access_token')
    const refresh = localStorage.getItem('refresh_token')
    if (token) setCookie('access_token', token, 1)
    if (refresh) setCookie('refresh_token', refresh, 30)
  },
}
