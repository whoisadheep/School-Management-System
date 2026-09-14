# Fee Collection, Structures, Invoicing & Student Ledger

> **Module**: Financial Management  
> **Sidebar Tabs**:  
> - **Fee Collection & Invoicing** `[NAV:feeCollection]`  
> - **Fee Structure Configuration** `[NAV:feeStructure]`  
> - **Fee Reports & Analytics** `[NAV:feeReports]`  
> **Access**: Super Admin, Admin, Accountant

---

## 1. Overview

The Fee Management system provides end-to-end handling of school finances:
- Defining custom fee heads and grade-wise fee structures.
- Assigning student concessions and scholarships.
- Rapid fee collection searching by **Admission Number**.
- Printing 80mm Thermal receipts and A4 invoices.
- Comprehensive student ledgers and outstanding dues reports.

---

## 2. Fee Structure Configuration

Before collecting fees, configure what fee components apply to each class.

### Step 1: Define Fee Heads
1. Go to **Fee Structure Configuration** from the sidebar.
2. In the **Fee Heads** section:
   - Enter head names such as: `Monthly Tuition Fee`, `Annual Admission Fee`, `Exam Fee`, `Library Fee`, `Sports & Activity Fee`, `Transport Fee`.
   - Specify whether the fee is Monthly, Quarterly, or Annual.
3. Click **Save Fee Head**.

### Step 2: Assign Fee Amounts to Classes
1. In the **Class Fee Structures** tab:
   - Select the target **Class** (e.g., `Class 10`).
   - Check the fee heads that apply to this class.
   - Enter the exact amount for each component (e.g., Tuition: $150/mo, Exam: $30/term).
2. Click **Save Structure**. All students admitted to this class will automatically be billed based on this structure.

---

## 3. Scholarships & Concessions

Eduvia allows administrators to grant discounts to specific students (e.g., Sibling concession, Merit scholarship, Staff child discount).

### How to Assign a Discount to a Student
1. Go to **Student Directory** [NAV:students] or **Fee Structure Configuration**.
2. Select the student and click **Manage Discounts**.
3. Choose the discount type:
   - **Percentage (%)**: e.g., 20% off Tuition Fee.
   - **Flat Amount ($)**: e.g., $50 off total invoice.
4. Enter the reason/category and click **Apply Discount**.
5. Future invoices generated for this student will automatically reflect the discounted amount.

---

## 4. Fee Collection Desk

The fee collection desk is optimized for high-speed reception counter billing.

### Step-by-Step: How to Collect Fees
1. Navigate to **Fee Collection & Invoicing** from the sidebar.
2. **Search for Student**:
   - In the search bar at the top, enter the student's **Admission Number** (e.g., `ADM-2026-0042`) or Student Name.
   - The dropdown displays the student's **Admission Number**, full name, class, and section for positive identification.
   - Click on the student to load their profile and outstanding dues.
3. **Select Items to Pay**:
   - The screen lists all pending fee items (e.g., May Tuition, Exam Fee, Transport).
   - Check the boxes for the items the parent is paying today.
   - You can enter partial amounts if the parent is paying a portion of the fee.
4. **Choose Payment Mode**:
   - Select from: `Cash`, `Bank Transfer`, `Cheque`, or `UPI Reference`.
   - If Cheque, Bank Transfer, or UPI is selected, enter the transaction/cheque reference number.
5. **Collect & Print Receipt**:
   - Click **Collect Fee**.
   - Choose your receipt format:
     - **Thermal Receipt (80mm)**: Ideal for fast POS thermal receipt printers.
     - **A4 Standard Invoice**: Ideal for full-page standard laser/inkjet printers.
   - The receipt includes school details, receipt number, date, student admission number, itemized payments, and remaining balance dues.

---

## 5. Student Fee Ledger

The Student Fee Ledger provides an unalterable, chronological record of all financial activity for an individual student:
- **Debits (Charges)**: Every invoice issued or monthly fee scheduled.
- **Credits (Payments)**: Every payment collected with receipt number and payment mode.
- **Running Balance**: Live balance due (positive means outstanding debt; zero means fully paid).

To view a student's ledger:
1. Open **Fee Collection & Invoicing**.
2. Select the student and switch to the **Student Ledger** tab.
3. Click **Export PDF** or **Print Ledger** to provide parents with a full statement of account.

---

## 6. Fee Reports & Defaulters List

Navigate to **Fee Reports & Analytics** [NAV:feeReports] to access:
- **Daily Collection Register**: Total cash, UPI, bank, and cheque collected today.
- **Fee Defaulters List**: List of students with unpaid dues grouped by class, including parent phone numbers for follow-ups.
- **CSV / Excel Export**: One-click export of financial records for external accounting.
