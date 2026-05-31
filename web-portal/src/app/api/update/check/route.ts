import { NextResponse } from 'next/server'

const DOWNLOAD_URL = 'https://darsakai.com/download'

export async function GET() {
  return NextResponse.json({
    latest_version: '1.3.2',
    download_url: DOWNLOAD_URL,
    changelog: 'دفع الفواتير (فودافون كاش + انستاباي)، مساعد ذكاء اصطناعي لتوليد الامتحانات، كود QR للمدرس، مشاركة الكود مع الطلاب',
  })
}
