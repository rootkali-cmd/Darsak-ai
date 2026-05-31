import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.6',
    download_url: DOWNLOAD_URL,
    changelog: 'إظهار اسم الطالب في الدرجات + إصلاح تسجيل الخروج التلقائي + إصلاح تعديل الطلاب',
  })
}
