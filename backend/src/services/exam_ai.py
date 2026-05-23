import json
import logging
import base64
from typing import Any

import httpx

from src.core.config import get_settings

logger = logging.getLogger("darsak")
settings = get_settings()

try:
    import fitz
    HAS_PDF_SUPPORT = True
except ImportError:
    HAS_PDF_SUPPORT = False
    logger.warning("PyMuPDF not installed; PDF text extraction disabled")

QUESTION_GEN_PROMPT = """أنت معلم خبير في المناهج التعليمية المصرية. مهمتك تحويل محتوى دراسي إلى أسئلة امتحان.

المطلوب:
1. تحليل النص أو الصورة المقدمة
2. استخراج أهم المعلومات
3. توليد 5-10 أسئلة متنوعة (اختيار متعدد + مقالي)
4. توفير نموذج إجابة كامل لكل سؤال

القواعد:
- أخرج JSON صالح فقط بدون أي نص إضافي
- استخدم اللغة العربية في الأسئلة والإجابات
- تنوع الأسئلة بين المستويات (فهم، تطبيق، تحليل)
- كل سؤال اختيار متعدد必须有 4 خيارات (أ، ب، ج، د)

الصيغة المطلوبة:
{
  "title": "عنوان الامتحان المقترح",
  "description": "وصف الامتحان",
  "questions": [
    {
      "type": "multiple_choice",
      "question_text": "نص السؤال",
      "options": [
        {"key": "أ", "text": "الخيار الأول"},
        {"key": "ب", "text": "الخيار الثاني"},
        {"key": "ج", "text": "الخيار الثالث"},
        {"key": "د", "text": "الخيار الرابع"}
      ],
      "correct_answer": "أ",
      "points": 5,
      "page_number": 1
    },
    {
      "type": "essay",
      "question_text": "نص السؤال المقالي",
      "correct_answer": "الإجابة النموذجية",
      "points": 10,
      "page_number": 1
    }
  ]
}"""

ANALYSIS_PROMPT = """أنت محلل تعليمي خبير. حلل أداء الطالب في الامتحان التالي:

بيانات الامتحان:
{exam_data}

إجابات الطالب:
{student_answers}

المطلوب:
1. تحليل نقاط القوة والضعف
2. تقديم توصيات للتحسين
3. اقتراح تمارين إضافية

أخرج JSON صالح فقط بهذا التنسيق:
{{
  "strengths": ["نقطة قوة 1", "نقطة قوة 2"],
  "weaknesses": ["نقطة ضعف 1", "نقطة ضعف 2"],
  "recommendations": ["توصية 1", "توصية 2"],
  "overall_assessment": "تقييم عام"
}}"""


class AIProvider:
    def __init__(self, name: str, api_key: str, base_url: str, model: str, vision_model: str, priority: int):
        self.name = name
        self.api_key = api_key
        self.base_url = base_url
        self.model = model
        self.vision_model = vision_model
        self.priority = priority

    async def call(self, messages: list, use_vision: bool = False, json_mode: bool = True) -> dict[str, Any] | None:
        if not self.api_key:
            return None
        model = self.vision_model if use_vision else self.model
        payload = {
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 4096,
        }
        if json_mode:
            payload["response_format"] = {"type": "json_object"}

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        if "openrouter" in self.base_url:
            headers["HTTP-Referer"] = "https://darsak-ai.vercel.app"
            headers["X-Title"] = "DarsakAI"

        try:
            async with httpx.AsyncClient(timeout=settings.AI_TIMEOUT) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                return json.loads(content)
        except httpx.HTTPStatusError as e:
            logger.warning("%s API error %s: %s", self.name, e.response.status_code, e.response.text[:200])
            return None
        except Exception as e:
            logger.warning("%s API call failed: %s", self.name, str(e))
            return None


