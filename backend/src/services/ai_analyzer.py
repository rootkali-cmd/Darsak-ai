import json
import httpx
import logging
from typing import Any

from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()

SYSTEM_PROMPT = """أنت محلل تعليمي ذكي متخصص في منهج وزارة التربية والتعليم.
مهمتك تحليل درجات الطالب وتقديم تقرير مفصل بصيغة JSON فقط.

القواعد:
1. أخرج JSON صالح فقط بدون أي نص إضافي
2. استخدم اللغة العربية في المحتوى
3. كن محدداً وعملياً في التوصيات

الصيغة المطلوبة:
{
  "strengths": ["نقطة قوة 1", "نقطة قوة 2"],
  "weaknesses": ["نقطة ضعف 1", "نقطة ضعف 2"],
  "recommended_focus": ["موضوع للتركيز 1", "موضوع للتركيز 2"],
  "next_exercise_suggestion": "تمرين مقترح مفصل"
}"""


class AIAnalyzer:
    def __init__(self):
        self.base_url = settings.OLLAMA_BASE_URL
        self.model = settings.OLLAMA_MODEL
        self.timeout = settings.AI_TIMEOUT

    async def analyze_student(
        self,
        student_name: str,
        subject: str,
        grades: list[dict],
        curriculum_context: str | None = None,
    ) -> dict[str, Any]:
        grade_summary = json.dumps(grades, ensure_ascii=False, indent=2)

        user_prompt = f"""حلل أداء الطالب التالي:

الطالب: {student_name}
المادة: {subject}
الدرجات:
{grade_summary}

{f"سياق المنهج: {curriculum_context}" if curriculum_context else ""}

قدم التقرير بصيغة JSON فقط."""

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/api/generate",
                    json={
                        "model": self.model,
                        "prompt": user_prompt,
                        "system": SYSTEM_PROMPT,
                        "stream": False,
                        "format": {
                            "type": "object",
                            "properties": {
                                "strengths": {"type": "array", "items": {"type": "string"}},
                                "weaknesses": {"type": "array", "items": {"type": "string"}},
                                "recommended_focus": {"type": "array", "items": {"type": "string"}},
                                "next_exercise_suggestion": {"type": "string"},
                            },
                            "required": ["strengths", "weaknesses", "recommended_focus", "next_exercise_suggestion"],
                        },
                    },
                )
                response.raise_for_status()
                result = response.json()
                raw_output = result.get("response", "")

                parsed = self._parse_json_output(raw_output)
                return parsed

        except httpx.ConnectError:
            logger.error("Cannot connect to Ollama at %s", self.base_url)
            return self._fallback_analysis(subject, grades)
        except Exception as e:
            logger.error("AI analysis failed: %s", str(e))
            return self._fallback_analysis(subject, grades)

    def _parse_json_output(self, raw: str) -> dict[str, Any]:
        raw = raw.strip()
        if raw.startswith("```"):
            lines = raw.split("\n")
            json_lines = []
            in_json = False
            for line in lines:
                if line.strip().startswith("```json") or line.strip() == "```":
                    in_json = not in_json if line.strip().startswith("```") else True
                    continue
                if in_json or (not line.strip().startswith("```")):
                    json_lines.append(line)
            raw = "\n".join(json_lines).strip()

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            start = raw.find("{")
            end = raw.rfind("}") + 1
            if start >= 0 and end > start:
                return json.loads(raw[start:end])
            raise

    def _fallback_analysis(self, subject: str, grades: list[dict]) -> dict[str, Any]:
        if not grades:
            return {
                "strengths": ["لم تتوفر بيانات كافية"],
                "weaknesses": ["لم تتوفر بيانات كافية"],
                "recommended_focus": ["يرجى إضافة درجات أكثر للتحليل"],
                "next_exercise_suggestion": "لا يوجد اقتراح حالياً",
            }

        scores = [g.get("score", 0) for g in grades]
        avg = sum(scores) / len(scores) if scores else 0

        strengths = []
        weaknesses = []
        for g in grades:
            pct = (g.get("score", 0) / g.get("max_score", 100)) * 100
            if pct >= 85:
                strengths.append(f"أداء ممتاز في {g.get('exam', 'اختبار')}")
            elif pct < 50:
                weaknesses.append(f"يحتاج تحسين في {g.get('exam', 'اختبار')}")

        return {
            "strengths": strengths or ["يحتاج المزيد من البيانات"],
            "weaknesses": weaknesses or ["لا توجد نقاط ضعف واضحة"],
            "recommended_focus": [f"تحسين الأداء في مادة {subject}"],
            "next_exercise_suggestion": f"متوسط الدرجات: {avg:.1f}%. راجع الأسئلة التي أخطأت فيها.",
        }


ai_analyzer = AIAnalyzer()
