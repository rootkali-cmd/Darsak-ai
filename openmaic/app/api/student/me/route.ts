import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

export async function GET() {
  const cookieStore = await cookies();
  const studentCookie = cookieStore.get('openmaic_student')?.value;

  if (!studentCookie) {
    return NextResponse.json({ student: null }, { status: 200 });
  }

  try {
    const student = JSON.parse(studentCookie);
    return NextResponse.json({ student });
  } catch {
    return NextResponse.json({ student: null }, { status: 200 });
  }
}
