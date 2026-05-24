from fastapi import APIRouter

router = APIRouter(prefix="/versions", tags=["Versions"])

VERSIONS = {
    "mobile": {
        "version": "1.0.2",
        "build": 4,
        "apk_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Student.apk",
        "size_mb": 72,
        "changes_ar": "توقيع APK رسمي، إصلاح QR code، تحسين PIN، إضافة الاشتراكات",
        "changes_en": "Official APK signing, QR fix, PIN improvements, subscriptions",
        "force_update": False,
    },
    "desktop": {
        "version": "1.1.37",
        "build": 37,
        "download_url": "https://github.com/rootkali-cmd/Darsak-ai/releases/download/v1.0.0/DarsakAI-Setup.exe",
        "size_mb": 14,
        "changes_ar": "إصلاح مشكلة تعيين PIN للطلاب، تحديث تلقائي",
        "changes_en": "Fix student PIN setting issue, auto-update improvements",
        "force_update": False,
    },
    "accounts": {
        "version": "1.0.0",
        "build": 1,
        "download_url": None,
        "size_mb": None,
        "changes_ar": "الإصدار الأول",
        "changes_en": "Initial release",
        "force_update": False,
    },
}


@router.get("/")
async def get_versions():
    return VERSIONS


@router.get("/{platform}")
async def get_version(platform: str):
    return VERSIONS.get(platform, {"error": "Unknown platform"})
