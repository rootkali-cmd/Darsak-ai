import { NextRequest, NextResponse } from 'next/server'

const REPO = 'rootkali-cmd/Darsak-ai'

// Map each downloadable filename to its GitHub release tag.
// Update this map when adding new releases or files.
const FILE_RELEASE_MAP: Record<string, string> = {
  // Teacher app
  'DarsakAI-Teacher-v1.2.6.apk': 'v1.2.6',

  // Student app — last updated in v1.0.0 release
  'DarsakAI-Student.apk': 'v1.0.0',

  // Desktop app
  'DarsakAI-Setup.exe': 'v1.0.0',
  'DarsakAI-Windows.zip': 'v1.0.0',
}

const DEFAULT_TAG = 'v1.0.0'

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

  const releaseTag = FILE_RELEASE_MAP[file] || DEFAULT_TAG
  const githubUrl = `https://github.com/${REPO}/releases/download/${releaseTag}/${encodeURIComponent(file)}`

  // 302 redirect - the browser will download directly from GitHub
  return NextResponse.redirect(githubUrl, { status: 302 })
}
