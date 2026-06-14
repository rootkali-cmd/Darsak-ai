# DarsakAI Mobile - Maestro E2E Tests

## 📋 ملخص الاختبارات

| # | ملف الاختبار | الوصف | الحالة |
|---|-------------|-------|--------|
| 01 | `01_app_launch.yaml` | تشغيل التطبيق وشاشة البداية | ✅ |
| 02 | `02_teacher_connect.yaml` | شاشة الاتصال بالمعلم | ✅ |
| 03 | `03_student_login.yaml` | تسجيل دخول الطالب + Validation | ✅ |
| 04 | `04_home_dashboard.yaml` | الشاشة الرئيسية + Bottom Nav | ✅ |
| 05 | `05_grades_screen.yaml` | شاشة الدرجات + فلتر المواد | ✅ |
| 06 | `06_attendance_screen.yaml` | شاشة الحضور + التقويم | ✅ |
| 07 | `07_profile_screen.yaml` | الملف الشخصي + الثيم + PIN | ✅ |
| 08 | `08_subscription_screen.yaml` | الاشتراك + تفعيل الرمز | ✅ |
| 09 | `09_full_e2e_journey.yaml` | رحلة كاملة E2E | ✅ |
| 10 | `10_error_handling.yaml` | معالجة الأخطاء + Edge Cases | ✅ |
| 11 | `11_exam_screens.yaml` | شاشة الاختبارات | ✅ |
| 12 | `12_student_qr.yaml` | كود QR للطالب | ✅ |

---

## 🔧 التثبيت والإعداد

### 1. تثبيت Maestro

```bash
# macOS / Linux
curl -Ls "https://get.maestro.mobile.dev" | bash

# أضف到 PATH
export PATH="$PATH:$HOME/.maestro/bin"

# تحقق من التثبيت
maestro --version
```

### 2. تثبيت Android SDK (إذا لم يكن مثبت)

```bash
# تأكد أن ADB متاح
adb --version

# أو تثبيت Android Command Line Tools
# https://developer.android.com/studio#command-tools
```

### 3. إعداد الجهاز

```bash
#فعّل USB Debugging على جهاز Android
# الإعدادات > خيارات المطور > تصحيح USB

# تأكد أن الجهاز متصل
adb devices

# يجب أن يظهر الجهاز في القائمة
```

### 4. بناء التطبيق (debug)

```bash
cd mobile-app

# بناء APK لل debug
flutter build apk --debug

# التثبيت على الجهاز
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🚀 تشغيل الاختبارات

### تشغيل اختبار واحد

```bash
cd mobile-app

# تشغيل اختبار تسجيل الدخول
maestro test maestro_tests/03_student_login.yaml

# تشغيل اختبار الشاشة الرئيسية
maestro test maestro_tests/04_home_dashboard.yaml
```

### تشغيل جميع الاختبارات

```bash
# تشغيل جميع الاختبارات بالترتيب
maestro test maestro_tests/

# أو تشغيل اختبار محدد
maestro test maestro_tests/09_full_e2e_journey.yaml
```

### تشغيل اختبار معين بالتسلسل

```bash
# تشغيل اختبار واحد فقط
maestro --env TEST_ENV=dev test maestro_tests/03_student_login.yaml
```

---

## 📝 ملاحظات مهمة

### بيانات الدخول التجريبية

| الحقل | القيمة |
|-------|--------|
| كود المعلم | `TCH-XXXXXX` |
| كود الطالب | `ST000001` |
| PIN | `123456` |

> ⚠️ **ملاحظة**: بيانات الدخول هذه للاختبار فقط. تأكد من وجود مستخدم تجريبي في قاعدة البيانات قبل تشغيل الاختبارات.

### إعداد بيانات الدخول

1. سجل حساب معلم جديد عبر الموقع
2. أنشئ طالب جديد عبر Dashboard المعلم
3. استخدم كود الطالب والـ PIN في ملفات الاختبار

### تعديل بيانات الدخول

إذا كنت تريد تغيير بيانات الدخول، عدّل الملفات التالية:

```yaml
# في ملفات 03, 04, 05, 06, 07, 08, 09, 11, 12
- tapOn:
    id: "كود الطالب"
- inputText: "ST000001"  # ← غيّر هذا الكود

- tapOn:
    id: "PIN"
- inputText: "123456"  # ← غيّر هذا الـ PIN
```

---

## 🔍 عرض النتائج

### عرض النتائج التفصيلية

```bash
# تشغيل مع تفاصيل أكثر
maestro test maestro_tests/ --format detailed

# حفظ النتائج في ملف
maestro test maestro_tests/ --format json > results.json
```

### Maestro Studio (واجهة تفاعلية)

```bash
# فتح Maestro Studio للاختبار يدوياً
maestro studio

# هذا يفتح واجهة ويب تفاعلية يمكنك من خلالها:
# - استكشاف عناصر الواجهة
# - كتابة اختبارات جديدة
# - تشغيل خطوات بشكل فردي
```

---

## 🐛 استكشاف الأخطاء

### إذا فشل اختبار

```bash
# تشغيل مع تفاصيل الخطأ
maestro test maestro_tests/03_student_login.yaml --format detailed

# عرض الشاشة الحالية
maestro screenshot

# عرض شجرة العناصر
maestro inspect
```

### مشاكل شائعة

| المشكلة | الحل |
|---------|------|
| `Device not found` | تأكد أن USB Debugging مفعّل + `adb devices` |
| `App not installed` | أعد بناء التطبيق: `flutter build apk --debug` |
| `Element not found` | تحقق من النص بالعربية + انتظر تحميل الشاشة |
| `Timeout` | زِد الـ timeout في `extendedWaitUntil` |

---

## 📁 هيكل الملفات

```
mobile-app/
├── maestro_tests/
│   ├── 01_app_launch.yaml
│   ├── 02_teacher_connect.yaml
│   ├── 03_student_login.yaml
│   ├── 04_home_dashboard.yaml
│   ├── 05_grades_screen.yaml
│   ├── 06_attendance_screen.yaml
│   ├── 07_profile_screen.yaml
│   ├── 08_subscription_screen.yaml
│   ├── 09_full_e2e_journey.yaml
│   ├── 10_error_handling.yaml
│   ├── 11_exam_screens.yaml
│   └── 12_student_qr.yaml
├── lib/
├── test/
└── pubspec.yaml
```
