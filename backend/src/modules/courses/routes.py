import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from .schemas import CourseCreate, CourseUpdate, CoursePricingUpdate, ChapterCreate, LessonCreate, ContentLockUpdate, SharedLectureCreate
from .service import course_service
from ..storage.r2_service import r2_service
from src.core.security.supabase_repo import SupabaseRepository
from src.utils.dependencies import get_current_teacher, get_current_student, get_current_student_optional
from src.core.subscription_guard import require_active_subscription
from src.modules.storage.routes import _check_storage_quota
from typing import Optional

logger = logging.getLogger("darsak")

router = APIRouter(prefix="/courses", tags=["Courses"])
files_repo = SupabaseRepository("course_files")
chapters_repo = SupabaseRepository("course_chapters")
courses_repo = SupabaseRepository("courses")
enrollments_repo = SupabaseRepository("student_course_enrollments")


async def _enrich_course(item: dict, student_registration_type: str = None) -> dict:
    """Add pricing + cover_image_url to a course dict."""
    pricing_repo = SupabaseRepository("course_pricing")
    pricing = await pricing_repo.select_one({"course_id": item["id"]})
    if pricing:
        item["pricing"] = pricing
    cover_key = item.get("cover_image_r2_key")
    if cover_key and r2_service.enabled:
        try:
            item["cover_image_url"] = await r2_service.generate_signed_url(cover_key, expires_minutes=60)
        except Exception:
            item["cover_image_url"] = None
    else:
        item["cover_image_url"] = None
    if student_registration_type and pricing:
        is_free_flag = pricing.get("is_free_for_center", False)
        platform_price = float(pricing.get("platform_price", 0) or 0)
        if student_registration_type == "center":
            item["is_free_for_student"] = is_free_flag
        else:
            item["is_free_for_student"] = platform_price <= 0
    return item


@router.get("/available")
async def list_available_courses(
    current_student: Optional[dict] = Depends(get_current_student_optional),
):
    """Public endpoint - students browse published courses."""
    items = await courses_repo.select(
        {"is_published": True},
        limit=200, order="created_at desc"
    )
    reg_type = current_student.get("registration_type") if current_student else None
    enriched = []
    for item in items:
        enriched.append(await _enrich_course(item, student_registration_type=reg_type))
    return {"items": enriched}


@router.get("/student/{course_id}")
async def get_course_for_student(
    course_id: str,
    current_student: dict = Depends(get_current_student),
):
    """Student view of a course - chapters and lessons with lock enforcement."""
    course = await course_service.get_course(course_id)
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    if not course.get("is_published"):
        raise HTTPException(status_code=404, detail="Course not available")

    student_id = current_student["id"]
    teacher_id = str(course.get("teacher_id", ""))
    student_reg_type = current_student.get("registration_type", "center")

    enrollment = await enrollments_repo.select_one({"student_id": student_id, "course_id": course_id})
    is_enrolled = enrollment is not None

    pricing = course.get("pricing") or {}
    is_free_flag = pricing.get("is_free_for_center", False)
    if student_reg_type == "center":
        is_free = is_free_flag
    else:
        is_free = float(pricing.get("platform_price", 0) or 0) <= 0
    center_price = float(pricing.get("center_price", 0) or 0)
    platform_price = float(pricing.get("platform_price", 0) or 0)

    cover_key = course.get("cover_image_r2_key")
    if cover_key and r2_service.enabled:
        try:
            course["cover_image_url"] = await r2_service.generate_signed_url(cover_key, expires_minutes=60)
        except Exception:
            course["cover_image_url"] = None
    else:
        course["cover_image_url"] = None

    for chapter in course.get("chapters", []):
        for lesson in chapter.get("lessons", []):
            lock = await course_service.locks_repo.select_one({"lesson_id": lesson["id"]})
            lesson["is_locked"] = False
            lesson["lock_type"] = None
            if lock:
                lt = lock.get("lock_type", "exam")
                if lt in ("payment", "both") and not is_free and not is_enrolled:
                    lesson["is_locked"] = True
                    lesson["lock_type"] = lt

    return {
        "ok": True,
        "data": course,
        "is_enrolled": is_enrolled,
        "is_free": is_free,
        "center_price": center_price,
        "platform_price": platform_price,
    }


