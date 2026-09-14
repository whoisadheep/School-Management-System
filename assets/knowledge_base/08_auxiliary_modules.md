# Auxiliary Modules: Library, Hostel, Transport & Inventory

> **Module**: School Operations & Facilities  
> **Sidebar Tabs**:  
> - **Library Management** `[NAV:library]`  
> - **Hostel Management** `[NAV:hostel]`  
> - **Transport Management** `[NAV:transport]`  
> - **Inventory Management** `[NAV:inventory]`

---

## 1. Library Management `[NAV:library]`

The Library module manages the school's book catalog and circulation records.

### Adding Books to the Catalog
1. Go to **Library Management** from the sidebar.
2. Click **+ Add Book**.
3. Enter Book Details: Title, Author, Publisher, Category/Genre, ISBN Number, Rack/Shelf Number, Total Copies.
4. Click **Save Book**.

### Issuing and Returning Books
- **To Issue a Book**:
  1. Under the **Circulation / Issue Book** tab, search for the book by Title or ISBN.
  2. Search for the borrower (Student by **Admission Number** or Staff by Employee ID).
  3. Set Issue Date and Due Date (default 14 days).
  4. Click **Confirm Issue**.
- **To Return a Book**:
  1. Locate the active issue in the **Issued Books** list.
  2. Click **Return Book**.
  3. If returned past the due date, Eduvia calculates the overdue fine based on your library fine settings.

---

## 2. Hostel Management `[NAV:hostel]`

The Hostel module tracks residential facilities for boarding schools.

### Managing Hostel Blocks & Rooms
1. Go to **Hostel Management** from the sidebar.
2. **Add Hostel Block**: Create blocks (e.g., `Junior Boys Hostel`, `Senior Girls Block`) and assign a Hostel Warden.
3. **Add Rooms**: Under each block, add rooms specifying Room Number, Room Type (Single, Double, Dormitory), Total Bed Capacity, and Monthly Hostel Fee.

### Allocating Students to Rooms
1. Go to the **Room Allocations** tab.
2. Search for the student by **Admission Number**.
3. Select the target Block and Room with available bed capacity.
4. Click **Allocate Bed**. The student's fee ledger will automatically include hostel charges if configured.

---

## 3. Transport Management `[NAV:transport]`

The Transport module oversees school bus routes, stops, and student passenger lists.

### Vehicles & Bus Routes Setup
1. Go to **Transport Management** from the sidebar.
2. **Add Vehicle**: Enter Vehicle Registration Number (e.g., `BUS-01`), Model, Seating Capacity, Driver Name, Driver License, and Emergency Phone.
3. **Create Route & Stops**:
   - Add Route (e.g., `Route 12 - Downtown to Main Campus`).
   - Add Stops along the route with expected pick-up/drop-off times and monthly transport fare per stop.

### Assigning Students to Routes
1. Under **Student Transport Allocation**, select the student by **Admission Number**.
2. Assign the Route and Stop.
3. The monthly transport fee is automatically mapped to the student's fee structure.

---

## 4. Inventory & Asset Management `[NAV:inventory]`

Tracks physical school property, classroom furniture, laboratory apparatus, and IT equipment.

### Tracking Assets
1. Go to **Inventory Management** from the sidebar.
2. Click **+ Add Item / Asset**.
3. Fill in:
   - **Item Name**: e.g., `Dell Desktop Computer`, `Student Desk & Chair Set`, `Microscope`.
   - **Category**: IT Equipment, Furniture, Science Lab, Sports, Stationery.
   - **Quantity & Unit**: e.g., 25 Units.
   - **Condition**: New, Good, Needs Repair, Damaged.
   - **Purchase Details**: Purchase date, vendor name, unit price, invoice number.
4. Click **Save Asset**.
5. Use the Inventory Dashboard to track stock depletion, re-order thresholds, and asset maintenance logs.
