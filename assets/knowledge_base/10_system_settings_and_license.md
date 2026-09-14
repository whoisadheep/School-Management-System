# System Settings, Database Backup, Licensing & Troubleshooting

> **Module**: System Administration & Configuration  
> **Sidebar Tabs**:  
> - **System Settings** `[NAV:settings]`  
> - **Manage Admin Users** `[NAV:manageUsers]`  
> - **Activity Log** `[NAV:activityLog]`  
> **Access**: Super Admin, Admin

---

## 1. School Information & Branding Settings

The settings module controls institutional identity across all generated invoices, receipts, and report cards.

### How to Update School Profile
1. Go to **System Settings** from the sidebar.
2. Under **School Identity**:
   - **School Name**: Enter the full official name (e.g., `St. Xavier's International School`). This name is saved permanently to the local database and persists across app restarts.
   - **School Address**: Street address, city, state, postal code.
   - **Contact Phone & Email**: Official administration contact lines.
   - **Affiliation / Registration Code**: Board registration number (e.g., CBSE, ICSE, State Board ID).
   - **Current Academic Session**: e.g., `2026-2027`.
   - **School Logo**: Upload the school's official crest/logo (PNG or JPG).
3. Click **Save Settings**. All report cards, fee receipts, and salary slips will immediately use this updated branding.

---

## 2. Database Backup & Disaster Recovery

Because Eduvia operates on a local, offline SQLite architecture, regular database backups protect against hardware failure or accidental data loss.

### How to Create an Instant Backup
1. Navigate to **System Settings** -> **Database Backup & Recovery** tab.
2. Click **Create Backup Now**.
3. Choose the destination directory (e.g., an external USB drive, a secondary hard drive, or a synced backup folder).
4. Eduvia creates a timestamped snapshot: `eduvia_backup_YYYY_MM_DD.db`.

### How to Restore from a Backup
1. In the same tab, click **Restore Database from File**.
2. Select your previously saved `.db` backup file.
3. Confirm the restoration warning. The app will replace current tables with the backup data and reload.

---

## 3. License Activation & Hardware ID (HWID)

Eduvia uses a secure offline licensing mechanism tied to the machine's hardware profile:
- **Hardware ID (HWID)**: A unique machine fingerprint derived from the computer's CPU and motherboard.
- **Activating a License**:
  1. Open **System Settings** -> **License & Activation**.
  2. Copy your displayed Hardware ID and provide it to Eduvia Support.
  3. Enter your issued License Activation Key.
  4. Click **Activate License**.
- **Grace Period / Read-Only Mode**: If a license expires, Eduvia enters a read-only mode where historical data, past receipts, and report cards remain accessible, but new entries cannot be created until renewed.

---

## 4. User Accounts & Activity Audit Trail

- **Managing User Accounts**: Under **Manage Admin Users** [NAV:manageUsers], the Super Admin can create accounts for accountants and teachers, assign passwords, and modify roles.
- **Activity Log & Audit Trail**: Under **Activity Log** [NAV:activityLog], view a tamper-proof log of who performed key actions (e.g., *"Admin John updated marks for Class 10 on Sep 14"*, *"Accountant Sarah collected $200 from ADM-0042"*).

---

## 5. Technical Troubleshooting

### Issue: "MSVCP140.dll was not found" or "VCRUNTIME140.dll missing"
- **Cause**: The host Windows machine is missing the standard Microsoft Visual C++ Redistributable runtime required by Flutter desktop and SQLite FFI.
- **Solution**:
  1. Eduvia's standard Windows installer (`installer.iss`) automatically detects missing Visual C++ runtimes and installs `vc_redist.x64.exe` quietly.
  2. If running standalone without the installer, download and install the free **Microsoft Visual C++ 2015–2022 Redistributable (x64)** from Microsoft's official website, or run the installer located in `windows/redist/vc_redist.x64.exe`.

### Issue: School Name reverts to "Eduvia" after restarting
- **Solution**: Ensure you click **Save Settings** in System Settings after editing the name. Eduvia persists the school name directly into the local SQLite settings table upon clicking save.

---

## 6. Technical Support & Developer Contact

For technical assistance, hardware ID license keys, or customizations:
- **Developer**: Kishan
- **Contact Number**: 9839994285

