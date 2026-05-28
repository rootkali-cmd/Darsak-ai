"""
DarsakAI Restore Tool
Usage:
  python scripts/restore.py list-backups
  python scripts/restore.py restore <backup_id> [--target-db URL]
  python scripts/restore.py verify <backup_id>
  python scripts/restore.py validate-schema [--target-db URL]
"""

import argparse
import asyncio
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).parent.parent))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("restore")

BACKUP_DIR = Path(os.environ.get("DARSAKAI_BACKUP_DIR", "/var/backups/darsakai"))


def _get_pg_url() -> str:
    url = os.environ.get("DATABASE_URL_SYNC") or os.environ.get("DATABASE_URL", "")
    if not url:
        raise RuntimeError("DATABASE_URL_SYNC or DATABASE_URL must be set")
    return url


def _decrypt_file(path: Path, output_path: Path) -> Path:
    key = os.environ.get("DARSAKAI_BACKUP_KEY", "").encode()
    if not key:
        raise RuntimeError("DARSAKAI_BACKUP_KEY required for decryption")
    try:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        import hashlib

        aesgcm = AESGCM(hashlib.sha256(key).digest())
        data = path.read_bytes()
        nonce, ciphertext = data[:12], data[12:]
        plaintext = aesgcm.decrypt(nonce, ciphertext, None)
        output_path.write_bytes(plaintext)
        logger.info("Decrypted: %s", path.name)
        return output_path
    except ImportError:
        raise RuntimeError("cryptography package required for decryption")


async def validate_schema(target_db: Optional[str] = None) -> dict:
    """Validate that target DB has all required tables and columns."""
    pg_url = target_db or _get_pg_url()
    required_tables = [
        "users", "students", "groups", "attendances", "grades",
        "invoices", "encrypted_payloads", "audit_logs",
        "subscription_plans", "teacher_subscriptions", "exams",
        "questions", "student_exams", "student_answers", "exam_results",
        "sync_cursors", "dead_letter_queue", "processed_operations",
        "payment_requests", "notifications",
    ]
    results = {"present": [], "missing": [], "errors": []}

    for table in required_tables:
        try:
            result = subprocess.run(
                ["psql", pg_url, "-t", "-c",
                 f"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '{table}')"],
                capture_output=True, text=True, timeout=10,
            )
            if "t" in result.stdout.strip():
                results["present"].append(table)
            else:
                results["missing"].append(table)
        except Exception as e:
            results["errors"].append(f"{table}: {e}")

    status = "ok" if not results["missing"] else "incomplete" if not results["errors"] else "error"
    results["status"] = status
    logger.info("Schema validation: %d present, %d missing, %d errors",
                len(results["present"]), len(results["missing"]), len(results["errors"]))
    return results


async def restore_backup(backup_id: str, target_db: Optional[str] = None, dry_run: bool = False) -> dict:
    """Restore a backup with pre-validation."""
    backup_dir = BACKUP_DIR / backup_id
    if not backup_dir.exists():
        return {"status": "error", "message": f"Backup {backup_id} not found at {backup_dir}"}

    meta_path = backup_dir / "backup.json"
    if not meta_path.exists():
        return {"status": "error", "message": "No backup.json in backup directory"}

    metadata = json.loads(meta_path.read_text())
    pg_url = target_db or _get_pg_url()
    steps = []

    # Step 1: Validate schema
    logger.info("Step 1: Validating target schema...")
    schema = await validate_schema(pg_url)
    steps.append({"step": "schema_validation", "status": schema["status"]})

    if schema["status"] == "error":
        return {"status": "aborted", "message": "Schema validation failed", "steps": steps}

    if dry_run:
        return {"status": "dry_run", "message": "Skipping actual restore", "steps": steps}

    # Step 2: Drop existing data
    if target_db:
        logger.info("Step 2: Dropping existing data in target...")
        try:
            subprocess.run(
                ["psql", pg_url, "-c",
                 "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"],
                capture_output=True, text=True, timeout=60,
            )
            steps.append({"step": "drop_data", "status": "ok"})
        except Exception as e:
            steps.append({"step": "drop_data", "status": "error", "error": str(e)})

    # Step 3: Restore from backup
    logger.info("Step 3: Restoring from backup...")
    for fname in metadata.get("files", []):
        fpath = backup_dir / fname
        if not fpath.exists():
            steps.append({"step": f"restore_{fname}", "status": "skipped", "reason": "file not found"})
            continue

        try:
            # Decrypt if needed
            if fname.endswith(".enc"):
                decrypted = backup_dir / fname.replace(".enc", "")
                _decrypt_file(fpath, decrypted)
                fpath = decrypted

            if "darsakai_pg" in fname and not fname.endswith(".enc"):
                ext = fpath.suffix
                if ext == ".sql" or ext == ".dump":
                    logger.info("  Restoring %s...", fname)
                    result = subprocess.run(
                        ["pg_restore", "--no-owner", "--no-acl", "--clean", "--if-exists",
                         "-d", pg_url, "-v", str(fpath)],
                        capture_output=True, text=True, timeout=600,
                    )
                    if result.returncode != 0:
                        logger.warning("  Warnings: %s", result.stderr[:300])
                    steps.append({
                        "step": f"restore_{fname}",
                        "status": "completed",
                        "warnings": result.stderr[:300] if result.stderr else None,
                    })

            # Cleanup decrypted files
            if fpath != backup_dir / fname and fpath.exists():
                fpath.unlink()

        except Exception as e:
            steps.append({"step": f"restore_{fname}", "status": "error", "error": str(e)})

    # Step 4: Post-restore verification
    logger.info("Step 4: Verifying restored data...")
    try:
        result = subprocess.run(
            ["psql", pg_url, "-t", "-c",
             "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'"],
            capture_output=True, text=True, timeout=10,
        )
        table_count = result.stdout.strip()
        steps.append({"step": "post_restore_verify", "tables": table_count, "status": "ok"})
    except Exception as e:
        steps.append({"step": "post_restore_verify", "status": "error", "error": str(e)})

    return {
        "status": "completed",
        "backup_id": backup_id,
        "target": pg_url.split("@")[-1] if "@" in pg_url else pg_url,
        "steps": steps,
    }


