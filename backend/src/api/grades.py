from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from src.utils.dependencies import get_current_teacher
from src.schemas.grade import GradeCreate, GradeBulkUpload, GradeResponse, StudentBrief
from src.services import grade_service, student_service, audit_service
from src.core.subscription_guard import enforce_grade_limit

router = APIRouter(prefix="/grades", tags=["Grades"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


async def _enrich_grade(g: dict) -> GradeResponse:
    resp = GradeResponse(**g)
    try:
        s = await student_service.get_by_id(g["student_id"])
        if s:
            resp.student = StudentBrief(
                id=s["id"],
                full_name=s.get("full_name", ""),
                code=s.get("code"),
                phone=s.get("phone"),
            )
    except Exception:
        pass
    return resp


async def _enrich_grades(grades: list[dict]) -> list[GradeResponse]:
    student_ids = list({str(g["student_id"]) for g in grades if g.get("student_id")})
    students_map = {}
    for sid in student_ids:
        try:
            s = await student_service.get_by_id(sid)
            if s:
                students_map[sid] = StudentBrief(
                    id=s["id"],
                    full_name=s.get("full_name", ""),
                    code=s.get("code"),
                    phone=s.get("phone"),
                )
        except Exception:
            pass
    result = []
    for g in grades:
        try:
            resp = GradeResponse(**g)
            sid = str(g.get("student_id", ""))
            if sid in students_map:
                resp.student = students_map[sid]
            result.append(resp)
        except Exception:
            continue
    return result


@router.post("/", response_model=GradeResponse, status_code=status.HTTP_201_CREATED)
async def create_grade(
    grade_data: GradeCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        if not grade_data.student_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="student_id is required")

        await enforce_grade_limit(current_user["id"])

        student = await student_service.get_by_id(str(grade_data.student_id))
        if not student or student["teacher_id"] != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

        grade = await grade_service.create(
            student_id=str(grade_data.student_id),
            teacher_id=current_user["id"],
            exam_name=grade_data.exam_name,
            subject=grade_data.subject,
            score=grade_data.score,
            max_score=grade_data.max_score,
            wrong_questions=grade_data.wrong_questions,
            notes=grade_data.notes,
        )

        await audit_service.log(
            actor_type=current_user.get("role", "teacher"),
            action="grade_created",
            actor_id=current_user["id"],
            resource_type="grade",
            resource_id=grade["id"],
            ip_address=get_client_ip(request),
        )

        return await _enrich_grade(grade)
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.getLogger("darsak").error("Failed to create grade: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to create grade: internal error")


@router.post("/bulk", response_model=list[GradeResponse], status_code=status.HTTP_201_CREATED)
async def bulk_upload_grades(
    bulk_data: GradeBulkUpload,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    results = []
    for row in bulk_data.grades:
        student = await student_service.get_by_code(row.student_code)
        if not student or student["teacher_id"] != current_user["id"]:
            continue

        grade = await grade_service.create(
            student_id=student["id"],
            teacher_id=current_user["id"],
            exam_name=bulk_data.exam_name,
            subject=bulk_data.subject,
            score=row.score,
            max_score=row.max_score,
        )
        results.append(await _enrich_grade(grade))

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="grade_bulk_upload",
        actor_id=current_user["id"],
        resource_type="grade",
        ip_address=get_client_ip(request),
        metadata={"count": len(results)},
    )

    return results


@router.get("/", response_model=list[GradeResponse])
async def list_grades(
    student_id: str | None = None,
    subject: str | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    filters = {"teacher_id": current_user["id"]}
    if student_id:
        filters["student_id"] = student_id
    if subject:
        filters["subject"] = subject

    grades = await grade_service.list(filters, limit=limit, offset=skip)
    return await _enrich_grades(grades)


@router.get("/stats")
async def grade_stats(
    subject: str | None = None,
    current_user: dict = Depends(get_current_teacher),
):
    stats = await grade_service.get_stats(current_user["id"], subject)
    return stats


@router.get("/{grade_id}", response_model=GradeResponse)
async def get_grade(
    grade_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    grades = await grade_service.list({"teacher_id": current_user["id"]}, limit=200)
    grade = next((g for g in grades if g["id"] == grade_id), None)
    if not grade:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grade not found")
    return await _enrich_grade(grade)


@router.put("/{grade_id}")
async def update_grade(
    grade_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        existing = await grade_service.get_by_id(grade_id)
        if not existing or existing.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

        body = await request.json()
        update_dict = {k: v for k, v in body.items() if v is not None and k not in ("id", "teacher_id", "type")}
        updated = await grade_service.update(grade_id, update_dict)

        await audit_service.log(
            actor_type=current_user.get("role", "teacher"),
            action="grade_updated",
            actor_id=current_user["id"],
            resource_type="grade",
            resource_id=grade_id,
            ip_address=get_client_ip(request),
        )

        return {
            "ok": True,
            "data": {
                k: str(v) if hasattr(v, "hex") else (v.isoformat() if hasattr(v, "isoformat") else v)
                for k, v in updated.items()
            }
        }
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.getLogger("darsak").error("Failed to update grade %s: %s", grade_id, exc)
        raise HTTPException(status_code=500, detail=f"فشل تحديث الدرجة: internal error")


@router.delete("/{grade_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_grade(
    grade_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    grades = await grade_service.list({"teacher_id": current_user["id"]}, limit=200)
    grade = next((g for g in grades if g["id"] == grade_id), None)
    if not grade:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grade not found")

    await grade_service.delete(grade_id)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="grade_deleted",
        actor_id=current_user["id"],
        resource_type="grade",
        resource_id=grade_id,
        ip_address=get_client_ip(request),
    )
