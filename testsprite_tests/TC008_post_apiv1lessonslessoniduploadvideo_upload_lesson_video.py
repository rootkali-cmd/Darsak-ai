import requests
import io
import os

BASE_URL = "http://localhost:8000/api/v1"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}"
}
TIMEOUT = 30

def create_lesson():
    url = f"{BASE_URL}/lessons/"
    payload = {
        "title": "Test Lesson for Video Upload"
    }
    response = requests.post(url, json=payload, headers=HEADERS, timeout=TIMEOUT)
    response.raise_for_status()
    return response.json()

def delete_lesson(lesson_id):
    url = f"{BASE_URL}/lessons/{lesson_id}"
    response = requests.delete(url, headers=HEADERS, timeout=TIMEOUT)
    response.raise_for_status()
    return response.json()

def test_post_apiv1_lessons_lessonid_upload_video():
    lesson = None
    try:
        # Create lesson to upload video to
        lesson = create_lesson()
        lesson_id = lesson.get("id")
        assert lesson_id, "Lesson ID not returned on creation"
        
        url = f"{BASE_URL}/lessons/{lesson_id}/upload-video"

        # Prepare a small valid video file in memory for upload (simulate upload)
        # Using a small dummy MP4 header with no real frames - just for testing API accept
        dummy_video_content = (
            b'\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41\x00\x00\x00\x08free\x00\x00\x02\x0cmoov'
        )
        files = {
            "file": ("test_video.mp4", io.BytesIO(dummy_video_content), "video/mp4")
        }
        response = requests.post(url, headers=HEADERS, files=files, timeout=TIMEOUT)
        response.raise_for_status()
        data = response.json()

        # Validate response fields
        assert isinstance(data.get("ok"), bool), "Missing or invalid 'ok' field"
        assert data.get("ok") is True, "'ok' field is not True"
        assert isinstance(data.get("message_id"), int), "Missing or invalid 'message_id'"
        assert isinstance(data.get("file_id"), str) and data.get("file_id").strip() != "", "Missing or invalid 'file_id'"
        assert isinstance(data.get("duration"), int) and data.get("duration") >= 0, "Missing or invalid 'duration'"

        # Verify lesson is auto-published by fetching lesson details
        lesson_get_url = f"{BASE_URL}/lessons/{lesson_id}"
        lesson_response = requests.get(lesson_get_url, headers=HEADERS, timeout=TIMEOUT)
        lesson_response.raise_for_status()
        lesson_data = lesson_response.json()
        assert lesson_data.get("is_published") is True, "Lesson is not auto-published after video upload"

    finally:
        if lesson and "id" in lesson:
            try:
                delete_lesson(lesson["id"])
            except Exception:
                pass

test_post_apiv1_lessons_lessonid_upload_video()