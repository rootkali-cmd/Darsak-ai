from src.repositories.supabase import SupabaseRepository


class InvoiceService:
    def __init__(self):
        self.repo = SupabaseRepository("invoices")

    async def list_by_teacher(self, teacher_id, status=None, student_id=None, limit=200):
        filters = {"teacher_id": teacher_id}
        if status:
            filters["status"] = status
        if student_id:
            filters["student_id"] = student_id
        return await self.repo.select(filters, limit=limit)

    async def create(self, data):
        return await self.repo.insert(data)

    async def update(self, inv_id, data):
        return await self.repo.update({"id": inv_id}, data)

    async def delete(self, inv_id):
        return await self.repo.delete({"id": inv_id})

    async def get_stats(self, teacher_id):
        records = await self.repo.select({"teacher_id": teacher_id}, limit=10000)
        total = len(records)
        paid = sum(1 for r in records if r.get("status") == "paid")
        total_amt = sum(float(r.get("amount", 0)) for r in records)
        paid_amt = sum(float(r.get("amount", 0)) for r in records if r.get("status") == "paid")
        return {
            "total_count": total,
            "total_amount": total_amt,
            "paid_count": paid,
            "unpaid_count": total - paid,
            "paid_amount": paid_amt,
        }


invoice_service = InvoiceService()
