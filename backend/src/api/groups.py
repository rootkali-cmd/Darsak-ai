from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from src.utils.dependencies import get_current_teacher
from src.schemas.group import GroupCreate, GroupUpdate, GroupResponse
from src.services import group_service, audit_service, student_service

router = APIRouter(prefix="/groups", tags=["Groups"])


def get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("/", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
async def create_group(
    group_data: GroupCreate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.create(
        teacher_id=current_user["id"],
        name=group_data.name,
        subject=group_data.subject,
        level=group_data.level.value if hasattr(group_data.level, 'value') else group_data.level,
        day_of_week=group_data.day_of_week,
        time_slot=group_data.time_slot,
    )

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="group_created",
        actor_id=current_user["id"],
        resource_type="group",
        resource_id=group["id"],
        ip_address=get_client_ip(request),
    )

    return GroupResponse(**group)


async def _add_student_count(groups: list[dict], teacher_id: str) -> list[dict]:
    all_students = await student_service.list_by_teacher(teacher_id, limit=10000)
    group_counts: dict[str, int] = {}
    for s in all_students:
        gid = s.get("group_id")
        if gid:
            group_counts[gid] = group_counts.get(gid, 0) + 1
    for g in groups:
        g["student_count"] = group_counts.get(g["id"], 0)
    return groups


@router.get("/", response_model=list[GroupResponse])
async def list_groups(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_teacher),
):
    groups = await group_service.list_by_teacher(current_user["id"], limit=limit)
    groups = groups[skip:skip+limit]
    groups = await _add_student_count(groups, current_user["id"])
    return [GroupResponse(**g) for g in groups]


@router.get("/{group_id}", response_model=GroupResponse)
async def get_group(
    group_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
    [group] = await _add_student_count([group], current_user["id"])
    return GroupResponse(**group)


@router.get("/{group_id}/student-count")
async def group_student_count(
    group_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
    students = await student_service.list_by_teacher(current_user["id"], limit=10000)
    count = sum(1 for s in students if s.get("group_id") == group_id)
    return {"student_count": count}


@router.patch("/{group_id}", response_model=GroupResponse)
async def update_group(
    group_id: str,
    update_data: GroupUpdate,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    data = update_data.model_dump(exclude_unset=True)
    if "level" in data and hasattr(data["level"], 'value'):
        data["level"] = data["level"].value
    updated = await group_service.update(group_id, data)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="group_updated",
        actor_id=current_user["id"],
        resource_type="group",
        resource_id=group_id,
        ip_address=get_client_ip(request),
    )

    updated_list = await _add_student_count([updated], current_user["id"])
    return GroupResponse(**updated_list[0])


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_group(
    group_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    group = await group_service.get_by_id(group_id)
    if not group or group["teacher_id"] != current_user["id"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    await group_service.delete(group_id)

    await audit_service.log(
        actor_type=current_user.get("role", "teacher"),
        action="group_deleted",
        actor_id=current_user["id"],
        resource_type="group",
        resource_id=group_id,
        ip_address=get_client_ip(request),
    )
