import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

logger = logging.getLogger("darsak")

from src.utils.dependencies import get_current_teacher

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/students/{teacher_id}")
async def get_student_reports(
    teacher_id: str,
    subject: Optional[str] = Query(None),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_teacher),
):
    if current_user["id"] != teacher_id:
        raise HTTPException(status_code=403, detail="Access denied")

    try:
        from src.core.security.supabase_repo import get_supabase

        client = await get_supabase()

        # Fetch students for this teacher
        students_res = await (
            client.table("students")
            .select("id, full_name, code")
            .eq("teacher_id", teacher_id)
            .execute()
        )
        students = students_res.data or []
        if not students:
            return {"students": [], "summary": {"total_students": 0, "average_score": 0, "pass_rate": 0}}

        student_ids = [s["id"] for s in students]

        # Fetch student_exams (without join — PostgREST join syntax not supported by Python client)
        se_res = await (
            client.table("student_exams")
            .select("id, student_id, exam_id, total_score, max_score, status, submitted_at")
            .in_("student_id", student_ids)
            .eq("status", "graded")
            .execute()
        )
        student_exams = se_res.data or []

        # Fetch exams separately for title lookup
        exam_ids = list({se["exam_id"] for se in student_exams if se.get("exam_id")})
        exam_map = {}
        if exam_ids:
            try:
                ex_res = await (
                    client.table("exams")
                    .select("id, title")
                    .in_("id", exam_ids)
                    .execute()
                )
                for ex in (ex_res.data or []):
                    exam_map[ex["id"]] = ex
            except Exception:
                pass

        # Apply filters
        filtered = []
        for se in student_exams:
            exam = exam_map.get(se.get("exam_id"))
            if not exam:
                continue

            submitted = se.get("submitted_at")
            if date_from and submitted:
                if isinstance(submitted, str):
                    submitted_dt = datetime.fromisoformat(submitted.replace("Z", "+00:00"))
                else:
                    submitted_dt = submitted
                from_dt = datetime.fromisoformat(date_from)
                if submitted_dt.replace(tzinfo=None) < from_dt:
                    continue

            if date_to and submitted:
                if isinstance(submitted, str):
                    submitted_dt = datetime.fromisoformat(submitted.replace("Z", "+00:00"))
                else:
                    submitted_dt = submitted
                to_dt = datetime.fromisoformat(date_to)
                if submitted_dt.replace(tzinfo=None) > to_dt:
                    continue

            filtered.append(se)

        # Fetch exam_results (AI analysis) for these student exams
        student_exam_ids = [se["id"] for se in student_exams]
        exam_results_map = {}
        if student_exam_ids:
            try:
                er_res = await (
                    client.table("exam_results")
                    .select("student_exam_id, total_score, max_score, correct_count, wrong_count, strengths, weaknesses, recommendations")
                    .in_("student_exam_id", student_exam_ids)
                    .execute()
                )
                for er in (er_res.data or []):
                    exam_results_map[er["student_exam_id"]] = er
            except Exception:
                pass

        # Group by student
        student_map = {s["id"]: s for s in students}
        students_data = {}
        for se in filtered:
            sid = se["student_id"]
            if sid not in students_data:
                student_map_entry = student_map.get(sid, {})
                students_data[sid] = {
                    "student_id": sid,
                    "name": student_map_entry.get("full_name", "طالب"),
                    "code": student_map_entry.get("code", ""),
                    "exams": [],
                    "total_score": 0,
                    "max_score": 0,
                    "all_strengths": [],
                    "all_weaknesses": [],
                    "all_recommendations": [],
                }
            total_score = se.get("total_score") or 0
            max_score = se.get("max_score") or 0
            se_id = se.get("id")
            exam_result = exam_results_map.get(se_id, {})
            
            exam_entry = {
                "exam_id": se.get("exam_id"),
                "student_exam_id": se_id,
                "score": total_score,
                "max_score": max_score,
                "percentage": round((total_score / max_score * 100) if max_score > 0 else 0, 1),
            }
            
            if exam_result:
                strengths = exam_result.get("strengths", "")
                weaknesses = exam_result.get("weaknesses", "")
                recommendations = exam_result.get("recommendations", "")
                exam_entry["strengths"] = strengths.split("\n") if strengths else []
                exam_entry["weaknesses"] = weaknesses.split("\n") if weaknesses else []
                exam_entry["recommendations"] = recommendations.split("\n") if recommendations else []
                
                for s in exam_entry["strengths"]:
                    if s.strip() and s.strip() not in students_data[sid]["all_strengths"]:
                        students_data[sid]["all_strengths"].append(s.strip())
                for w in exam_entry["weaknesses"]:
                    if w.strip() and w.strip() not in students_data[sid]["all_weaknesses"]:
                        students_data[sid]["all_weaknesses"].append(w.strip())
                for r in exam_entry["recommendations"]:
                    if r.strip() and r.strip() not in students_data[sid]["all_recommendations"]:
                        students_data[sid]["all_recommendations"].append(r.strip())
            
            students_data[sid]["exams"].append(exam_entry)
            students_data[sid]["total_score"] += float(total_score)
            students_data[sid]["max_score"] += float(max_score)

        # Calculate averages and sort
        result_list = []
        for sid, data in students_data.items():
            avg = (data["total_score"] / data["max_score"] * 100) if data["max_score"] > 0 else 0
            result_list.append({
                "student_id": sid,
                "name": data["name"],
                "code": data["code"],
                "average_score": round(avg, 1),
                "exams_count": len(data["exams"]),
                "exams": data["exams"],
                "strengths": data["all_strengths"],
                "weaknesses": data["all_weaknesses"],
                "recommendations": data["all_recommendations"],
            })

        result_list.sort(key=lambda x: x["average_score"], reverse=True)

        # Summary stats
        total_students = len(result_list)
        avg_score = round(sum(r["average_score"] for r in result_list) / total_students, 1) if total_students > 0 else 0
        pass_count = sum(1 for r in result_list if r["average_score"] >= 50)
        pass_rate = round((pass_count / total_students * 100) if total_students > 0 else 0, 1)

        # AI-style analysis text
        if total_students == 0:
            analysis = "لا توجد بيانات كافية للتحليل."
        elif avg_score >= 80:
            analysis = f"أداء ممتاز للفصل بمعدل {avg_score}%. معظم الطلاب يحققون نتائج مميزة."
        elif avg_score >= 60:
            analysis = f"أداء جيد للفصل بمعدل {avg_score}%. هناك نسبة {100 - pass_rate}% من الطلاب بحاجة لدعم إضافي."
        else:
            analysis = f"معدل الفصل {avg_score}%. يحتاج الفصل لاهتمام أكبر مع {100 - pass_rate}% من الطلاب بمستوى منخفض."

        return {
            "students": result_list,
            "summary": {
                "total_students": total_students,
                "average_score": avg_score,
                "pass_rate": pass_rate,
                "analysis": analysis,
            },
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get student reports: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get reports: {str(exc)}")


@router.get("/analytics/{teacher_id}")
async def get_analytics_summary(
    teacher_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    if current_user["id"] != teacher_id:
        raise HTTPException(status_code=403, detail="Access denied")

    try:
        from src.core.security.supabase_repo import get_supabase

        client = await get_supabase()

        students_res = await (
            client.table("students")
            .select("id, full_name")
            .eq("teacher_id", teacher_id)
            .execute()
        )
        students = students_res.data or []
        total_students = len(students)

        if students:
            try:
                se_res = await (
                    client.table("student_exams")
                    .select("id, student_id, total_score, max_score, status")
                    .in_("student_id", [s["id"] for s in students])
                    .execute()
                )
                student_exams = se_res.data or []
            except Exception as se_err:
                logger.warning("student_exams query failed (table may not exist): %s", se_err)
                student_exams = []
        else:
            student_exams = []

        graded = [se for se in student_exams if se.get("status") == "graded"]

        total_exams = len(graded)
        if total_exams > 0:
            avg_score = round(sum((se.get("total_score") or 0) / (se.get("max_score") or 1) * 100 for se in graded) / total_exams, 1)
            pass_count = sum(1 for se in graded if ((se.get("total_score") or 0) / (se.get("max_score") or 1) * 100) >= 50)
            pass_rate = round(pass_count / total_exams * 100, 1)
        else:
            avg_score = 0
            pass_rate = 0

        return {
            "total_students": total_students,
            "total_graded_exams": total_exams,
            "average_score": avg_score,
            "pass_rate": pass_rate,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get analytics: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to get analytics: {str(exc)}")
