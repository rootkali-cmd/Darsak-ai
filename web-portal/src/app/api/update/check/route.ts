import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.4.1',
    download_url: DOWNLOAD_URL,
    changelog: 'تسجيل دخول جديد بالكامل — flutter_secure_storage\nكاميرا CameraX + ML Kit — كل أنواع الباركود\nدروس بدون أخطاء — إعادة برمجة كاملة\nكود المدرس يعمل الآن',
  })
}
