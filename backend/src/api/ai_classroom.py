import logging
import secrets
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Header, Query
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from src.utils.dependencies import get_current_student
from src.core.security.supabase_repo import SupabaseRepository, get_supabase
from src.core.config import get_settings

logger = logging.getLogger("darsak")

router = APIRouter(prefix="/students/me/ai-classroom", tags=["AI Classroom"])

RATE_PER_MINUTE = 0.42
MIN_BALANCE = 10.00

session_repo = SupabaseRepository("ai_lesson_sessions")
wallet_repo = SupabaseRepository("student_wallets")
tx_repo = SupabaseRepository("student_transactions")


class StartLessonRequest(BaseModel):
    classroom_url: str | None = Field(None, description="Classroom URL (optional)")
    title: str = Field(default="درس AI", description="Classroom title")


class HeartbeatResponse(BaseModel):
    ok: bool
    balance: float
    warning: bool = False
    force_end: bool = False
    message: str = ""


async def _get_wallet(student_id: str) -> dict:
    wallet = await wallet_repo.select_one({"student_id": student_id})
    if not wallet:
        wallet = await wallet_repo.insert({
            "student_id": student_id, "balance": 0.00,
            "total_deposited": 0.00, "total_spent": 0.00,
        })
    return dict(wallet)


@router.post("/start")
async def start_lesson(
    body: StartLessonRequest,
    student: dict = Depends(get_current_student),
):
    student_id = student["id"]
    wallet = await _get_wallet(student_id)
    balance = float(wallet.get("balance", 0))

    if balance < MIN_BALANCE:
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=402,
            content={"detail": f"رصيد غير كاف. الحد الأدنى {MIN_BALANCE:.2f} ج.م، رصيدك {balance:.2f} ج.م"},
        )

    now = datetime.now(timezone.utc).isoformat()
    classroom_url = body.classroom_url
    chat_token = secrets.token_urlsafe(16)
    if not classroom_url:
        classroom_url = f"https://darsak-backend.fly.dev/api/students/me/ai-classroom/chat/{chat_token}"

    session = await session_repo.insert({
        "student_id": student_id,
        "teacher_id": student.get("teacher_id"),
        "classroom_url": classroom_url,
        "title": body.title,
        "rate_per_minute": RATE_PER_MINUTE,
        "min_balance": MIN_BALANCE,
        "started_at": now,
        "heartbeat_at": now,
        "balance_before": balance,
        "status": "active",
    })
    if not body.classroom_url:
        await session_repo.update({"id": session.get("id")}, {"chat_token": chat_token})

    logger.info("AI lesson started: student=%s session=%s", student_id[:8], session.get("id"))
    return {
        "session_id": session.get("id"),
        "classroom_url": classroom_url,
        "title": body.title,
        "balance": balance,
        "rate_per_minute": RATE_PER_MINUTE,
        "min_balance": MIN_BALANCE,
    }


@router.post("/session/{session_id}/heartbeat")
async def heartbeat(
    session_id: str,
    student: dict = Depends(get_current_student),
):
    session = await session_repo.select_one({"id": session_id, "student_id": student["id"]})
    if not session:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=404, content={"detail": "الجلسة غير موجودة"})
    if session.get("status") != "active":
        return HeartbeatResponse(ok=True, balance=0, force_end=True, message="الجلسة منتهية")

    now = datetime.now(timezone.utc).isoformat()
    wallet = await _get_wallet(student["id"])
    balance = float(wallet.get("balance", 0))

    await session_repo.update({"id": session_id}, {"heartbeat_at": now})

    warning = balance < MIN_BALANCE

    return HeartbeatResponse(
        ok=True,
        balance=round(balance, 2),
        warning=warning,
        force_end=False,
        message="" if not warning else f"رصيدك {balance:.2f} ج.م، الحد الأدنى {MIN_BALANCE:.2f} ج.م",
    )


