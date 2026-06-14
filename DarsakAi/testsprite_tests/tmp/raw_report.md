
# TestSprite AI Testing Report(MCP)

---

## 1️⃣ Document Metadata
- **Project Name:** Darsak-ai
- **Date:** 2026-06-08
- **Prepared by:** TestSprite AI Team

---

## 2️⃣ Requirement Validation Summary

#### Test TC001 post apiv1authregister with valid data
- **Test Code:** [TC001_post_apiv1authregister_with_valid_data.py](./TC001_post_apiv1authregister_with_valid_data.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 87, in <module>
  File "<string>", line 33, in test_post_apiv1authregister_with_valid_data
AssertionError: Expected 200 OK, got 404

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/0a208e04-abe9-45e0-b4bc-86235d2f897f
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC002 post apiv1authlogin with valid credentials
- **Test Code:** [TC002_post_apiv1authlogin_with_valid_credentials.py](./TC002_post_apiv1authlogin_with_valid_credentials.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 27, in <module>
  File "<string>", line 16, in test_post_apiv1_auth_login_with_valid_credentials
AssertionError: Unexpected status code: 401, Response: {"detail":"Login failed"}

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/2e32fcd5-9e52-4c0f-8c48-7c4e1309bff9
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC003 get apiv1authme with valid access token
- **Test Code:** [TC003_get_apiv1authme_with_valid_access_token.py](./TC003_get_apiv1authme_with_valid_access_token.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 46, in <module>
  File "<string>", line 17, in test_get_apiv1authme_with_valid_access_token
AssertionError: Expected status code 200, got 401

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/45ef58cf-fe7e-4838-9bf8-98eae957e71c
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC004 post apiv1authrefresh with valid refresh token
- **Test Code:** [TC004_post_apiv1authrefresh_with_valid_refresh_token.py](./TC004_post_apiv1authrefresh_with_valid_refresh_token.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 89, in <module>
  File "<string>", line 37, in test_post_apiv1authrefresh_with_valid_refresh_token
AssertionError: Unexpected status code on register: 404

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/d5333339-8bf8-46df-8767-110e9d936995
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC005 post apiv1students create new student
- **Test Code:** [TC005_post_apiv1students_create_new_student.py](./TC005_post_apiv1students_create_new_student.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 54, in <module>
  File "<string>", line 27, in test_post_apiv1students_create_new_student
AssertionError: Expected 200 OK, got 401: {"detail":"Invalid or expired token"}

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/e1ceec57-66cd-4415-8e03-2853e0a38b36
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC006 get apiv1students list students
- **Test Code:** [TC006_get_apiv1students_list_students.py](./TC006_get_apiv1students_list_students.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 140, in <module>
  File "<string>", line 66, in test_get_apiv1students_list_students
AssertionError: Unauthorized: Invalid or expired token

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/98572eee-0cca-4afb-bffc-e3b192e0d175
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC007 post apiv1attendancebarcode mark attendance by barcode
- **Test Code:** [TC007_post_apiv1attendancebarcode_mark_attendance_by_barcode.py](./TC007_post_apiv1attendancebarcode_mark_attendance_by_barcode.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 140, in <module>
  File "<string>", line 28, in test_post_apiv1attendancebarcode_mark_attendance_by_barcode
AssertionError: Failed to create student: {"detail":"Invalid or expired token"}

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/1a26b079-42f2-4955-8b4d-7cdcee93ecad
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC008 post apiv1lessonslessoniduploadvideo upload lesson video
- **Test Code:** [TC008_post_apiv1lessonslessoniduploadvideo_upload_lesson_video.py](./TC008_post_apiv1lessonslessoniduploadvideo_upload_lesson_video.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 70, in <module>
  File "<string>", line 31, in test_post_apiv1_lessons_lessonid_upload_video
  File "<string>", line 18, in create_lesson
  File "/var/lang/lib/python3.12/site-packages/requests/models.py", line 1024, in raise_for_status
    raise HTTPError(http_error_msg, response=self)
requests.exceptions.HTTPError: 401 Client Error: Unauthorized for url: http://localhost:8000/api/v1/lessons/

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/0058de69-2853-4bd9-ad8e-3ab5075aeac0
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC009 post apiv1subscriptionsactivate activate subscription code
- **Test Code:** [TC009_post_apiv1subscriptionsactivate_activate_subscription_code.py](./TC009_post_apiv1subscriptionsactivate_activate_subscription_code.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 79, in <module>
  File "<string>", line 18, in test_post_apiv1subscriptionsactivate_activate_subscription_code
AssertionError: Failed to fetch plans, status code: 401

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/d60479f4-c3d7-477b-be0a-0ff6a832a900
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC010 get apiv1dashboardstats get dashboard statistics
- **Test Code:** [TC010_get_apiv1dashboardstats_get_dashboard_statistics.py](./TC010_get_apiv1dashboardstats_get_dashboard_statistics.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 29, in <module>
  File "<string>", line 17, in test_get_dashboard_stats
AssertionError: Expected 200 OK, got 401. Response: {"detail":"Invalid or expired token"}

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c6110e54-1218-43b0-8057-a77492c2eb66/4251ded5-78d4-4528-a403-03b0e30ef292
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---


## 3️⃣ Coverage & Matching Metrics

- **0.00** of tests passed

| Requirement        | Total Tests | ✅ Passed | ❌ Failed  |
|--------------------|-------------|-----------|------------|
| ...                | ...         | ...       | ...        |
---


## 4️⃣ Key Gaps / Risks
{AI_GNERATED_KET_GAPS_AND_RISKS}
---