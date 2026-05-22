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
        self.api_key = settings.GROQ_API_KEY
        self.model = settings.GROQ_MODEL
        self.timeout = settings.AI_TIMEOUT
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"

    async def analyze_student(
        self,
        student_name: str,
        subject: str,
        grades: list[dict],
        curriculum_context: str | None = None,
    ) -> dict[str, Any]:
        if not self.api_key:
            logger.warning("GROQ_API_KEY not set, using fallback analysis")
            return self._fallback_analysis(subject, grades)

        grade_summary = json.dumps(grades, ensure_ascii=False, indent=2)
        curriculum = f"\nسياق المنهج: {curriculum_context}" if curriculum_context else ""

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"""حلل أداء الطالب التالي:

الطالب: {student_name}
المادة: {subject}
الدرجات:
{grade_summary}{curriculum}

قدم التقرير بصيغة JSON فقط.""",
            },
        ]

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.api_url,
                    json={
                        "model": self.model,
                        "messages": messages,
                        "temperature": 0.3,
                        "response_format": {"type": "json_object"},
                    },
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                )
                response.raise_for_status()
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                return json.loads(content)

        except httpx.HTTPStatusError as e:
            logger.error("Groq API error: %s - %s", e.response.status_code, e.response.text)
            return self._fallback_analysis(subject, grades)
        except Exception as e:
            logger.error("AI analysis failed: %s", str(e))
            return self._fallback_analysis(subject, grades)

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
