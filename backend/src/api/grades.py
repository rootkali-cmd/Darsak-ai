from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from src.utils.dependencies import get_current_teacher
from src.schemas.grade import GradeCreate, GradeBulkUpload, GradeResponse
from src.services import grade_service, student_service, audit_service
from src.core.subscription_guard import enforce_grade_limit

router = APIRouter(prefix="/grades", tags=["Grades"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("/", response_model=GradeResponse, status_code=status.HTTP_201_CREATED)
async def create_grade(
    grade_data: GradeCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
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

    return GradeResponse(**grade)


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
        results.append(GradeResponse(**grade))

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
    return [GradeResponse(**g) for g in grades]


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
    return GradeResponse(**grade)


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