@router.post("/session/{session_id}/end")
async def end_lesson(
    session_id: str,
    student: dict = Depends(get_current_student),
):
    session = await session_repo.select_one({"id": session_id, "student_id": student["id"]})
    if not session:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=404, content={"detail": "الجلسة غير موجودة"})
    if session.get("status") != "active":
        return JSONResponse(status_code=400, content={"detail": "الجلسة منتهية بالفعل"})

    started_str = session.get("started_at")
    if not started_str:
        return JSONResponse(status_code=500, content={"detail": "وقت بدء الجلسة غير متوفر"})

    started = datetime.fromisoformat(started_str.replace("Z", "+00:00"))
    ended = datetime.now(timezone.utc)
    duration_seconds = int((ended - started).total_seconds())
    duration_minutes = max(1, round(duration_seconds / 60))
    cost = round(duration_minutes * RATE_PER_MINUTE, 2)

    wallet = await _get_wallet(student["id"])
    current_balance = float(wallet.get("balance", 0))
    current_version = int(wallet.get("version", 0))

    if current_balance < cost:
        cost = current_balance

    new_balance = round(current_balance - cost, 2)
    now_str = ended.isoformat()

    from src.services.supabase_services import get_supabase as _supabase
    client = await _supabase()
    try:
        rpc_result = client.rpc("exec_sql", {
            "query": f"""
                UPDATE student_wallets
                SET balance = balance - {cost},
                    total_spent = total_spent + {cost},
                    updated_at = '{now_str}',
                    version = version + 1
                WHERE id = '{wallet["id"]}'
                  AND version = {current_version}
                  AND balance >= {cost};
            """
        }).execute()
    except Exception:
        pass

    updated = await wallet_repo.select_one({"id": wallet["id"]})
    final_balance = float(updated.get("balance", 0))

    await tx_repo.insert({
        "student_id": student["id"],
        "wallet_id": wallet["id"],
        "transaction_type": "lesson_consumption",
        "amount": cost,
        "balance_after": final_balance,
        "reference_type": "ai_lesson_session",
        "reference_id": session_id,
        "description": f"خصم دروس AI - {cost:.2f} ج.م (المدة: {duration_seconds//60} د)",
    })

    await session_repo.update({"id": session_id}, {
        "ended_at": now_str,
        "duration_seconds": duration_seconds,
        "cost": cost,
        "balance_before": round(current_balance, 2),
        "balance_after": final_balance,
        "status": "ended",
    })

    logger.info("AI lesson ended: session=%s duration=%ds cost=%.2f", session_id, duration_seconds, cost)
    return {
        "session_id": session_id,
        "title": session.get("title", "درس AI"),
        "duration_seconds": duration_seconds,
        "duration_formatted": _fmt_duration(duration_seconds),
        "cost": cost,
        "balance_before": round(current_balance, 2),
        "balance_after": final_balance,
        "rate_per_minute": RATE_PER_MINUTE,
    }


@router.get("/sessions")
async def list_sessions(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    student: dict = Depends(get_current_student),
):
    items = await session_repo.select(
        {"student_id": student["id"]},
        limit=limit, offset=offset, order_by="created_at",
    )
    return {
        "items": [
            {
                "id": s.get("id"),
                "title": s.get("title", "درس AI"),
                "classroom_url": s.get("classroom_url", ""),
                "started_at": s.get("started_at", ""),
                "ended_at": s.get("ended_at", ""),
                "duration_seconds": s.get("duration_seconds", 0),
                "duration_formatted": _fmt_duration(s.get("duration_seconds", 0) or 0),
                "cost": float(s.get("cost", 0) or 0),
                "balance_before": float(s.get("balance_before", 0) or 0),
                "balance_after": float(s.get("balance_after", 0) or 0),
                "status": s.get("status", ""),
            }
            for s in (items or [])
        ],
        "total": len(items or []),
    }


@router.get("/config")
async def get_config():
    return {
        "rate_per_minute": RATE_PER_MINUTE,
        "min_balance": MIN_BALANCE,
        "currency": "EGP",
    }


