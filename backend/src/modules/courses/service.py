import logging
import uuid
from io import BytesIO
from src.core.security.supabase_repo import SupabaseRepository
from src.modules.storage.r2_service import r2_service

logger = logging.getLogger("darsak")

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    logger.warning("Pillow not installed; course cover image resizing disabled")

MAX_COVER_WIDTH = 1200


class CourseService:
    def __init__(self):
        self.courses_repo = SupabaseRepository("courses")
        self.pricing_repo = SupabaseRepository("course_pricing")
        self.chapters_repo = SupabaseRepository("course_chapters")
        self.lessons_repo = SupabaseRepository("course_lessons")
        self.files_repo = SupabaseRepository("course_files")
        self.locks_repo = SupabaseRepository("content_locks")
        self.media_repo = SupabaseRepository("teacher_media")

    async def create_course(self, teacher_id: str, data: dict) -> dict:
        course = await self.courses_repo.insert({
            "teacher_id": teacher_id,
            "title": data["title"],
            "description": data.get("description"),
            "subject": data.get("subject"),
            "level": data.get("level"),
        })
        await self.pricing_repo.insert({
            "course_id": course["id"],
            "teacher_id": teacher_id,
            "center_price": 0.00,
            "platform_price": 0.00,
            "is_free_for_center": True,
            "currency": "EGP",
        })
        logger.info("Course created: %s by teacher %s", course["id"], teacher_id)
        return dict(course)

    async def get_course(self, course_id: str) -> dict | None:
        course = await self.courses_repo.select_one({"id": course_id})
        if not course:
            return None
        pricing = await self.pricing_repo.select_one({"course_id": course_id})
        chapters = await self.chapters_repo.select(
            {"course_id": course_id}, limit=100, order="sort_order asc"
        )
        for ch in chapters:
            ch["lessons"] = await self.lessons_repo.select(
                {"chapter_id": ch["id"]}, limit=200, order="sort_order asc"
            )
        course["pricing"] = pricing
        course["chapters"] = chapters
        return dict(course)

    async def list_courses(self, teacher_id: str) -> list[dict]:
        courses = await self.courses_repo.select(
            {"teacher_id": teacher_id}, limit=200, order="created_at desc"
        )
        return [dict(c) for c in courses]

    async def update_course(self, course_id: str, data: dict) -> dict:
        return await self.courses_repo.update({"id": course_id}, data)

    async def delete_course(self, teacher_id: str, course_id: str) -> int:
        course = await self.courses_repo.select_one({"id": course_id, "teacher_id": teacher_id})
        if not course:
            raise ValueError("Course not found")

        delete_count = 0

        chapters = await self.chapters_repo.select({"course_id": course_id}, limit=500)
        for ch in chapters:
            lessons = await self.lessons_repo.select({"chapter_id": ch["id"]}, limit=500)
            for lesson in lessons:
                lesson_files = await self.files_repo.select({"lesson_id": lesson["id"]}, limit=500)
                for f in lesson_files:
                    r2_key = f.get("r2_key")
                    if r2_key and r2_service.enabled:
                        try:
                            await r2_service.delete(r2_key)
                            delete_count += 1
                        except Exception as e:
                            logger.warning("Failed to delete R2 file %s: %s", r2_key, e)
                if lesson.get("r2_video_key") and r2_service.enabled:
                    try:
                        await r2_service.delete(lesson["r2_video_key"])
                        delete_count += 1
                    except Exception as e:
                        logger.warning("Failed to delete R2 video %s: %s", lesson["r2_video_key"], e)
                await self.locks_repo.delete({"lesson_id": lesson["id"]})
                await self.files_repo.delete({"lesson_id": lesson["id"]})
            for lesson in lessons:
                await self.lessons_repo.delete({"id": lesson["id"]})

        for ch in chapters:
            await self.chapters_repo.delete({"id": ch["id"]})

        if course.get("cover_image_r2_key") and r2_service.enabled:
            try:
                await r2_service.delete(course["cover_image_r2_key"])
                delete_count += 1
            except Exception as e:
                logger.warning("Failed to delete R2 cover %s: %s", course["cover_image_r2_key"], e)

        await self.pricing_repo.delete({"course_id": course_id})
        await self.courses_repo.delete({"id": course_id})

        logger.info("Cascade deleted course %s: %d files", course_id, delete_count)
        return delete_count

    async def update_pricing(self, course_id: str, data: dict) -> dict:
        existing = await self.pricing_repo.select_one({"course_id": course_id})
        if existing:
            return await self.pricing_repo.update({"course_id": course_id}, data)
        return await self.pricing_repo.insert({**data, "course_id": course_id})

    async def create_chapter(self, course_id: str, teacher_id: str, data: dict) -> dict:
        chapter = await self.chapters_repo.insert({
            "course_id": course_id,
            "teacher_id": teacher_id,
            "title": data["title"],
            "description": data.get("description"),
            "sort_order": data.get("sort_order", 0),
        })
        return dict(chapter)

    async def list_chapters(self, course_id: str) -> list[dict]:
        return await self.chapters_repo.select(
            {"course_id": course_id}, limit=100, order="sort_order asc"
        )

    async def delete_chapter(self, chapter_id: str) -> bool:
        lessons = await self.lessons_repo.select({"chapter_id": chapter_id}, limit=500)
        for lesson in lessons:
            await self.delete_lesson(str(lesson["id"]))
        return await self.chapters_repo.delete({"id": chapter_id})

    async def create_lesson(self, chapter_id: str, course_id: str, teacher_id: str, data: dict) -> dict:
        lesson = await self.lessons_repo.insert({
            "chapter_id": chapter_id,
            "course_id": course_id,
            "teacher_id": teacher_id,
            "title": data["title"],
            "description": data.get("description"),
            "is_free": data.get("is_free", False),
            "has_exam": data.get("has_exam", False),
            "has_homework": data.get("has_homework", False),
            "sort_order": data.get("sort_order", 0),
        })
        return dict(lesson)

    async def list_lessons(self, chapter_id: str) -> list[dict]:
        return await self.lessons_repo.select(
            {"chapter_id": chapter_id}, limit=200, order="sort_order asc"
        )

    async def get_lesson(self, lesson_id: str) -> dict | None:
        lesson = await self.lessons_repo.select_one({"id": lesson_id})
        if not lesson:
            return None
        lesson["files"] = await self.files_repo.select({"lesson_id": lesson_id}, limit=100)
        lesson["lock"] = await self.locks_repo.select_one({"lesson_id": lesson_id})
        return dict(lesson)

    async def update_lesson(self, lesson_id: str, data: dict) -> dict:
        return await self.lessons_repo.update({"id": lesson_id}, data)

    async def delete_lesson(self, lesson_id: str) -> int:
        delete_count = 0
        lesson = await self.lessons_repo.select_one({"id": lesson_id})
        if not lesson:
            return 0

        if lesson.get("r2_video_key") and r2_service.enabled:
            try:
                await r2_service.delete(lesson["r2_video_key"])
                delete_count += 1
            except Exception as e:
                logger.warning("Failed to delete R2 video %s: %s", lesson["r2_video_key"], e)

        files = await self.files_repo.select({"lesson_id": lesson_id}, limit=500)
        for f in files:
            r2_key = f.get("r2_key")
            if r2_key and r2_service.enabled:
                try:
                    await r2_service.delete(r2_key)
                    delete_count += 1
                except Exception as e:
                    logger.warning("Failed to delete R2 file %s: %s", r2_key, e)

        await self.locks_repo.delete({"lesson_id": lesson_id})
        await self.files_repo.delete({"lesson_id": lesson_id})
        await self.lessons_repo.delete({"id": lesson_id})

        logger.info("Deleted lesson %s: %d R2 files", lesson_id, delete_count)
        return delete_count

    async def upload_lesson_video(self, lesson_id: str, file_content: bytes, filename: str, mime_type: str) -> dict:
        lesson = await self.lessons_repo.select_one({"id": lesson_id})
        if not lesson:
            raise ValueError("Lesson not found")

        ext = filename.split(".")[-1] if "." in filename else "mp4"
        safe_name = f"{uuid.uuid4().hex}.{ext}"
        teacher_id = str(lesson["teacher_id"])

        r2_key = await r2_service.upload(teacher_id, "video", safe_name, file_content, mime_type=mime_type)

        await self.lessons_repo.update({"id": lesson_id}, {
            "r2_video_key": r2_key,
            "video_url": r2_key,
        })

        return {"r2_key": r2_key, "lesson_id": lesson_id}

    async def upload_lesson_file(self, lesson_id: str, file_content: bytes, filename: str, mime_type: str) -> dict:
        lesson = await self.lessons_repo.select_one({"id": lesson_id})
        if not lesson:
            raise ValueError("Lesson not found")

        ext = filename.split(".")[-1] if "." in filename else "bin"
        safe_name = f"{uuid.uuid4().hex}.{ext}"
        teacher_id = str(lesson["teacher_id"])
        course_id = str(lesson["course_id"])

        r2_key = await r2_service.upload(teacher_id, "document", safe_name, file_content, mime_type=mime_type)

        record = await self.files_repo.insert({
            "lesson_id": lesson_id,
            "course_id": course_id,
            "teacher_id": teacher_id,
            "file_name": filename,
            "file_size_bytes": len(file_content),
            "mime_type": mime_type,
            "r2_key": r2_key,
        })

        return dict(record)

    async def set_content_lock(self, lesson_id: str, data: dict) -> dict:
        lesson = await self.lessons_repo.select_one({"id": lesson_id})
        if not lesson:
            raise ValueError("Lesson not found")
        course_id = str(lesson["course_id"])
        existing = await self.locks_repo.select_one({"lesson_id": lesson_id})
        if existing:
            return await self.locks_repo.update({"lesson_id": lesson_id}, {
                "requires_exam_id": data.get("requires_exam_id"),
                "lock_type": data.get("lock_type", "exam"),
            })
        return await self.locks_repo.insert({
            "lesson_id": lesson_id,
            "course_id": course_id,
            "requires_exam_id": data.get("requires_exam_id"),
            "lock_type": data.get("lock_type", "exam"),
        })

    async def get_lesson_files(self, lesson_id: str) -> list[dict]:
        return await self.files_repo.select({"lesson_id": lesson_id}, limit=100)

    async def upload_course_cover(self, course_id: str, file_content: bytes, mime_type: str) -> dict:
        course = await self.courses_repo.select_one({"id": course_id})
        if not course:
            raise ValueError("Course not found")

        # Resize image to max 1200px width if Pillow is available
        if HAS_PIL:
            try:
                img = Image.open(BytesIO(file_content))
                if img.width > MAX_COVER_WIDTH:
                    ratio = MAX_COVER_WIDTH / img.width
                    new_height = int(img.height * ratio)
                    img = img.resize((MAX_COVER_WIDTH, new_height), Image.LANCZOS)
                    buf = BytesIO()
                    fmt = img.format or "JPEG"
                    img.save(buf, format=fmt, quality=85)
                    file_content = buf.getvalue()
                    logger.info("Course cover resized: %dx%d -> %dx%d", img.width, img.height, MAX_COVER_WIDTH, new_height)
            except Exception as e:
                logger.warning("Failed to resize course cover image: %s", e)

        ext = "jpg"
        safe_name = f"cover_{uuid.uuid4().hex}.{ext}"
        teacher_id = str(course["teacher_id"])

        r2_key = await r2_service.upload(teacher_id, "image", safe_name, file_content, mime_type=mime_type)

        await self.courses_repo.update({"id": course_id}, {
            "cover_image_r2_key": r2_key,
        })

        return {"r2_key": r2_key, "course_id": course_id}


course_service = CourseService()
