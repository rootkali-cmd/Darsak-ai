import io
import logging
from datetime import datetime
from uuid import UUID

logger = logging.getLogger("darsak")

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import cm
    from reportlab.lib.enums import TA_CENTER, TA_RIGHT
    HAS_REPORTLAB = True
except ImportError:
    HAS_REPORTLAB = False
    logger.warning("reportlab not installed; PDF generation disabled")


class PDFGenerator:
    @staticmethod
    def generate_student_report(
        student_name: str,
        student_code: str,
        subject: str,
        ai_report: dict,
        grades: list[dict],
        teacher_name: str,
    ) -> bytes:
        if not HAS_REPORTLAB:
            raise RuntimeError("PDF generation unavailable: reportlab not installed")
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            rightMargin=2 * cm,
            leftMargin=2 * cm,
            topMargin=2 * cm,
            bottomMargin=2 * cm,
        )

        styles = getSampleStyleSheet()
        styles.add(ParagraphStyle(
            name="ArabicTitle",
            fontSize=18,
            textColor=colors.HexColor("#8B5CF6"),
            alignment=TA_CENTER,
            spaceAfter=10,
        ))
        styles.add(ParagraphStyle(
            name="SectionHeader",
            fontSize=14,
            textColor=colors.HexColor("#1E293B"),
            spaceBefore=15,
            spaceAfter=8,
        ))

        elements = []

        elements.append(Paragraph("DarsakAI - تقرير الطالب", styles["ArabicTitle"]))
        elements.append(Spacer(1, 10))

        info_data = [
            ["اسم الطالب:", student_name],
            ["كود الطالب:", student_code],
            ["المادة:", subject],
            ["المدرس:", teacher_name],
            ["التاريخ:", datetime.now().strftime("%Y-%m-%d")],
        ]
        info_table = Table(info_data, colWidths=[4 * cm, 10 * cm])
        info_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#F1F5F9")),
            ("TEXTCOLOR", (0, 0), (-1, -1), colors.HexColor("#1E293B")),
            ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]))
        elements.append(info_table)
        elements.append(Spacer(1, 20))

        elements.append(Paragraph("نقاط القوة", styles["SectionHeader"]))
        for item in ai_report.get("strengths", []):
            elements.append(Paragraph(f"• {item}", styles["Normal"]))

        elements.append(Paragraph("نقاط الضعف", styles["SectionHeader"]))
        for item in ai_report.get("weaknesses", []):
            elements.append(Paragraph(f"• {item}", styles["Normal"]))

        elements.append(Paragraph("التوصيات", styles["SectionHeader"]))
        for item in ai_report.get("recommended_focus", []):
            elements.append(Paragraph(f"• {item}", styles["Normal"]))

        elements.append(Paragraph("التمرين المقترح", styles["SectionHeader"]))
        elements.append(Paragraph(ai_report.get("next_exercise_suggestion", ""), styles["Normal"]))

        if grades:
            elements.append(PageBreak())
            elements.append(Paragraph("سجل الدرجات", styles["SectionHeader"]))
            grade_data = [["الامتحان", "الدرجة", "من", "النسبة"]]
            for g in grades:
                pct = (g.get("score", 0) / g.get("max_score", 100)) * 100
                grade_data.append([
                    g.get("exam_name", ""),
                    str(g.get("score", 0)),
                    str(g.get("max_score", 100)),
                    f"{pct:.1f}%",
                ])
            grade_table = Table(grade_data, colWidths=[5*cm, 2.5*cm, 2.5*cm, 3*cm])
            grade_table.setStyle(TableStyle([
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#8B5CF6")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F8FAFC")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("ALIGN", (1, 1), (-1, -1), "CENTER"),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]))
            elements.append(grade_table)

        doc.build(elements)
        buffer.seek(0)
        return buffer.getvalue()


pdf_generator = PDFGenerator()
