import { NextRequest, NextResponse } from 'next/server'

const RELEASE_TAG = 'v1.0.0'
const REPO = 'rootkali-cmd/Darsak-ai'
const GITHUB_BASE = `https://github.com/${REPO}/releases/download/${RELEASE_TAG}`

/**
 * Proxy download from GitHub releases.
 * This keeps the user on darsakai.com during download
 * instead of redirecting them to GitHub.
 */
export async function GET(
  request: NextRequest,
  { params }: { params: { file: string } }
) {
  const file = params.file

  if (!file || !file.match(/^[\w\-\.]+$/)) {
    return NextResponse.json({ error: 'Invalid filename' }, { status: 400 })
  }

  const githubUrl = `${GITHUB_BASE}/${encodeURIComponent(file)}`

  try {
    const response = await fetch(githubUrl, {
      redirect: 'follow',
    })

    if (!response.ok) {
      return NextResponse.json(
        { error: 'File not found on release' },
        { status: 404 }
      )
    }

    const contentType = response.headers.get('content-type') || 'application/octet-stream'
    const contentLength = response.headers.get('content-length')

    // Stream the response back with proper download headers
    const headers = new Headers()
    headers.set('Content-Type', contentType)
    headers.set('Content-Disposition', `attachment; filename="${file}"`)
    if (contentLength) {
      headers.set('Content-Length', contentLength)
    }

    return new NextResponse(response.body, {
      status: 200,
      headers,
    })
  } catch (error) {
    console.error('Download proxy error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch file' },
      { status: 500 }
    )
  }
}
