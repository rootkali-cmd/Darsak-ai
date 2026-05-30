import { NextRequest, NextResponse } from 'next/server'

const RELEASE_TAG = 'v1.0.0'
const REPO = 'rootkali-cmd/Darsak-ai'

/**
 * Redirect to GitHub releases for direct download.
 * GitHub sends the file with proper MIME type and Content-Disposition.
 * This avoids Vercel serverless function timeout on large files (60+ MB).
 */
export async function GET(
  request: NextRequest,
  { params }: { params: { file: string } }
) {
  const file = params.file

  if (!file || !file.match(/^[\w\-\.\+]+$/)) {
    return NextResponse.json({ error: 'Invalid filename' }, { status: 400 })
  }

  const githubUrl = `https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${encodeURIComponent(file)}`

  // 302 redirect - the browser will download directly from GitHub
  return NextResponse.redirect(githubUrl, { status: 302 })
}
