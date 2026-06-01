import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.11',
    download_url: DOWNLOAD_URL,
    changelog: 'إصلاح جذري لتسجيل الخروج: الأنتيرسبتور لا يمسح التوكن أبداً\nكاميرا: أمامية أولاً + إدخال يدوي كبديل\nإصلاح خطأ 500 في إنشاء المجموعات',
  })
}
