import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.4',
    download_url: DOWNLOAD_URL,
    changelog: 'إضافة زر التحقق من التحديثات في المزيد',
  })
}
