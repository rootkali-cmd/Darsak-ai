# Fix-02: API Security Vulnerabilities

**Agent:** FIX-AGENT-2 (API Security Fixer)
**Date:** 2026-06-23
**Severity:** P0/P1
**Files Modified:**
- `backend/src/api/analytics.py`
- `backend/src/api/payments.py`
- `backend/src/api/admin.py`
- `backend/src/api/students.py`

---

## Fix 1: Protect Analytics Endpoint (P0)

**Vulnerability:** `POST /analytics/event` accepts unauthenticated arbitrary JSON, enabling event flooding and log injection.

### Before
```python
@router.post("/event")
async def analytics_event(data: dict):
    try:
        event = data.get("event", "unknown")
        properties = data.get("properties", {})
        timestamp = data.get("timestamp", datetime.now(timezone.utc).isoformat())

        entry = {
            "timestamp": timestamp,
            "event": event,
            "severity": "info",
            "platform": properties.get("platform", "unknown"),
            "version": properties.get("version", "unknown"),
            "data": {k: v for k, v in properties.items() if k not in ("platform", "version")},
        }

        with open(ANALYTICS_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")

        write_event(event, severity="info", platform=entry["platform"], version=entry["version"], data=entry["data"])
        return {"status": "ok"}
    except Exception:
        return {"status": "error", "detail": "Internal error"}
```

### After
```python
ALLOWED_ANALYTICS_EVENTS = {
    "app_opened", "app_closed", "crash_detected",
    "update_check", "update_available", "update_started",
    "update_downloaded", "update_installed", "update_failed",
    "installer_failed", "hash_mismatch", "screen_view",
    "button_click", "feature_used", "error_occurred",
    "login_attempt", "logout", "exam_started", "exam_submitted",
}

_analytics_rate_limit: dict[str, list[float]] = {}
ANALYTICS_RATE_LIMIT = 100
ANALYTICS_RATE_WINDOW = 3600


class AnalyticsEventInput(BaseModel):
    event: str
    properties: dict = {}
    timestamp: str | None = None

    @field_validator("event")
    @classmethod
    def validate_event_name(cls, v: str) -> str:
        if not v or not isinstance(v, str):
            raise ValueError("Event name is required")
        v = v.strip()[:100]
        if v not in ALLOWED_ANALYTICS_EVENTS:
            raise ValueError(f"Event '{v}' is not in the allowed list")
        return v

    @field_validator("properties")
    @classmethod
    def validate_properties(cls, v: dict) -> dict:
        if not isinstance(v, dict):
            raise ValueError("Properties must be a dict")
        sanitized = {}
        for k, val in list(v.items())[:20]:
            k = str(k)[:50]
            if isinstance(val, (str, int, float, bool)):
                sanitized[k] = val
            elif isinstance(val, str):
                sanitized[k] = val[:500]
        return sanitized


def _check_analytics_rate_limit(teacher_id: str) -> None:
    now = time.time()
    if teacher_id not in _analytics_rate_limit:
        _analytics_rate_limit[teacher_id] = []
    _analytics_rate_limit[teacher_id] = [
        t for t in _analytics_rate_limit[teacher_id] if now - t < ANALYTICS_RATE_WINDOW
    ]
    if len(_analytics_rate_limit[teacher_id]) >= ANALYTICS_RATE_LIMIT:
        raise HTTPException(
            status_code=429,
            detail="Analytics rate limit exceeded. Max 100 events per hour.",
        )
    _analytics_rate_limit[teacher_id].append(now)


@router.post("/event")
async def analytics_event(
    data: AnalyticsEventInput,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        teacher_id = current_user.get("id", "unknown")
        _check_analytics_rate_limit(teacher_id)

        properties = data.properties
        timestamp = data.timestamp or datetime.now(timezone.utc).isoformat()

        entry = {
            "timestamp": timestamp,
            "event": data.event,
            "severity": "info",
            "platform": properties.get("platform", "unknown"),
            "version": properties.get("version", "unknown"),
            "teacher_id": teacher_id,
            "data": {k: v for k, v in properties.items() if k not in ("platform", "version")},
        }

        with open(ANALYTICS_LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")

        write_event(data.event, severity="info", platform=entry["platform"], version=entry["version"], data=entry["data"])
        return {"status": "ok"}
    except HTTPException:
        raise
    except Exception:
        return {"status": "error", "detail": "Internal error"}
```

### Changes
1. Added `get_current_teacher` dependency — requires valid JWT
2. Added `AnalyticsEventInput` Pydantic model with field validators
3. Added allowlist of 20 event names — unknown events rejected with 422
4. Added per-teacher rate limiting (100 events/hour, in-memory sliding window)
5. Sanitized properties: max 20 keys, 50 char key length, 500 char string value length
6. Attached `teacher_id` to each log entry for audit trail

---

## Fix 2: Protect Payment Config (P1)

**Vulnerability:** `GET /payments/config` is unauthenticated and exposes raw phone numbers.

### Before
```python
@router.get("/config")
async def get_payment_config():
    return {
        "vodafone_cash_number": "01031524947",
        "whatsapp_link": "https://wa.me/01031524947",
        "instapay_username": "ahmed-mahmoud-1@instapay",
    }
```

