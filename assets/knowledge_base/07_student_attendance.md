# Student Attendance Management

> **Module**: Academic Management  
> **Sidebar Tab**: **Student Attendance**  
> **Deep Link**: `[NAV:attendance]`  
> **Access**: All Roles (Super Admin, Admin, Teacher)

---

## 1. Overview

Eduvia provides a streamlined, fast attendance entry system designed for class teachers to record morning attendance in under 30 seconds.

---

## 2. Marking Daily Class Attendance

### Step-by-Step Instructions
1. Navigate to **Student Attendance** from the sidebar.
2. Select the filters:
   - **Date**: Defaults to today's date (or pick past dates to backfill).
   - **Class**: e.g., `Class 5`.
   - **Section**: e.g., `Section A`.
3. The student list for that section loads automatically with their Roll Number, Admission Number, and Full Name.
4. **Speed Tip — "Mark All Present"**:
   - Click the green **Mark All Present** button at the top to set every student to `Present` instantly.
   - Then, simply click on the few students who are absent to change their status to `Absent` or `Late`.
5. **Attendance Status Options**:
   - `Present` (Green): Student in attendance.
   - `Absent` (Red): Unexcused absence.
   - `Late` (Yellow): Arrived after morning bell.
   - `Half-Day` (Orange): Left school early with permission.
   - `Excused / Leave` (Blue): Authorized medical or parent leave note.
6. (Optional) Enter brief remarks (e.g., "Doctor appointment").
7. Click **Save Attendance**.

---

## 3. Monthly Attendance Register & Reports

- **Monthly Grid View**: Switch to the **Monthly Register** tab to view a calendar grid for the entire month (days 1 to 31) showing every student's status per day.
- **Attendance Percentage**: The system automatically computes:
  $$\text{Attendance \%} = \left(\frac{\text{Total Days Present}}{\text{Total Working Days}}\right) \times 100$$
- **Low Attendance Warning**: Students falling below the required institutional threshold (e.g., 75%) are automatically highlighted in red for academic review.
- **Exporting Registers**: Click **Export PDF** or **Export Excel** to print monthly registers for school records.

---

## 4. Bulk CSV Attendance Import

If attendance was recorded in another software or spreadsheet:
1. Open **Student Attendance** and click **Import Attendance CSV**.
2. Upload the `.csv` file with columns: `admission_number`, `date`, `status`.
3. Click **Validate & Import**.

---

## 5. Limitations & What is NOT Supported
- **Direct Biometric Fingerprint/Face Recognition Scanner**: Eduvia does not connect directly to USB or IP biometric hardware turnstiles. Attendance must be marked via the daily roster or imported via CSV.
- **Automated SMS Notification to Parents on Absence**: Eduvia does not automatically send SMS messages when a student is marked absent. Staff can export absence lists to contact parents.
