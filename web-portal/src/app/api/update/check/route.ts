import { NextResponse } from 'next/server'

const REPO = 'rootkali-cmd/Darsak-ai'
const TAG = 'v1.3.1'
const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.1',
    download_url: DOWNLOAD_URL,
    changelog: 'إصلاح شامل: ألوان الوضع الفاتح، تسجيل دخول دائم، كاميرا، امتحانات، مجموعات، فواتير، درجات',
  })
}
