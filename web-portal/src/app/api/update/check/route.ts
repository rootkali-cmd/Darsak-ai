import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.9',
    download_url: DOWNLOAD_URL,
    changelog: 'إصلاح الكاميرا نهائياً (بدون arguments زائدة)\nتمديد الفترة التجريبية إلى 30 يوم\nتمديد صلاحية الـ Token إلى 30 يوم\nفيديوهات غير محدوده بجودة عالية على كل الباقات',
  })
}