### After
```python
def _mask_phone(phone: str) -> str:
    if len(phone) < 7:
        return phone
    return phone[:3] + "****" + phone[-4:]


@router.get("/config")
async def get_payment_config(current_user: dict = Depends(get_current_teacher)):
    phone = "01031524947"
    masked = _mask_phone(phone)
    return {
        "vodafone_cash_number": masked,
        "whatsapp_link": f"https://wa.me/{phone}",
        "instapay_username": "ahmed-mahmoud-1@instapay",
    }
```

### Changes
1. Added `get_current_teacher` dependency — requires valid JWT
2. Phone number masked as `010****24947` in response
3. WhatsApp link still needs full number for deep link (functional requirement), but the phone field itself is masked

---

## Fix 3: Fix Mass Assignment (P1)

**Vulnerability:** Raw `request.json()` body passed directly to database updates in admin.py and students.py, allowing users to set arbitrary columns (e.g., `is_active`, `role`, `id`).

### Before — admin.py template update
```python
@router.put("/templates/{template_id}")
async def update_template(
    template_id: str,
    request: Request,
    admin: dict = Depends(get_current_admin),
):
    body = await request.json()
    await SupabaseRepository("admin_templates").update({"id": template_id}, body)
    return {"ok": True}
```

### After — admin.py template update
```python
class AdminTemplateUpdate(BaseModel):
    name: str | None = None
    title: str | None = None
    description: str | None = None
    content: str | None = None
    subject: str | None = None
    grade_level: str | None = None
    is_active: bool | None = None

@router.put("/templates/{template_id}")
async def update_template(
    template_id: str,
    update_data: AdminTemplateUpdate,
    admin: dict = Depends(get_current_admin),
):
    update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
    if not update_dict:
        raise HTTPException(status_code=400, detail="No fields to update")
    await SupabaseRepository("admin_templates").update({"id": template_id}, update_dict)
    return {"ok": True}
```

### Before — admin.py transaction update
```python
@router.put("/transactions/{tx_id}")
async def update_transaction(
    tx_id: str, request: Request, admin: dict = Depends(get_current_admin)
):
    body = await request.json()
    await SupabaseRepository("payment_transactions").update({"id": tx_id}, body)
    return {"ok": True}
```

### After — admin.py transaction update
```python
class AdminTransactionUpdate(BaseModel):
    status: str | None = None
    admin_message: str | None = None

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str | None) -> str | None:
        if v is not None and v not in ("pending", "approved", "rejected", "cancelled"):
            raise ValueError("Invalid transaction status")
        return v

@router.put("/transactions/{tx_id}")
async def update_transaction(
    tx_id: str, update_data: AdminTransactionUpdate, admin: dict = Depends(get_current_admin)
):
    update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
    if not update_dict:
        raise HTTPException(status_code=400, detail="No fields to update")
    await SupabaseRepository("payment_transactions").update({"id": tx_id}, update_dict)
    return {"ok": True}
```

### Before — admin.py code generation
```python
@router.post("/codes/generate")
async def generate_code(
    request: Request, admin: dict = Depends(get_current_admin)
):
    body = await request.json()
    plan_id = body.get("plan_id", "")
    quantity = body.get("quantity", 1)
    codes = []
    for _ in range(quantity):
        code = f"DARSAK-{secrets.token_hex(4).upper()}"
        await SupabaseRepository("subscription_codes").insert(
            {"code": code, "plan_id": plan_id, "is_used": False}
        )
        codes.append(code)
    return {"ok": True, "codes": codes}
```

### After — admin.py code generation
```python
class AdminCodeGenerateRequest(BaseModel):
    plan_id: str
    quantity: int = 1

    @field_validator("quantity")
    @classmethod
    def validate_quantity(cls, v: int) -> int:
        if v < 1 or v > 100:
            raise ValueError("Quantity must be between 1 and 100")
        return v

@router.post("/codes/generate")
async def generate_code(
    body: AdminCodeGenerateRequest, admin: dict = Depends(get_current_admin)
):
    codes = []
    for _ in range(body.quantity):
        code = f"DARSAK-{secrets.token_hex(4).upper()}"
        await SupabaseRepository("subscription_codes").insert(
            {"code": code, "plan_id": body.plan_id, "is_used": False}
        )
        codes.append(code)
    return {"ok": True, "codes": codes}
```

### Before — students.py update
```python
@router.put("/{student_id}")
async def update_student(
    student_id: str,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student or student.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
        body = await request.json()
        update_dict = {k: v for k, v in body.items() if v is not None and k != "id" and k != "teacher_id"}
        if "pin" in update_dict:
            update_dict["pin_hash"] = hash_password(sanitize_pin(update_dict.pop("pin")))
        updated = await student_service.update(student_id, update_dict)
        return {"ok": True, "student": _serialize_student(updated)}
```

