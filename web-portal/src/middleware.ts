import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

function isValidJwt(token: string): boolean {
  return /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)
}

function isTokenExpired(token: string): boolean {
  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')))
    return typeof payload.exp === 'number' && payload.exp < Math.floor(Date.now() / 1000)
  } catch {
    return true
  }
}

const PUBLIC_PATHS = ['/login', '/register', '/', '/pricing', '/about', '/contact', '/faq', '/terms', '/privacy', '/download']

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  if (/\.(png|webp|jpg|jpeg|svg|ico|gif|woff2?|ttf|css|map|apk)$/i.test(pathname)) {
    return NextResponse.next()
  }

  const isPublic = PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith('/_next') || pathname.startsWith('/static'))
  if (isPublic) return NextResponse.next()

  const token = request.cookies.get('access_token')?.value
  if (!token) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }

  if (!isValidJwt(token) || isTokenExpired(token)) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
