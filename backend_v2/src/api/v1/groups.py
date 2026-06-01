import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from src.api.deps import get_current_teacher, get_current_user
from src.core.exceptions import BadRequestException, NotFoundException
from src.services.group_service import group_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/groups")


class CreateGroupBody(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    subject: str | None = None
    level: str | None = None
    day_of_week: str | None = None
    time_slot: str | None = None


class UpdateGroupBody(BaseModel):
    name: str | None = None
    subject: str | None = None
    level: str | None = None
    day_of_week: str | None = None
    time_slot: str | None = None


def _serialize(obj: dict) -> dict:
    result = {}
    for key, value in obj.items():
        if hasattr(value, "isoformat"):
            result[key] = value.isoformat()
        elif isinstance(value, str):
            result[key] = value
        else:
            result[key] = value
    return result


@router.get("/")
async def list_groups(
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        groups = await group_service.list_by_teacher(teacher_id)
        return {"data": [_serialize(g) for g in groups]}
    except Exception as e:
        logger.error(f"Error listing groups: {e}", exc_info=True)
        raise BadRequestException("Failed to list groups")


@router.post("/")
async def create_group(
    body: CreateGroupBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = str(teacher["id"])
        data = {
            "name": body.name,
            "teacher_id": teacher_id,
        }
        if body.subject:
            data["subject"] = body.subject
        if body.level:
            data["level"] = body.level
        if body.day_of_week:
            data["day_of_week"] = body.day_of_week
        if body.time_slot:
            data["time_slot"] = body.time_slot

        new_group = await group_service.create(data)
        return _serialize(new_group)
    except Exception as e:
        logger.error(f"Error creating group: {e}", exc_info=True)
        raise BadRequestException("Failed to create group")


@router.get("/{group_id}")
async def get_group(
    group_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        group = await group_service.get_by_id(group_id)
        if not group:
            raise NotFoundException("Group not found")
        if str(group.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Group not found")
        return _serialize(group)
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error getting group: {e}", exc_info=True)
        raise BadRequestException("Failed to get group")


@router.put("/{group_id}")
async def update_group(
    group_id: str,
    body: UpdateGroupBody,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        group = await group_service.get_by_id(group_id)
        if not group:
            raise NotFoundException("Group not found")
        if str(group.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Group not found")

        update_data = {}
        if body.name is not None:
            update_data["name"] = body.name
        if body.subject is not None:
            update_data["subject"] = body.subject
        if body.level is not None:
            update_data["level"] = body.level
        if body.day_of_week is not None:
            update_data["day_of_week"] = body.day_of_week
        if body.time_slot is not None:
            update_data["time_slot"] = body.time_slot

        if not update_data:
            return _serialize(group)

        updated = await group_service.update(group_id, update_data)
        return _serialize(updated)
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error updating group: {e}", exc_info=True)
        raise BadRequestException("Failed to update group")


@router.delete("/{group_id}")
async def delete_group(
    group_id: str,
    teacher: dict = Depends(get_current_teacher),
):
    try:
        group = await group_service.get_by_id(group_id)
        if not group:
            raise NotFoundException("Group not found")
        if str(group.get("teacher_id")) != str(teacher["id"]):
            raise NotFoundException("Group not found")

        deleted = await group_service.delete(group_id)
        return {"deleted": deleted}
    except NotFoundException:
        raise
    except Exception as e:
        logger.error(f"Error deleting group: {e}", exc_info=True)
        raise BadRequestException("Failed to delete group")