def _fmt_duration(seconds: int) -> str:
    h, r = divmod(seconds, 3600)
    m, s = divmod(r, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


_CHAT_PAGE_HTML = """<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>الفصل الذكي</title>
<style>
*{margin:0;padding:0;box-sizing:border-box;font-family:'Segoe UI',Tahoma,sans-serif}
body{background:#f5f5f5;display:flex;flex-direction:column;height:100vh;overflow:hidden}
.header{background:linear-gradient(135deg,#6C5CE7,#a29bfe);color:#fff;padding:14px 16px;text-align:center;font-size:16px;font-weight:700;flex-shrink:0}
.chat-area{flex:1;overflow-y:auto;padding:12px 10px;display:flex;flex-direction:column;gap:8px;scroll-behavior:smooth}
.msg{max-width:80%;padding:10px 14px;border-radius:16px;font-size:14px;line-height:1.6;word-wrap:break-word;animation:fadeIn .2s ease}
.msg.user{background:#6C5CE7;color:#fff;align-self:flex-end;border-bottom-left-radius:4px}
.msg.ai{background:#fff;color:#333;align-self:flex-start;border-bottom-right-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.08)}
.msg.system{align-self:center;background:#fff3cd;color:#856404;font-size:12px;padding:6px 12px;border-radius:8px}
@keyframes fadeIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
.typing{display:flex;gap:4px;padding:12px 16px;align-self:flex-start;background:#fff;border-radius:16px;border-bottom-right-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.08)}
.typing span{width:7px;height:7px;background:#999;border-radius:50%;animation:bounce 1.4s infinite}
.typing span:nth-child(2){animation-delay:.2s}
.typing span:nth-child(3){animation-delay:.4s}
@keyframes bounce{0%,60%,100%{transform:translateY(0)}30%{transform:translateY(-6px)}}
.input-bar{display:flex;gap:8px;padding:10px 12px;background:#fff;border-top:1px solid #e0e0e0;flex-shrink:0}
.input-bar input{flex:1;padding:10px 14px;border:1px solid #ddd;border-radius:24px;outline:none;font-size:14px}
.input-bar input:focus{border-color:#6C5CE7}
.input-bar button{width:44px;height:44px;border:none;border-radius:50%;background:#6C5CE7;color:#fff;font-size:20px;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;transition:opacity .15s}
.input-bar button:disabled{opacity:.5}
.error-msg{text-align:center;color:#d32f2f;font-size:12px;padding:4px;display:none}
</style>
</head>
<body>
<div class="header">الفصل الذكي - تعليم بالذكاء الاصطناعي</div>
<div class="chat-area" id="chatArea">
  <div class="msg system">مرحباً بك في الفصل الذكي! اكتب سؤالك أو موضوعك للبدء.</div>
</div>
<div class="input-bar">
  <input type="text" id="msgInput" placeholder="اكتب رسالتك..." maxlength="1000" autofocus>
  <button id="sendBtn" onclick="send()">&#10148;</button>
</div>
<div class="error-msg" id="errorMsg"></div>
<script>
const SESSION_ID = "__SESSION_ID__";
const TOKEN = "__TOKEN__";
const API_BASE = "__API_BASE__";

let waiting = false;
const area = document.getElementById("chatArea");
const input = document.getElementById("msgInput");
const errEl = document.getElementById("errorMsg");

input.addEventListener("keydown",function(e){if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();send()}});

function addMsg(text,role){
  const div=document.createElement("div");
  div.className="msg "+role;
  div.textContent=text;
  area.appendChild(div);
  area.scrollTop=area.scrollHeight;
}

function showTyping(){
  const div=document.createElement("div");
  div.className="typing";
  div.id="typing";
  div.innerHTML="<span></span><span></span><span></span>";
  area.appendChild(div);
  area.scrollTop=area.scrollHeight;
}

function hideTyping(){
  const t=document.getElementById("typing");
  if(t)t.remove();
}

function showError(msg){
  errEl.textContent=msg;
  errEl.style.display="block";
  setTimeout(()=>{errEl.style.display="none"},5000);
}

async function send(){
  if(waiting)return;
  const text=input.value.trim();
  if(!text)return;
  input.value="";
  errEl.style.display="none";
  waiting=true;
  document.getElementById("sendBtn").disabled=true;
  addMsg(text,"user");
  showTyping();
  try{
    const res=await fetch(API_BASE+"/chat/"+SESSION_ID+"/message",{
      method:"POST",
      headers:{"Content-Type":"application/json","X-Chat-Token":TOKEN},
      body:JSON.stringify({message:text})
    });
    hideTyping();
    if(!res.ok){
      const d=await res.json().catch(()=>({}));
      showError(d.detail||"حدث خطأ في الاتصال");
      waiting=false;
      document.getElementById("sendBtn").disabled=false;
      return;
    }
    const d=await res.json();
    addMsg(d.answer,"ai");
  }catch(e){
    hideTyping();
    showError("تعذر الاتصال بالخادم");
  }
  waiting=false;
  document.getElementById("sendBtn").disabled=false;
}
</script>
</body>
</html>"""


@router.get("/chat/{chat_token}")
async def chat_page(
    chat_token: str,
):
    try:
        session = await session_repo.select_one({"chat_token": chat_token})
    except Exception as e:
        from fastapi.responses import JSONResponse
        logger.error("chat_page select_one error: %s", str(e), exc_info=True)
        return JSONResponse(status_code=500, content={"detail": f"DB error: {str(e)[:100]}"})
    
    if not session:
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=404, content={"detail": "الجلسة غير موجودة"})
    try:
        page = _CHAT_PAGE_HTML.replace("__SESSION_ID__", chat_token)
        page = page.replace("__TOKEN__", session.get("id", ""))
        page = page.replace("__API_BASE__", "https://darsak-backend.fly.dev/api/students/me/ai-classroom")
        return HTMLResponse(content=page)
    except Exception as e:
        from fastapi.responses import JSONResponse
        logger.error("chat_page render error: %s", str(e), exc_info=True)
        return JSONResponse(status_code=500, content={"detail": f"Render error: {str(e)[:100]}"})


