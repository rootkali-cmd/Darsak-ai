import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.7',
    download_url: DOWNLOAD_URL,
    changelog: 'نظام الدروس والفيديو: رفع وبث عبر تيليجرام\nتحليلات المشاهدة ومكافحة الغش\nإشعارات واتساب لأولياء الأمور\nإصلاح تسجيل الخروج التلقائي (ping + retry + JWT fallback)\nإصلاح 20+ حلقة تحميل لا نهائية (dynamic ID)',
  })
}