class ExamAIService:
    def __init__(self):
        self.providers: list[AIProvider] = []
        if settings.OPENROUTER_API_KEY:
            self.providers.append(AIProvider(
                name="OpenRouter",
                api_key=settings.OPENROUTER_API_KEY,
                base_url="https://openrouter.ai/api/v1",
                model=settings.OPENROUTER_MODEL,
                vision_model=settings.OPENROUTER_VISION_MODEL,
                priority=0,
            ))
            logger.info("OpenRouter AI enabled (model=%s, vision=%s)", settings.OPENROUTER_MODEL, settings.OPENROUTER_VISION_MODEL)
        if settings.GROQ_API_KEY:
            self.providers.append(AIProvider(
                name="Groq",
                api_key=settings.GROQ_API_KEY,
                base_url="https://api.groq.com/openai/v1",
                model=settings.GROQ_MODEL,
                vision_model="llama-3.2-90b-vision-preview",
                priority=1,
            ))
            logger.info("Groq AI enabled (model=%s)", settings.GROQ_MODEL)
        if not self.providers:
            logger.warning("No AI provider configured! Set OPENROUTER_API_KEY or GROQ_API_KEY")

    async def _call_best(self, messages: list, use_vision: bool = False) -> dict[str, Any]:
        for provider in self.providers:
            result = await provider.call(messages, use_vision=use_vision)
            if result is not None:
                logger.info("AI call succeeded via %s", provider.name)
                return result
            logger.warning("%s failed, trying next provider...", provider.name)
        logger.error("All AI providers failed, using fallback")
        return self._fallback_questions()

    async def extract_text_from_pdf(self, pdf_bytes: bytes) -> str:
        if not HAS_PDF_SUPPORT:
            return ""
        try:
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
            text = ""
            for page in doc:
                text += page.get_text() + "\n"
            doc.close()
            return text.strip()
        except Exception as e:
            logger.error("PDF text extraction failed: %s", e)
            return ""

    def _image_to_base64(self, image_bytes: bytes) -> str:
        return base64.b64encode(image_bytes).decode("utf-8")

    async def generate_questions_from_text(self, text: str, subject: str | None = None) -> dict[str, Any]:
        if not text.strip():
            return self._fallback_questions()
        subject_ctx = f"\nالمادة: {subject}" if subject else ""
        messages = [
            {"role": "system", "content": QUESTION_GEN_PROMPT},
            {
                "role": "user",
                "content": f"قم بتحليل المحتوى التالي وتوليد أسئلة امتحان منه:{subject_ctx}\n\n{text[:12000]}",
            },
        ]
        return await self._call_best(messages)

    async def generate_questions_from_image(self, image_bytes: bytes, subject: str | None = None) -> dict[str, Any]:
        b64 = self._image_to_base64(image_bytes)
        subject_ctx = f"\nالمادة: {subject}" if subject else ""
        fmt = 'أخرج JSON صالح فقط بهذا التنسيق:\n{"title":"عنوان","description":"وصف","questions":[{"type":"multiple_choice","question_text":"نص","options":[{"key":"أ","text":"..."}],"correct_answer":"أ","points":5,"page_number":1}]}'
        messages = [
            {"role": "system", "content": QUESTION_GEN_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": f"قم بتحليل الصورة التعليمية التالية وتوليد أسئلة امتحان منها.{subject_ctx}\n\n{fmt}"},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                ],
            },
        ]
        return await self._call_best(messages, use_vision=True)

    async def generate_questions_from_pdf(self, pdf_bytes: bytes, subject: str | None = None) -> dict[str, Any]:
        text = await self.extract_text_from_pdf(pdf_bytes)
        if text:
            return await self.generate_questions_from_text(text, subject)
        return await self.generate_questions_from_image(pdf_bytes, subject)

    async def analyze_student_exam(
        self,
        exam_title: str,
        questions: list[dict],
        student_answers: list[dict],
        total_score: float,
        max_score: float,
    ) -> dict[str, Any]:
        exam_data = json.dumps({
            "title": exam_title,
            "questions": questions,
            "total_score": total_score,
            "max_score": max_score,
        }, ensure_ascii=False, indent=2)
        answers_data = json.dumps(student_answers, ensure_ascii=False, indent=2)
        messages = [
            {"role": "system", "content": ANALYSIS_PROMPT.format(
                exam_data=exam_data,
                student_answers=answers_data,
            )},
        ]
        return await self._call_best(messages)

    def _fallback_questions(self) -> dict[str, Any]:
        return {
            "title": "امتحان تجريبي",
            "description": "تم توليد أسئلة افتراضية (تعذر الاتصال بالذكاء الاصطناعي)",
            "questions": [
                {
                    "type": "multiple_choice",
                    "question_text": "ما عاصمة مصر؟",
                    "options": [
                        {"key": "أ", "text": "القاهرة"},
                        {"key": "ب", "text": "الإسكندرية"},
                        {"key": "ج", "text": "الجيزة"},
                        {"key": "د", "text": "الأقصر"},
                    ],
                    "correct_answer": "أ",
                    "points": 5,
                    "page_number": 1,
                },
                {
                    "type": "essay",
                    "question_text": "اكتب فقرة عن أهمية نهر النيل لمصر.",
                    "correct_answer": "نهر النيل هو شريان الحياة لمصر، يوفر المياه للشرب والزراعة والصناعة.",
                    "points": 10,
                    "page_number": 1,
                },
            ],
        }

    def _fallback_analysis(self) -> dict[str, Any]:
        return {
            "strengths": ["لم يتوفر تحليل AI"],
            "weaknesses": ["لم يتوفر تحليل AI"],
            "recommendations": ["تواصل مع مدرسك للحصول على تقييم"],
            "overall_assessment": "يرجى المحاولة مرة أخرى لاحقاً",
        }


exam_ai_service = ExamAIService()
