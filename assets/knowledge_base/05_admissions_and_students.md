# Student Admissions, Directory & AI CSV Import

> **Module**: Student Management  
> **Sidebar Tabs**:  
> - **Student Admission Wizard** `[NAV:admission]`  
> - **Student Directory** `[NAV:students]`  
> **Access**: Super Admin, Admin, Accountant (view only), Teacher (view only)

---

## 1. Student Admission Wizard

The Admission Wizard is a multi-step guided registration flow for enrolling new students.

### Step-by-Step: Registering a New Student
1. Go to **Student Admission Wizard** from the sidebar.
2. **Step 1: Personal Details**:
   - First Name, Last Name, Date of Birth, Gender, Blood Group, Nationality, Religion.
   - Student Photo (upload PNG or JPG image).
3. **Step 2: Parent / Guardian Information**:
   - Father's Name, Mother's Name, Primary Guardian Name.
   - Contact Phone Number, Email Address, Residential Address.
4. **Step 3: Academic Placement**:
   - **Admission Number**: System automatically generates a unique sequential admission number (e.g., `ADM-2026-0042`), or you can specify a custom number.
   - Select the target **Class** and **Section**.
   - Roll Number within the section.
   - Admission Date and Previous School Information.
5. **Step 4: Optional Facilities**:
   - Opt into **Transport**: Select bus route and pick-up stop.
   - Opt into **Hostel**: Select hostel block and room allocation.
6. **Step 5: Document Upload**:
   - Attach Birth Certificate, Transfer Certificate (TC), Aadhaar/National ID, and Previous Mark Sheets.
7. Click **Complete Admission**. The student is immediately active across attendance, classes, and fee billing.

---

## 2. Student Directory

The Student Directory is the central search and management hub for all registered students.

### Filtering and Managing Students
- **Search Bar**: Search by Student Name, Admission Number, or Parent Phone Number.
- **Filters**: Filter by Class, Section, Gender, or Status (`Active`, `Inactive`, `Alumni`).
- **Student Profile View**:
  - Click on any student row to view full details: personal info, academic grades, attendance history, and fee payment status.
  - Click **Edit Student** to update contact details, address, or roll numbers.
  - Click **Print Profile** or **ID Card** to generate a student ID card.

---

## 3. AI-Powered CSV & Excel Student Import

If migrating from another software or importing hundreds of students at once, Eduvia provides an AI-assisted bulk import tool.

### How to Import Students via CSV or Excel
1. Go to **Student Directory** from the sidebar.
2. Click the **Import Students** button at the top right.
3. Click **Choose File** and select your `.csv` or `.xlsx` file.
4. **Intelligent Column Mapping**:
   - Eduvia's AI mapper inspects your spreadsheet headers and automatically matches them to Eduvia's database fields:
     - e.g., `"Student Name"` or `"Full Name"` $\rightarrow$ `name`
     - e.g., `"Adm No"`, `"Enrollment ID"`, `"Reg Number"` $\rightarrow$ `admission_number`
     - e.g., `"Contact"`, `"Mobile"`, `"Cell"` $\rightarrow$ `phone`
     - e.g., `"Standard"`, `"Grade"` $\rightarrow$ `class_id`
   - You can manually override any column mapping if needed using the dropdown selectors.
5. **Data Validation Preview**:
   - The preview table shows valid records with green checkmarks and flags any formatting issues (e.g., invalid date formats).
6. Click **Confirm & Import All Students**.
7. Hundreds of students are imported into SQLite in seconds, complete with auto-generated fee ledger accounts.

---

## 4. FAQs & Tips

- **Q: Can two students have the same Admission Number?**  
  *A:* No. Admission Numbers must be unique across the entire school database.
- **Q: What happens if a student leaves the school?**  
  *A:* Open the student's profile, click **Edit**, and change their status to `Alumni` or `Inactive`. Their historical marks and fee ledgers are preserved permanently, but they will no longer appear in daily attendance rosters.
