/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  productionBrowserSourceMaps: false,
  images: {
    domains: [
      'fmoqdezqbpefptyyzfvw.supabase.co',
      'prod.spline.design',
      'images.unsplash.com',
      'images.pexels.com',
      'videos.pexels.com',
    ],
    remotePatterns: [
      { protocol: 'https', hostname: 'prod.spline.design' },
      { protocol: 'https', hostname: 'fmoqdezqbpefptyyzfvw.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
      { protocol: 'https', hostname: 'images.pexels.com' },
      { protocol: 'https', hostname: 'videos.pexels.com' },
      { protocol: 'https', hostname: 'storage.googleapis.com' },
    ],
  },
  async redirects() {
    return [
      { source: '/download', destination: '/#download', permanent: true },
      { source: '/pricing', destination: '/#pricing', permanent: true },
      { source: '/features', destination: '/#features', permanent: true },
      { source: '/contact', destination: '/#contact', permanent: true },
      { source: '/login', destination: '/', permanent: true },
      { source: '/register', destination: '/', permanent: true },
      { source: '/about', destination: '/', permanent: true },
      { source: '/faq', destination: '/', permanent: true },
      { source: '/terms', destination: '/terms', permanent: false },
      { source: '/privacy', destination: '/privacy', permanent: false },
      { source: '/refund', destination: '/refund', permanent: false },
      { source: '/dashboard', destination: '/', permanent: true },
      { source: '/dashboard/:path*', destination: '/', permanent: true },
    ]
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self' data: https:; media-src 'self' https: data: blob:; connect-src 'self' https:; frame-src 'self' https:; worker-src 'self' blob:;",
          },
        ],
      },
    ]
  },
}

module.exports = nextConfig
