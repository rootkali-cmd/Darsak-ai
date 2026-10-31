import { NextRequest, NextResponse } from 'next/server';

/** Convert string to Uint8Array */
function encode(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

/** Convert ArrayBuffer to hex string */
function bufToHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** Verify an HMAC-signed token using Web Crypto API (Edge-compatible) */
async function verifyToken(token: string, secret: string): Promise<boolean> {
  const dotIndex = token.indexOf('.');
  if (dotIndex === -1) return false;

  const payload = token.substring(0, dotIndex);
  const signature = token.substring(dotIndex + 1);

  const keyData = encode(secret);
  const key = await crypto.subtle.importKey(
    'raw',
    keyData.buffer as ArrayBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const data = encode(payload);
  const expected = bufToHex(await crypto.subtle.sign('HMAC', key, data.buffer as ArrayBuffer));

  if (signature.length !== expected.length) return false;
  let mismatch = 0;
  for (let i = 0; i < signature.length; i++) {
    mismatch |= signature.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return mismatch === 0;
}

/** Decode base64url to string */
function base64UrlDecode(str: string): string {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) base64 += '=';
  return decodeURIComponent(
    Array.from(atob(base64))
      .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
      .join(''),
  );
}

export async function middleware(request: NextRequest) {
  const accessCode = process.env.ACCESS_CODE;
  const { pathname, searchParams } = request.nextUrl;

  // Internal API key for trusted backend-to-OpenMAIC calls
  const internalKey = request.headers.get('x-internal-key');
  if (internalKey && accessCode && internalKey === accessCode) {
    return NextResponse.next();
  }

  // Whitelist: access-code endpoints, health check, student endpoint
  if (
    pathname.startsWith('/api/access-code/') ||
    pathname === '/api/health' ||
    pathname === '/api/student/me'
  ) {
    return NextResponse.next();
  }

  // ── Student token from backend (DarsakAI Flutter app) ──
  const studentToken = searchParams.get('student_token');
  if (studentToken && accessCode) {
    const parts = studentToken.split('.');
    if (parts.length === 2) {
      const [payloadB64, signature] = parts;
      const keyData = encode(accessCode);
      const key = await crypto.subtle.importKey(
        'raw',
        keyData.buffer as ArrayBuffer,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign'],
      );
      const data = encode(payloadB64);
      const expected = bufToHex(
        await crypto.subtle.sign('HMAC', key, data.buffer as ArrayBuffer),
      );
      if (signature === expected) {
        try {
          const studentData = JSON.parse(base64UrlDecode(payloadB64));
          // Set student data cookie (30 days) and auth cookie (7 days)
          const response = NextResponse.redirect(
            new URL(pathname, request.url),
          );
          response.cookies.set('openmaic_student', JSON.stringify(studentData), {
            httpOnly: true,
            sameSite: 'lax',
            path: '/',
            secure: true,
            maxAge: 60 * 60 * 24 * 30,
          });
          response.cookies.set('openmaic_access', studentToken, {
            httpOnly: true,
            sameSite: 'lax',
            path: '/',
            secure: true,
            maxAge: 60 * 60 * 24 * 7,
          });
          return response;
        } catch {
          // Invalid payload, fall through
        }
      }
    }
  }

  // Check if already authenticated (access-code cookie or student cookie)
  const accessCookie = request.cookies.get('openmaic_access');
  if (accessCookie?.value) {
    if (!accessCode || (await verifyToken(accessCookie.value, accessCode))) {
      return NextResponse.next();
    }
  }

  // No ACCESS_CODE set → allow everything
  if (!accessCode) {
    return NextResponse.next();
  }

  // API requests without valid cookie → 401
  if (pathname.startsWith('/api/')) {
    return NextResponse.json(
      { success: false, errorCode: 'INVALID_REQUEST', error: 'Access code required' },
      { status: 401 },
    );
  }

  // Page requests → let through, frontend shows AccessCodeGuard modal
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|logos/).*)'],
};