class ChatMessageRequest(BaseModel):
    message: str


class ChatMessageResponse(BaseModel):
    answer: str


@router.post("/chat/{chat_token}/message")
async def chat_message(
    chat_token: str,
    body: ChatMessageRequest,
    x_chat_token: str = Header(""),
):
    from fastapi.responses import JSONResponse
    
    settings = get_settings()
    session = await session_repo.select_one({"chat_token": chat_token})
    if not session:
        return JSONResponse(status_code=404, content={"detail": "الجلسة غير موجودة"})
    if x_chat_token != session.get("id", ""):
        return JSONResponse(status_code=401, content={"detail": "غير مصرح"})
    if session.get("status") != "active":
        return JSONResponse(status_code=400, content={"detail": "الجلسة منتهية"})
    if not body.message.strip():
        return JSONResponse(status_code=400, content={"detail": "الرسالة فارغة"})

    import httpx
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.OPENROUTER_MODEL,
                    "messages": [
                        {"role": "system", "content": "أنت معلم مصري خبير. أجب باللغة العربية الفصحى. كن ودوداً ومفيداً. اشرح المعلومات بطريقة مبسطة تناسب الطلاب."},
                        {"role": "user", "content": body.message},
                    ],
                    "max_tokens": 2000,
                    "temperature": 0.7,
                },
            )
            data = resp.json()
            answer = data.get("choices", [{}])[0].get("message", {}).get("content", "")
            if not answer:
                answer = "عذراً، لم أتمكن من معالجة طلبك. حاول مرة أخرى."
    except Exception as e:
        from fastapi.responses import JSONResponse
        logger.error("OpenRouter chat error: %s", str(e))
        return JSONResponse(status_code=502, content={"detail": "فشل الاتصال بخدمة الذكاء الاصطناعي"})

    return ChatMessageResponse(answer=answer)
