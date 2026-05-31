import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.3',
    download_url: DOWNLOAD_URL,
    changelog: 'إصلاح ألوان الوضع الفاتح + إصلاح كاميرا + إصلاح إنشاء المجموعات + إصلاح بروفايل الطالب + إصلاح تسجيل الدخول الدائم',
  })
}