def simulate_corruption(backup_id: str) -> str:
    """Simulate backup corruption for disaster recovery testing."""
    backup_dir = BACKUP_DIR / backup_id
    if not backup_dir.exists():
        return "Backup not found"

    import random
    corrupted = []
    for f in backup_dir.glob("*"):
        if f.is_file() and f.suffix not in (".json",):
            data = bytearray(f.read_bytes())
            if len(data) > 0:
                idx = random.randint(0, len(data) - 1)
                data[idx] ^= 0xFF
                f.write_bytes(bytes(data))
                corrupted.append(f.name)
    return f"Corrupted {len(corrupted)} files: {', '.join(corrupted)}"


def main():
    parser = argparse.ArgumentParser(description="DarsakAI Restore & Recovery Tool")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list-backups", help="List available backups")

    restore_p = sub.add_parser("restore", help="Restore a backup")
    restore_p.add_argument("backup_id", help="Backup ID")
    restore_p.add_argument("--target-db", help="Target database URL")
    restore_p.add_argument("--dry-run", action="store_true", help="Validate only, don't restore")

    verify_p = sub.add_parser("verify", help="Verify backup integrity")
    verify_p.add_argument("backup_id", help="Backup ID")

    validate_p = sub.add_parser("validate-schema", help="Validate target DB schema")
    validate_p.add_argument("--target-db", help="Database URL to validate")

    corrupt_p = sub.add_parser("simulate-corruption", help="Corrupt backup for DR testing")
    corrupt_p.add_argument("backup_id", help="Backup ID to corrupt")

    args = parser.parse_args()

    if args.command == "list-backups":
        if not BACKUP_DIR.exists():
            print("No backups found")
            return
        backups = sorted([d.name for d in BACKUP_DIR.iterdir() if d.is_dir() and d.name.startswith(("full_", "pg_"))])
        for b in backups:
            meta = BACKUP_DIR / b / "backup.json"
            if meta.exists():
                info = json.loads(meta.read_text())
                size = info.get("size_bytes", 0)
                print(f"  {b:<30} {info.get('type','?'):<10} {size/1e6:.1f} MB")
            else:
                print(f"  {b:<30} {'unknown':<10}")

    elif args.command == "restore":
        result = asyncio.run(restore_backup(args.backup_id, args.target_db, args.dry_run))
        print(json.dumps(result, indent=2, default=str))

    elif args.command == "verify":
        from backup_manager import verify_backup
        result = asyncio.run(verify_backup(args.backup_id))
        print(json.dumps(result, indent=2, default=str))

    elif args.command == "validate-schema":
        result = asyncio.run(validate_schema(args.target_db))
        print(json.dumps(result, indent=2, default=str))

    elif args.command == "simulate-corruption":
        msg = simulate_corruption(args.backup_id)
        print(msg)


if __name__ == "__main__":
    main()
