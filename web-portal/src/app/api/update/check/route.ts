import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.12',
    download_url: DOWNLOAD_URL,
    changelog: 'كاميرا CameraX + Google ML Kit (بدون أعطال Camera2)\nتسجيل دائم: التوكن لا يمحى أبداً\nإدخال يدوي للباركود عند تعطل الكاميرا\nإصلاح خطأ 500 في الدروس',
  })
}
