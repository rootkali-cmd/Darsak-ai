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
        self.api_key = settings.OPENROUTER_API_KEY or settings.GROQ_API_KEY
        self.model = settings.OPENROUTER_MODEL
        self.base_url = "https://openrouter.ai/api/v1/chat/completions"
        self.timeout = settings.AI_TIMEOUT
        self.fallback_provider = None
        if settings.GROQ_API_KEY:
            self.fallback_provider = {
                "api_key": settings.GROQ_API_KEY,
                "model": settings.GROQ_MODEL,
                "base_url": "https://api.groq.com/openai/v1",
            }

    async def _check_ai_limit(self, teacher_id: str) -> None:
        from src.services import teacher_subscription_service, subscription_plan_service
        sub = await teacher_subscription_service.get_active_subscription(teacher_id)
        if not sub:
            return
        plan_name = sub.get("plan_name", "")
        if not plan_name:
            plan = await subscription_plan_service.get_by_id(sub.get("plan_id", ""))
            if not plan:
                return
            plan_name = plan.get("name", "")
        limit = await subscription_plan_service.get_plan_ai_limit(plan_name)
        if limit <= 0:
            return
        count = await subscription_plan_service.get_teacher_ai_usage_this_month(teacher_id)
        if count >= limit:
            raise Exception(f"وصلت للحد الأقصى لاستخدام AI هذا الشهر ({limit} طلب). انتظر الشهر القادم أو قم بالترقية.")

    async def analyze_student(
        self,
        student_name: str,
        subject: str,
        grades: list[dict],
        curriculum_context: str | None = None,
        teacher_id: str | None = None,
    ) -> dict[str, Any]:
        if teacher_id:
            await self._check_ai_limit(teacher_id)

        if not self.api_key:
            logger.warning("No AI API key set, using fallback analysis")
            return self._fallback_analysis(subject, grades)

        grade_summary = json.dumps(grades, ensure_ascii=False, indent=2)
        curriculum = f"\nسياق المنهج: {curriculum_context}" if curriculum_context else ""

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"حلل أداء الطالب التالي:\n\nالطالب: {student_name}\nالمادة: {subject}\nالدرجات:\n{grade_summary}{curriculum}\n\nقدم التقرير بصيغة JSON فقط.",
            },
        ]

        result = await self._call_with_fallback(messages)
        if result:
            return result
        return self._fallback_analysis(subject, grades)

    async def _call_with_fallback(self, messages: list) -> dict | None:
        providers = [("OpenRouter", self.base_url, self.api_key, self.model)]
        if self.fallback_provider:
            providers.append(("Groq", self.fallback_provider["base_url"] + "/chat/completions", self.fallback_provider["api_key"], self.fallback_provider["model"]))
        
        for provider_name, url, key, model in providers:
            try:
                if not key:
                    continue
                headers = {
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                }
                if provider_name == "OpenRouter":
                    headers["HTTP-Referer"] = "https://darsak-ai.vercel.app"
                    headers["X-Title"] = "DarsakAI"
                
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(
                        url,
                        json={
                            "model": model,
                            "messages": messages,
                            "temperature": 0.3,
                            "response_format": {"type": "json_object"},
                        },
                        headers=headers,
                    )
                    response.raise_for_status()
                    result = response.json()
                    content = result["choices"][0]["message"]["content"]
                    return json.loads(content)
            except Exception as e:
                logger.warning("AI provider %s failed: %s", provider_name, e)
                continue
        return None

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
