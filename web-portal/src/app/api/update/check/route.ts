import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.13',
    download_url: DOWNLOAD_URL,
    changelog: 'كاميرا CameraX + Google ML Kit — باركود (كل الأنواع)\nتسجيل دخول جديد من الصفر — مفيش خروج تلقائي\nإصلاح خطأ 500 في الدروس\nشكل مستطيل للماسح الضوئي',
  })
}
