import io
import base64
import qrcode
from uuid import UUID


class QRService:
    @staticmethod
    def generate_qr_base64(data: str, size: int = 300) -> str:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        img = img.resize((size, size))
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")

    @staticmethod
    def generate_teacher_qr(teacher_id: UUID, teacher_code: str) -> str:
        payload = teacher_code
        return QRService.generate_qr_base64(payload)


qr_service = QRService()
