import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.10',
    download_url: DOWNLOAD_URL,
    changelog: 'إصلاح تسجيل الخروج التلقائي: حفظ المستخدم من JWT فوراً قبل استدعاء API\nإصلاح الكاميرا: تجربة الكاميرا الأمامية عند فشل الخلفية\nتحسين الثبات والأمان',
  })
}
