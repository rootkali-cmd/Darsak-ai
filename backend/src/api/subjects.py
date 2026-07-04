from fastapi import APIRouter, Depends
from src.utils.dependencies import get_current_teacher

router = APIRouter(prefix="/subjects", tags=["Subjects"])


@router.get("")
async def get_my_subjects(current_user: dict = Depends(get_current_teacher)):
    subjects = current_user.get("subjects") or []
    return {"subjects": subjects}


@router.get("/levels")
async def get_my_levels(current_user: dict = Depends(get_current_teacher)):
    levels = current_user.get("levels") or []
    return {"levels": levels}
