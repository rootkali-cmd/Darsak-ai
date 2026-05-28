"""
Database Integrity Reporter
Scans Supabase tables for orphan records, null violations, and constraint issues.
Usage: python scripts/integrity_reporter.py
"""
import asyncio
import sys
sys.path.insert(0, "/home/ahmed/Documents/DarsakAi/backend")

from src.core.config import get_settings
from src.core.security.supabase_client import get_supabase

settings = get_settings()


class IntegrityReporter:
    def __init__(self):
        self.issues = []
        self.total_checked = 0

    async def run(self):
        print("=" * 60)
        print("DarsakAI Database Integrity Report")
        print("=" * 60)

        client = await get_supabase()

        await self._check_table_count(client, "users", "Users")
        await self._check_table_count(client, "students", "Students")
        await self._check_table_count(client, "groups", "Groups")
        await self._check_table_count(client, "attendances", "Attendance Records")
        await self._check_table_count(client, "grades", "Grades")
        await self._check_table_count(client, "invoices", "Invoices")
        await self._check_table_count(client, "encrypted_payloads", "Encrypted Payloads")
        await self._check_table_count(client, "audit_logs", "Audit Logs")

        print("\n" + "-" * 40)
        print("Integrity Checks")
        print("-" * 40)

        await self._check_orphan_students(client)
        await self._check_orphan_attendance(client)
        await self._check_orphan_grades(client)
        await self._check_orphan_invoices(client)
        await self._check_orphan_groups(client)
        await self._check_negative_scores(client)
        await self._check_negative_amounts(client)
        await self._check_null_required_fields(client)
        await self._check_duplicate_student_codes(client)
        await self._check_duplicate_attendance(client)

        print("\n" + "-" * 40)
        print(f"Summary: {len(self.issues)} issues found across {self.total_checked} checks")
        print("-" * 40)

        if self.issues:
            for issue in self.issues:
                print(f"  [{issue['severity']}] {issue['message']}")
                if issue.get("count", 0) > 0:
                    print(f"       Count: {issue['count']}")
                if issue.get("sample"):
                    print(f"       Sample: {issue['sample']}")
        else:
            print("  No issues found. Database integrity looks good!")

        return self.issues

    async def _check_table_count(self, client, table: str, label: str):
        try:
            result = await client.table(table).select("id", count="exact").execute()
            count = result.count if hasattr(result, "count") else len(result.data)
            print(f"  {label}: {count} records")
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Cannot access table {table}: {e}", "count": 0})

    async def _check_orphan_students(self, client):
        try:
            result = await client.table("students").select("id, teacher_id").execute()
            students = result.data or []
            orphan_count = 0
            for s in students:
                user_result = await client.table("users").select("id").eq("id", s["teacher_id"]).execute()
                if not user_result.data:
                    orphan_count += 1
            if orphan_count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Students referencing non-existent teachers",
                    "count": orphan_count,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Orphan student check failed: {e}", "count": 0})

    async def _check_orphan_attendance(self, client):
        try:
            result = await client.table("attendances").select("id, student_id").execute()
            records = result.data or []
            orphan_count = 0
            for r in records:
                student_result = await client.table("students").select("id").eq("id", r["student_id"]).execute()
                if not student_result.data:
                    orphan_count += 1
            if orphan_count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Attendance records referencing non-existent students",
                    "count": orphan_count,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Orphan attendance check failed: {e}", "count": 0})

    async def _check_orphan_grades(self, client):
        try:
            result = await client.table("grades").select("id, student_id").execute()
            records = result.data or []
            orphan_count = 0
            for r in records:
                student_result = await client.table("students").select("id").eq("id", r["student_id"]).execute()
                if not student_result.data:
                    orphan_count += 1
            if orphan_count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Grades referencing non-existent students",
                    "count": orphan_count,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Orphan grades check failed: {e}", "count": 0})

    async def _check_orphan_invoices(self, client):
        try:
            result = await client.table("invoices").select("id, student_id").execute()
            records = result.data or []
            orphan_count = 0
            for r in records:
                student_result = await client.table("students").select("id").eq("id", r["student_id"]).execute()
                if not student_result.data:
                    orphan_count += 1
            if orphan_count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Invoices referencing non-existent students",
                    "count": orphan_count,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Orphan invoices check failed: {e}", "count": 0})

    async def _check_orphan_groups(self, client):
        try:
            result = await client.table("groups").select("id, teacher_id").execute()
            records = result.data or []
            orphan_count = 0
            for r in records:
                user_result = await client.table("users").select("id").eq("id", r["teacher_id"]).execute()
                if not user_result.data:
                    orphan_count += 1
            if orphan_count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Groups referencing non-existent teachers",
                    "count": orphan_count,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Orphan groups check failed: {e}", "count": 0})

    async def _check_negative_scores(self, client):
        try:
            result = await client.table("grades").select("id, score, max_score").lt("score", 0).execute()
            count = len(result.data or [])
            if count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Grades with negative scores",
                    "count": count,
                    "sample": result.data[0] if result.data else None,
                })
            result2 = await client.table("grades").select("id, score, max_score").lt("max_score", 1).execute()
            count2 = len(result2.data or [])
            if count2 > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Grades with invalid max_score (<= 0)",
                    "count": count2,
                })
            result3 = await client.table("grades").select("id, score, max_score").gt("score", 0).execute()
            over_max = 0
            for r in (result3.data or []):
                if r.get("max_score", 100) > 0 and r.get("score", 0) > r.get("max_score", 100):
                    over_max += 1
            if over_max > 0:
                self.issues.append({
                    "severity": "MEDIUM",
                    "message": f"Grades where score exceeds max_score",
                    "count": over_max,
                })
            self.total_checked += 3
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Score validation failed: {e}", "count": 0})

    async def _check_negative_amounts(self, client):
        try:
            result = await client.table("invoices").select("id, amount").lt("amount", 0).execute()
            count = len(result.data or [])
            if count > 0:
                self.issues.append({
                    "severity": "HIGH",
                    "message": f"Invoices with negative amounts",
                    "count": count,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Amount validation failed: {e}", "count": 0})

    async def _check_null_required_fields(self, client):
        checks = [
            ("students", ["full_name", "code"]),
            ("groups", ["name", "subject", "level"]),
            ("attendances", ["status", "date"]),
            ("grades", ["exam_name", "score"]),
            ("invoices", ["amount"]),
        ]
        for table, fields in checks:
            for field in fields:
                try:
                    result = await client.table(table).select("id").is_(field, "null").execute()
                    count = len(result.data or [])
                    if count > 0:
                        self.issues.append({
                            "severity": "MEDIUM",
                            "message": f"{table}: {count} records with NULL {field}",
                            "count": count,
                        })
                    self.total_checked += 1
                except Exception as e:
                    self.issues.append({"severity": "WARN", "message": f"NULL check {table}.{field} failed: {e}", "count": 0})

    async def _check_duplicate_student_codes(self, client):
        try:
            result = await client.table("students").select("code, teacher_id").execute()
            records = result.data or []
            seen = {}
            duplicates = 0
            for r in records:
                key = f"{r.get('teacher_id', '')}:{r.get('code', '')}"
                if key in seen:
                    duplicates += 1
                seen[key] = True
            if duplicates > 0:
                self.issues.append({
                    "severity": "MEDIUM",
                    "message": f"Duplicate student codes within same teacher",
                    "count": duplicates,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Duplicate check failed: {e}", "count": 0})

    async def _check_duplicate_attendance(self, client):
        try:
            result = await client.table("attendances").select("student_id, date").execute()
            records = result.data or []
            seen = {}
            duplicates = 0
            for r in records:
                key = f"{r.get('student_id', '')}:{r.get('date', '')}"
                if key in seen:
                    duplicates += 1
                seen[key] = True
            if duplicates > 0:
                self.issues.append({
                    "severity": "MEDIUM",
                    "message": f"Duplicate attendance records (same student, same date)",
                    "count": duplicates,
                })
            self.total_checked += 1
        except Exception as e:
            self.issues.append({"severity": "WARN", "message": f"Duplicate attendance check failed: {e}", "count": 0})


async def main():
    reporter = IntegrityReporter()
    await reporter.run()


if __name__ == "__main__":
    asyncio.run(main())
