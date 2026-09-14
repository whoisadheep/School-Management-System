# Examinations, Marks Entry & Report Cards

> **Module**: Academic Management  
> **Sidebar Tab**: **Exams & Performance Reports**  
> **Deep Link**: `[NAV:exams]`  
> **Access**: Super Admin, Admin, Teacher

---

## 1. Overview

The Examinations module handles the entire examination lifecycle in Eduvia:
1. Creating exams and scheduling test dates.
2. Auto-picking curriculum subjects for the selected class.
3. Rapid tabular marks entry for entire classes via the **Marks Entry Roster**.
4. Grading scales and generating professional, printable PDF report cards.

---

## 2. Creating an Examination

### How to Create an Exam
1. Navigate to **Exams & Performance Reports** from the sidebar.
2. Click the **+ Create Exam** button.
3. Fill in the exam details:
   - **Exam Name**: e.g., `Mid-Term Examination 2026`, `Annual Final Exam`.
   - **Academic Year**: e.g., `2026-2027`.
   - **Term / Type**: Select from Term 1, Term 2, Final, or Monthly Test.
   - **Start & End Dates**: Select from the date picker.
   - **Target Class**: Select the class taking this exam (e.g., `Class 10`).
4. **Subject Population (Auto-Pick)**:
   - As soon as you select the Class, Eduvia **automatically pulls all subjects** previously configured in **Class & Section Setup** for that class.
   - Each subject appears as an interactive chip showing its name and code.
5. **Flexible Subject Customization**:
   - **To exclude a subject from this exam**: Click the `X` icon on any subject chip (e.g., if "Physical Education" is not tested in this term). Removing it here will **NOT** delete it from the class curriculum.
   - **To add an extra subject**: Type the subject name and click the **+** button.
6. Specify the **Maximum Marks** (default 100) and **Passing Marks** (default 33 or 40).
7. Click **Save Exam**.

---

## 3. Entering Student Marks (Marks Entry Roster)

Eduvia features a high-speed tabular roster to enter marks for all students in a section simultaneously.

### Step-by-Step: How to Enter Marks
1. Go to **Exams & Performance Reports**.
2. Select the **Exam**, **Class**, and **Section** from the filter dropdowns at the top.
3. Click the **Marks Entry Roster** button.
4. A full tabular roster displays all enrolled students with their Roll Number and Student Name:
   - Each subject has its own input column.
   - Enter marks directly into each subject cell.
   - Press `Tab` or `Enter` to move smoothly between cells and rows.
5. Total Marks and Overall Percentage update automatically as you type.
6. Click **Save Marks** at the bottom right to persist all entered grades.

---

## 4. Grade Scales

Eduvia uses configurable grade scales to translate percentage scores into letter grades and GPA points:

| Percentage Range | Grade | Remarks |
| :--- | :---: | :--- |
| **90% - 100%** | **A+** | Outstanding |
| **80% - 89%** | **A** | Excellent |
| **70% - 79%** | **B+** | Very Good |
| **60% - 69%** | **B** | Good |
| **50% - 59%** | **C** | Average |
| **33% - 49%** | **D** | Pass |
| **Below 33%** | **F** | Needs Improvement (Fail) |

Grade scales can be customized in the Grade Scale tab within the Exams module.

---

## 5. Generating & Printing Report Cards

### Individual Report Card
1. In the **Exams & Performance Reports** view, filter by Exam and Class.
2. In the student marks table, click the **Report Card** icon next to any student's name.
3. A clean PDF preview will open containing:
   - School name, address, and logo header.
   - Student information (Name, Admission No, Roll No, Class, Section).
   - Subject-wise breakdown: Max Marks, Obtained Marks, Grade, and Result status.
   - Total marks, overall percentage, final grade, and teacher remarks.
4. Click **Print** or **Download PDF**.

### Bulk Class Report Cards
- To generate report cards for the entire section at once, click the **Generate All Report Cards** button at the top of the roster.
- A multi-page PDF document is generated ready for bulk printing before parent-teacher conferences.

---

## 6. FAQs

- **Q: Why didn't any subjects appear when I created an exam?**  
  *A:* You have not assigned subjects to that class yet. Go to **Class & Section Setup** [NAV:classes], find your class, click the **Subjects** button, and add your curriculum subjects.
- **Q: Can I edit marks after saving?**  
  *A:* Yes. Open the Marks Entry Roster for that exam and class at any time, update the numbers, and click Save Marks.
