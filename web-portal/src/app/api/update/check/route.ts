import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '2.1.2',
    download_url: DOWNLOAD_URL,
    changelog: 'صفحة هبوط جديدة + تسجيل حساب\nكود QR حقيقي للمدرس + مشاركة\nلوحة تحكم بتصميم جديد\nOnboarding مرة واحدة فقط\nإصلاح 405 + 500 في كل الـ APIs\nحدود الباقات: طلاب + AI + تخزين',
  })
}
