import json
import logging
import base64
import io
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
3. توليد أسئلة متنوعة (اختيار متعدد + مقالي)
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


class ExamAIService:
    def __init__(self):
        self.api_key = settings.GROQ_API_KEY
        self.model = "llama-3.2-90b-vision-preview"
        self.fast_model = settings.GROQ_MODEL
        self.timeout = settings.AI_TIMEOUT if hasattr(settings, 'AI_TIMEOUT') else 60
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"

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
                "content": f"""قم بتحليل المحتوى التالي وتوليد أسئلة امتحان منه:{subject_ctx}

{text[:8000]}""",
            },
        ]

        return await self._call_groq(messages)

    async def generate_questions_from_image(self, image_bytes: bytes, subject: str | None = None) -> dict[str, Any]:
        b64 = self._image_to_base64(image_bytes)
        subject_ctx = f"\nالمادة: {subject}" if subject else ""
        messages = [
            {"role": "system", "content": QUESTION_GEN_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": f"قم بتحليل الصورة التعليمية التالية وتوليد أسئلة امتحان منها.{subject_ctx}\n\nأخرج JSON صالح فقط بهذا التنسيق:\n{{\n  \"title\": \"عنوان الامتحان\",\n  \"description\": \"وصف\",\n  \"questions\": [\n    {{\n      \"type\": \"multiple_choice\",\n      \"question_text\": \"نص السؤال\",\n      \"options\": [{{\"key\": \"أ\", \"text\": \"...\"}}],\n      \"correct_answer\": \"أ\",\n      \"points\": 5,\n      \"page_number\": 1\n    }}\n  ]\n}}"},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                ],
            },
        ]

        return await self._call_groq(messages, use_vision=True)

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
        if not self.api_key:
            return self._fallback_analysis()

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

        return await self._call_groq(messages)

    async def _call_groq(self, messages: list, use_vision: bool = False) -> dict[str, Any]:
        if not self.api_key:
            logger.warning("GROQ_API_KEY not set, using fallback")
            return self._fallback_questions()

        model = self.model if use_vision else self.fast_model
        payload = {
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "response_format": {"type": "json_object"},
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.api_url,
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                )
                response.raise_for_status()
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                data = json.loads(content)
                return data
        except httpx.HTTPStatusError as e:
            logger.error("Groq API error: %s - %s", e.response.status_code, e.response.text)
            return self._fallback_questions()
        except Exception as e:
            logger.error("AI call failed: %s", str(e))
            return self._fallback_questions()

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