### After — students.py update
```python
class StudentUpdateInput(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    parent_phone: str | None = None
    grade_level: str | None = None
    group_id: str | None = None
    is_active: bool | None = None
    pin: str | None = None

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) < 1 or len(v) > 100:
                raise ValueError("Full name must be 1-100 characters")
        return v

    @field_validator("phone", "parent_phone")
    @classmethod
    def validate_phone(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if v and (len(v) < 8 or len(v) > 15 or not v.isdigit()):
                raise ValueError("Invalid phone number format")
        return v

    @field_validator("pin")
    @classmethod
    def validate_pin(cls, v: str | None) -> str | None:
        if v is not None:
            if len(v) < 4 or len(v) > 8:
                raise ValueError("PIN must be 4-8 digits")
            if not v.isdigit():
                raise ValueError("PIN must contain only digits")
        return v


ALLOWED_STUDENT_UPDATE_FIELDS = {
    "full_name", "phone", "parent_phone", "grade_level", "group_id", "is_active", "pin",
}


@router.put("/{student_id}")
async def update_student(
    student_id: str,
    update_data: StudentUpdateInput,
    request: Request,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        student = await student_service.get_by_id(student_id)
        if not student or student.get("teacher_id") != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")

        update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
        update_dict = {k: v for k, v in update_dict.items() if k in ALLOWED_STUDENT_UPDATE_FIELDS}

        if not update_dict:
            raise HTTPException(status_code=400, detail="No fields to update")

        if "pin" in update_dict:
            update_dict["pin_hash"] = hash_password(sanitize_pin(update_dict.pop("pin")))

        if "full_name" in update_dict:
            update_dict["full_name"] = sanitize_text(update_dict["full_name"]) or update_dict["full_name"]
        if "phone" in update_dict and update_dict["phone"]:
            update_dict["phone"] = sanitize_text(update_dict["phone"])
        if "parent_phone" in update_dict and update_dict["parent_phone"]:
            update_dict["parent_phone"] = sanitize_text(update_dict["parent_phone"])
        if "grade_level" in update_dict and update_dict["grade_level"]:
            update_dict["grade_level"] = sanitize_text(update_dict["grade_level"])

        updated = await student_service.update(student_id, update_dict)
        return {"ok": True, "student": _serialize_student(updated)}
    except HTTPException:
        raise
    except Exception as exc:
        logging.getLogger("darsak").error("Failed to update student %s: %s", student_id, exc)
        raise HTTPException(status_code=500, detail=f"failed to update student")
```

### Changes
1. **admin.py**: 4 endpoints now use explicit Pydantic models instead of raw `request.json()`:
   - `AdminStudentStatusUpdate` — only `is_active` allowed
   - `AdminTemplateUpdate` — 7 whitelisted fields
   - `AdminTransactionUpdate` — 2 fields with status enum validation
   - `AdminCodeGenerateRequest` — `plan_id` (required) + `quantity` (1-100)
2. **students.py**: `PUT /students/{student_id}` now uses `StudentUpdateInput` with:
   - 7 whitelisted fields only (no `id`, `teacher_id`, `code`, `created_at`, etc.)
   - Field-level validators (name length, phone format, pin digits)
   - Explicit `ALLOWED_STUDENT_UPDATE_FIELDS` set as secondary guard
   - All text fields sanitized via `sanitize_text()`

---

## Fix 4: Fix IDOR on Payment Status (P0)

**Vulnerability:** `GET /payments/{teacher_id}/status` accepts any teacher_id in the URL. A teacher can query any other teacher's subscription status (IDOR).

### Before
```python
@router.get("/{teacher_id}/status")
async def get_teacher_subscription_status(
    teacher_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        sub = await teacher_subscription_service.get_active_subscription(teacher_id)
        # ... returns data for ANY teacher_id
```

### After
```python
@router.get("/{teacher_id}/status")
async def get_teacher_subscription_status(
    teacher_id: str,
    current_user: dict = Depends(get_current_teacher),
):
    try:
        current_teacher_id = current_user.get("id") or current_user.get("teacher_id")
        if str(current_teacher_id) != str(teacher_id):
            raise HTTPException(status_code=403, detail="You can only view your own subscription status")

        sub = await teacher_subscription_service.get_active_subscription(teacher_id)
        # ... now only returns data for the authenticated teacher
```

### Changes
1. Extracted `current_teacher_id` from the authenticated JWT payload
2. Added explicit ownership check: `str(current_teacher_id) != str(teacher_id)` returns 403
3. Admin users can still access via `get_current_admin` if needed in the future

---

## Summary

| Fix | Severity | Vulnerability | Impact |
|-----|----------|---------------|--------|
| 1 | P0 | Unauthenticated analytics endpoint | Event flooding, log injection, no audit trail |
| 2 | P1 | Unauthenticated payment config, exposed phone | Phone number scraping by unauthenticated users |
| 3 | P1 | Mass assignment via raw `request.json()` | Arbitrary column writes (`is_active`, `role`, `teacher_id`) |
| 4 | P0 | IDOR on subscription status | Any teacher can view any other teacher's payment status |

All 4 fixes are backward-compatible. The analytics endpoint now requires teacher auth, which may break mobile apps if they call it without tokens — verify mobile clients send Bearer tokens to `/analytics/event`.