@router.get("/student/{course_id}/access")
async def check_course_access(
    course_id: str,
    current_student: dict = Depends(get_current_student),
):
    """Check if student has access to a course."""
    course = await courses_repo.select_one({"id": course_id})
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    student_id = current_student["id"]
    student_reg_type = current_student.get("registration_type", "center")
    enrollment = await enrollments_repo.select_one({"student_id": student_id, "course_id": course_id})
    pricing = await course_service.pricing_repo.select_one({"course_id": course_id})
    is_free_flag = pricing.get("is_free_for_center", True) if pricing else True
    platform_price = float(pricing.get("platform_price", 0) or 0) if pricing else 0
    if student_reg_type == "center":
        is_free = is_free_flag
    else:
        is_free = platform_price <= 0

    return {
        "ok": True,
        "is_enrolled": enrollment is not None,
        "is_free": is_free,
        "center_price": float(pricing.get("center_price", 0) or 0) if pricing else 0,
        "platform_price": platform_price,
    }


@router.post("/student/{course_id}/purchase")
async def purchase_course(
    course_id: str,
    current_student: dict = Depends(get_current_student),
):
    """Student purchases a course from their wallet."""
    course = await courses_repo.select_one({"id": course_id})
    if not course or not course.get("is_published"):
        raise HTTPException(status_code=404, detail="Course not found")

    student_id = current_student["id"]
    teacher_id = str(course["teacher_id"])
    student_reg_type = current_student.get("registration_type", "center")

    existing = await enrollments_repo.select_one({"student_id": student_id, "course_id": course_id})
    if existing:
        return {"ok": True, "message": "Already enrolled", "enrollment_id": str(existing["id"])}

    pricing = await course_service.pricing_repo.select_one({"course_id": course_id})
    is_free_flag = pricing.get("is_free_for_center", True) if pricing else True
    is_free = is_free_flag and student_reg_type == "center"

    if is_free:
        enrollment = await enrollments_repo.insert({
            "student_id": student_id,
            "course_id": course_id,
            "teacher_id": teacher_id,
            "paid_amount": 0,
        })
        return {"ok": True, "message": "Free course enrolled", "enrollment_id": str(enrollment["id"])}

    from ..finance.service import finance_service
    from ..wallet.service import WalletService

    try:
        # Determine price: center students use center_price, online use platform_price
        if student_reg_type == "center":
            price = float(pricing.get("center_price", 0) or 0) if pricing else 0
        else:
            price = float(pricing.get("platform_price", 0) or 0) if pricing else 0

        if price <= 0:
            enrollment = await enrollments_repo.insert({
                "student_id": student_id,
                "course_id": course_id,
                "teacher_id": teacher_id,
                "paid_amount": 0,
            })
            return {"ok": True, "message": "Free course enrolled", "enrollment_id": str(enrollment["id"])}

        result = await finance_service.deduct_from_wallet(
            student_id=student_id,
            amount=price,
            description=f"شراء كورس: {course.get('title', '')}",
            ref_type="course",
            ref_id=course_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    enrollment = await enrollments_repo.insert({
        "student_id": student_id,
        "course_id": course_id,
        "teacher_id": teacher_id,
        "paid_amount": price,
    })

    # Credit teacher wallet
    try:
        wallet_service = WalletService()
        await wallet_service.credit_wallet(
            teacher_id=teacher_id,
            amount=price,
            description=f"بيع كورس: {course.get('title', '')}",
            ref_type="enrollment",
            ref_id=enrollment["id"],
        )
    except Exception as e:
        logger.error("Failed to credit teacher wallet for course %s: %s", course_id, e)

    return {"ok": True, "message": "Course purchased", "enrollment_id": str(enrollment["id"]), "balance_after": result["balance_after"]}


@router.get("/student/enrolled/list")
async def list_enrolled_courses(
    current_student: dict = Depends(get_current_student),
):
    """List courses the student is enrolled in."""
    student_id = current_student["id"]
    enrollments = await enrollments_repo.select({"student_id": student_id}, limit=200)
    course_ids = [e["course_id"] for e in enrollments]
    if not course_ids:
        return {"items": []}

    items = []
    for cid in course_ids:
        course = await courses_repo.select_one({"id": cid})
        if course and course.get("is_published"):
            await _enrich_course(course)
            items.append(course)
    return {"items": items}


@router.get("/student/{course_id}/shared-lectures")
async def list_shared_lectures_for_student(
    course_id: str,
    current_student: dict = Depends(get_current_student),
):
    """List shared lectures visible to the student based on their group."""
    student_id = current_student["id"]
    student_group_id = current_student.get("group_id")
    if not student_group_id:
        return {"items": []}

    shared_lectures_repo = SupabaseRepository("shared_lectures")
    all_lectures = await shared_lectures_repo.select({"course_id": course_id}, limit=200, order="created_at desc")
    visible = [l for l in all_lectures if student_group_id in (l.get("group_ids") or [])]
    return {"items": visible}


@router.get("/student/{course_id}/lessons/{lesson_id}")
async def get_lesson_for_student(
    course_id: str,
    lesson_id: str,
    current_student: dict = Depends(get_current_student),
):
    """Student view of a single lesson - enforces content locks."""
    lesson = await course_service.get_lesson(lesson_id)
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if str(lesson.get("course_id")) != course_id:
        raise HTTPException(status_code=400, detail="Lesson does not belong to this course")

    student_id = current_student["id"]
    student_reg_type = current_student.get("registration_type", "center")
    enrollment = await enrollments_repo.select_one({"student_id": student_id, "course_id": course_id})
    is_enrolled = enrollment is not None

    pricing = await course_service.pricing_repo.select_one({"course_id": course_id})
    is_free_flag = pricing.get("is_free_for_center", True) if pricing else True
    platform_price = float(pricing.get("platform_price", 0) or 0) if pricing else 0
    if student_reg_type == "center":
        is_free = is_free_flag
    else:
        is_free = platform_price <= 0

    lock = lesson.get("lock")
    if lock and lock.get("lock_type") in ("payment", "both") and not is_free and not is_enrolled:
        raise HTTPException(status_code=403, detail="This lesson is locked. Purchase the course to access.")

    r2_key = lesson.get("r2_video_key")
    if r2_key and r2_service.enabled:
        try:
            lesson["video_signed_url"] = await r2_service.generate_signed_url(r2_key, expires_minutes=120)
        except Exception:
            lesson["video_signed_url"] = lesson.get("video_url")
    else:
        lesson["video_signed_url"] = lesson.get("video_url")

    lesson_files = await files_repo.select({"lesson_id": lesson_id}, limit=50)
    enriched_files = []
    for f in (lesson_files or []):
        file_key = f.get("r2_file_key")
        if file_key and r2_service.enabled:
            try:
                f["signed_url"] = await r2_service.generate_signed_url(file_key, expires_minutes=120)
            except Exception:
                f["signed_url"] = None
        enriched_files.append(f)
    lesson["files"] = enriched_files

    return {"ok": True, "data": lesson}


@router.get("")
async def list_courses(current_user: dict = Depends(get_current_teacher)):
    items = await course_service.list_courses(current_user["id"])
    for item in items:
        cover_key = item.get("cover_image_r2_key")
        if cover_key and r2_service.enabled:
            try:
                item["cover_image_url"] = await r2_service.generate_signed_url(cover_key, expires_minutes=60)
            except Exception:
                item["cover_image_url"] = None
        else:
            item["cover_image_url"] = None
        # Attach pricing
        pricing = await course_service.pricing_repo.select_one({"course_id": item["id"]})
        item["pricing"] = pricing
        # Attach student count
        try:
            from src.core.security.supabase_repo import get_supabase
            client = await get_supabase()
            cnt = await client.table("student_course_enrollments").select("id", count="exact").eq("course_id", item["id"]).execute()
            item["students_count"] = cnt.count if hasattr(cnt, "count") else 0
        except Exception:
            item["students_count"] = 0
    return {"items": items}


@router.post("")
async def create_course(
    body: CourseCreate,
    current_user: dict = Depends(get_current_teacher),
):
    await require_active_subscription(current_user["id"])
    try:
        course = await course_service.create_course(current_user["id"], body.model_dump())
        return {"ok": True, "data": course}
    except Exception as e:
        logger.error("Course creation failed for teacher %s: %s", current_user["id"], e)
        raise HTTPException(status_code=500, detail="فشل إنشاء الكورس. يرجى المحاولة مرة أخرى.")


@router.get("/lessons/{lesson_id}")
async def get_lesson(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await course_service.get_lesson(lesson_id)
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    return {"ok": True, "data": lesson}


@router.put("/lessons/{lesson_id}")
async def update_lesson(
    lesson_id: str,
    body: LessonCreate,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await course_service.get_lesson(lesson_id)
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    updated = await course_service.update_lesson(lesson_id, body.model_dump())
    return {"ok": True, "data": updated}


@router.delete("/lessons/{lesson_id}/delete")
async def delete_lesson(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await course_service.get_lesson(lesson_id)
    if not lesson or str(lesson.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Lesson not found")
    count = await course_service.delete_lesson(lesson_id)
    return {"ok": True, "deleted_files": count, "lesson_id": lesson_id}


@router.post("/lessons/{lesson_id}/video")
async def upload_lesson_video(
    lesson_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_teacher),
):
    if not r2_service.enabled:
        raise HTTPException(status_code=503, detail="R2 storage not configured")

    lesson = await course_service.get_lesson(lesson_id)
    if not lesson or str(lesson.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Lesson not found")

    content = await file.read()
    await _check_storage_quota(current_user["id"], len(content))
    mime_type = file.content_type or "video/mp4"

    result = await course_service.upload_lesson_video(
        lesson_id, content, file.filename or "video.mp4", mime_type
    )
    return {"ok": True, "data": result}


@router.post("/lessons/{lesson_id}/file")
async def upload_lesson_file(
    lesson_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_teacher),
):
    if not r2_service.enabled:
        raise HTTPException(status_code=503, detail="R2 storage not configured")

    # Validate file extension - only allow document formats
    ALLOWED_FILE_EXTENSIONS = {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt"}
    filename = file.filename or ""
    ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_FILE_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"نوع الملف غير مسموح به ({ext}). الأنواع المسموحة: PDF, Word, Excel, PowerPoint, TXT"
        )

    lesson = await course_service.get_lesson(lesson_id)
    if not lesson or str(lesson.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Lesson not found")

    content = await file.read()
    await _check_storage_quota(current_user["id"], len(content))
    mime_type = file.content_type or "application/octet-stream"

    result = await course_service.upload_lesson_file(
        lesson_id, content, file.filename or "file", mime_type
    )
    return {"ok": True, "data": result}


@router.get("/lessons/{lesson_id}/files")
async def list_lesson_files(
    lesson_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await course_service.get_lesson(lesson_id)
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    items = await course_service.get_lesson_files(lesson_id)
    return {"items": items}


@router.put("/lessons/{lesson_id}/lock")
async def set_content_lock(
    lesson_id: str,
    body: ContentLockUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    lesson = await course_service.get_lesson(lesson_id)
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    result = await course_service.set_content_lock(lesson_id, body.model_dump())
    return {"ok": True, "data": result}


@router.delete("/files/{file_id}/delete")
async def delete_course_file(
    file_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    file_record = await files_repo.select_one({"id": file_id})
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found")

    r2_key = file_record.get("r2_key")
    if r2_key and r2_service.enabled:
        try:
            await r2_service.delete(r2_key)
        except Exception as e:
            logger.warning("Failed to delete R2 file %s: %s", r2_key, e)

    await files_repo.delete({"id": file_id})
    return {"ok": True, "file_id": file_id}


@router.delete("/chapters/{chapter_id}/delete")
async def delete_chapter(
    chapter_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    chapter = await chapters_repo.select_one({"id": chapter_id})
    if not chapter or str(chapter.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Chapter not found")
    await course_service.delete_chapter(chapter_id)
    return {"ok": True, "chapter_id": chapter_id}


@router.post("/chapters/{chapter_id}/lessons")
async def create_lesson(
    chapter_id: str,
    body: LessonCreate,
    current_user: dict = Depends(get_current_teacher),
):
    chapter = await chapters_repo.select_one({"id": chapter_id})
    if not chapter or str(chapter.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Chapter not found")

    course_id = str(chapter["course_id"])
    lesson = await course_service.create_lesson(
        chapter_id, course_id, current_user["id"], body.model_dump()
    )
    return {"ok": True, "data": lesson}


@router.get("/chapters/{chapter_id}/lessons")
async def list_lessons(
    chapter_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    chapter = await chapters_repo.select_one({"id": chapter_id})
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")
    items = await course_service.list_lessons(chapter_id)
    return {"items": items}


@router.get("/{course_id}")
async def get_course(
    course_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    course = await course_service.get_course(course_id)
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    return {"ok": True, "data": course}


@router.put("/{course_id}")
async def update_course(
    course_id: str,
    body: CourseUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    course = await course_service.get_course(course_id)
    if not course or str(course.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Course not found")
    update_data = {k: v for k, v in body.model_dump().items() if v is not None}
    if not update_data:
        return {"ok": True, "data": course}

    was_published = course.get("is_published", False)
    will_publish = update_data.get("is_published", False)
    updated = await course_service.update_course(course_id, update_data)

    if not was_published and will_publish:
        try:
            from src.services.fcm_service import send_push_to_students_of_teacher
            title = "📚 كورس جديد"
            course_title = updated.get("title") or course.get("title", "")
            body = f"تم نشر كورس جديد: {course_title}"
            await send_push_to_students_of_teacher(current_user["id"], title, body)
        except Exception as e:
            logger.warning("Failed to send push notifications for course publish: %s", e)

    return {"ok": True, "data": updated}


@router.delete("/{course_id}/delete")
async def delete_course(
    course_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        count = await course_service.delete_course(current_user["id"], course_id)
        return {"ok": True, "deleted_files": count, "course_id": course_id}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{course_id}/cover")
async def upload_course_cover(
    course_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_teacher),
):
    if not r2_service.enabled:
        raise HTTPException(status_code=503, detail="R2 storage not configured")

    course = await course_service.get_course(course_id)
    if not course or str(course.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Course not found")

    content = await file.read()

    if file.content_type and not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="يجب أن تكون الصورة من نوع صورة (JPEG, PNG, WebP)")

    await _check_storage_quota(current_user["id"], len(content))
    mime_type = file.content_type or "image/jpeg"

    result = await course_service.upload_course_cover(course_id, content, mime_type)
    cover_url = None
    if result.get("r2_key") and r2_service.enabled:
        try:
            cover_url = await r2_service.generate_signed_url(result["r2_key"], expires_minutes=60)
        except Exception:
            pass
    return {"ok": True, "data": result, "cover_image_url": cover_url}


@router.put("/{course_id}/pricing")
async def update_pricing(
    course_id: str,
    body: CoursePricingUpdate,
    current_user: dict = Depends(get_current_teacher),
):
    course = await course_service.get_course(course_id)
    if not course or str(course.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Course not found")
    result = await course_service.update_pricing(course_id, body.model_dump())
    return {"ok": True, "data": result}


@router.post("/{course_id}/shared-lecture")
async def create_shared_lecture(
    course_id: str,
    body: SharedLectureCreate,
    current_user: dict = Depends(get_current_teacher),
):
    """Create a lecture shared across multiple student groups."""
    course = await course_service.get_course(course_id)
    if not course or str(course.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Course not found")

    # Validate group IDs belong to this teacher
    groups_repo = SupabaseRepository("groups")
    for gid in body.group_ids:
        group = await groups_repo.select_one({"id": gid, "teacher_id": current_user["id"]})
        if not group:
            raise HTTPException(status_code=400, detail=f"المجموعة غير موجودة: {gid}")

    shared_lectures_repo = SupabaseRepository("shared_lectures")
    lecture = await shared_lectures_repo.insert({
        "course_id": course_id,
        "teacher_id": current_user["id"],
        "title": body.title,
        "description": body.description,
        "group_ids": body.group_ids,
        "is_free": body.is_free,
        "has_exam": body.has_exam,
    })
    return {"ok": True, "data": lecture}


@router.get("/{course_id}/shared-lectures")
async def list_shared_lectures(
    course_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    """List shared lectures for a course."""
    shared_lectures_repo = SupabaseRepository("shared_lectures")
    items = await shared_lectures_repo.select({"course_id": course_id}, limit=200, order="created_at desc")
    return {"items": items}


@router.post("/{course_id}/chapters")
async def create_chapter(
    course_id: str,
    body: ChapterCreate,
    current_user: dict = Depends(get_current_teacher),
):
    course = await course_service.get_course(course_id)
    if not course or str(course.get("teacher_id")) != current_user["id"]:
        raise HTTPException(status_code=404, detail="Course not found")
    chapter = await course_service.create_chapter(course_id, current_user["id"], body.model_dump())
    return {"ok": True, "data": chapter}


@router.get("/{course_id}/chapters")
async def list_chapters(
    course_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    course = await course_service.get_course(course_id)
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    items = await course_service.list_chapters(course_id)
    return {"items": items}
