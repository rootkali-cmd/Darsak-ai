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
        self.api_key = settings.GROQ_API_KEY or settings.OPENROUTER_API_KEY
        self.model = settings.GROQ_MODEL
        self.timeout = settings.AI_TIMEOUT
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"
        self.fallback_provider = None
        if settings.OPENROUTER_API_KEY:
            self.fallback_provider = {
                "api_key": settings.OPENROUTER_API_KEY,
                "model": settings.OPENROUTER_MODEL,
                "base_url": "https://openrouter.ai/api/v1",
            }

    async def analyze_student(
        self,
        student_name: str,
        subject: str,
        grades: list[dict],
        curriculum_context: str | None = None,
    ) -> dict[str, Any]:
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
        for provider_name, cfg in [("Groq", None), ("OpenRouter", self.fallback_provider)]:
            try:
                if provider_name == "Groq":
                    if not settings.GROQ_API_KEY:
                        continue
                    async with httpx.AsyncClient(timeout=self.timeout) as client:
                        response = await client.post(
                            "https://api.groq.com/openai/v1/chat/completions",
                            json={
                                "model": self.model,
                                "messages": messages,
                                "temperature": 0.3,
                                "response_format": {"type": "json_object"},
                            },
                            headers={
                                "Authorization": f"Bearer {settings.GROQ_API_KEY}",
                                "Content-Type": "application/json",
                            },
                        )
                        response.raise_for_status()
                        result = response.json()
                        content = result["choices"][0]["message"]["content"]
                        return json.loads(content)
                elif provider_name == "OpenRouter" and cfg:
                    headers = {
                        "Authorization": f"Bearer {cfg['api_key']}",
                        "Content-Type": "application/json",
                        "HTTP-Referer": "https://darsak-ai.vercel.app",
                        "X-Title": "DarsakAI",
                    }
                    async with httpx.AsyncClient(timeout=self.timeout) as client:
                        response = await client.post(
                            f"{cfg['base_url']}/chat/completions",
                            json={
                                "model": cfg["model"],
                                "messages": messages,
                                "temperature": 0.3,
                                "max_tokens": 4096,
                                "response_format": {"type": "json_object"},
                            },
                            headers=headers,
                        )
                        response.raise_for_status()
                        result = response.json()
                        content = result["choices"][0]["message"]["content"]
                        return json.loads(content)
            except httpx.HTTPStatusError as e:
                logger.warning("%s API error: %s", provider_name, e.response.status_code)
            except Exception as e:
                logger.warning("%s API failed: %s", provider_name, str(e))
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
