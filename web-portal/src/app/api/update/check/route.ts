import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.5',
    download_url: DOWNLOAD_URL,
    changelog: 'إظهار كود الطالب + إصلاح الكاميرا + إصلاح الدرجات والفواتير + تفعيل كود الاشتراك + الدفع عبر السيرفر + ألوان ثابتة + حدود لحقول الإدخال + حماية من الحقن',
  })
}
