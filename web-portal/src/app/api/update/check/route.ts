import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '2.0.0',
    download_url: DOWNLOAD_URL,
    changelog: '🚀 v2.0.0: تسجيل دخول دائم + رفع فيديو + بث + تحليلات + مكافحة الغش + إشعارات واتساب',
  })
}
