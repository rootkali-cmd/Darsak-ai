import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

const PUBLIC_PATHS = ['/login', '/register', '/', '/pricing', '/about', '/contact', '/faq', '/terms', '/privacy', '/download']

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  const isPublic = PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith('/_next') || pathname.startsWith('/api') || pathname.startsWith('/static'))
  if (isPublic) return NextResponse.next()

  const token = request.cookies.get('access_token')?.value
  if (!token) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }

  if (pathname.startsWith('/admin')) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]))
      if (payload.role !== 'admin') {
        return NextResponse.redirect(new URL('/dashboard', request.url))
      }
    } catch {
      return NextResponse.redirect(new URL('/login', request.url))
    }
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|public).*)'],
}
