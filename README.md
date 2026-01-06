# Exhibition Booth Manager

A Flutter application for managing exhibitions, booth layouts, and booth booking applications with role-based access for **Admin**, **Organizer**, **Exhibitor**, and **Guest**.

## Features

### Roles
- **Admin**: Manage users and exhibitions, upload floor plans, manage booth mapping (admin override), view booking overview.
- **Organizer**: Manage exhibitions, booth types, add-ons, booth layouts, and approve/reject applications.
- **Exhibitor**: Browse published exhibitions, search/filter exhibitions, view floor plans, apply for booths, and track application statuses.
- **Guest**: Browse published exhibitions and view booth maps (read-only).

### Core flows
- Authentication (register + login with role selection)
- Published exhibition browsing with basic search/filter
- Floor plan viewing (image zoom/pan)
- Booth mapping per exhibition (layout saved to DB)
- Booth application submission + status tracking
- Organizer approval workflow with decision reasons

## Tech Stack

- **Flutter / Dart**
- **SQLite** via `sqflite`

### Third‑party packages (examples)
This project uses multiple packages including:
- `sqflite`, `path`
- `http`, `provider`
- `file_picker`, `path_provider`
- `intl`

## Database

- Database product: **SQLite**
- Database name (SQLite file): `exhibition_booth_management.db`
- Tables (high-level): `users`, `exhibitions`, `booth_applications`, `floor_plans`, `booth_layouts`, `booth_types`, `add_ons`

Full schema + ERD are documented in: [docs/SectionB_Project_Report.md](docs/SectionB_Project_Report.md)

## Getting Started

### Prerequisites
- Flutter SDK (3.x recommended)
- Android Studio / VS Code with Flutter extension
- An Android emulator or a physical device

### Install dependencies
```bash
flutter pub get
```

### Run
```bash
flutter run
```

### Tests
```bash
flutter test
```

## Demo Accounts (Seeded)

The app seeds sample users in the local database:

- Admin: `admin@exhibition.com` / `password123`
- Organizer: `organizer@exhibition.com` / `password123`
- Exhibitor: `exhibitor@exhibition.com` / `password123`

## Project Structure

```text
lib/
	main.dart
	models/
	screens/
		admin/
		organizer/
		public/
	services/
docs/
	SectionB_Project_Report.md
	screenshots/
```

## Screenshots

Place screenshots in `docs/screenshots/` and update links inside the report:
- [docs/SectionB_Project_Report.md](docs/SectionB_Project_Report.md)

## Notes

- Passwords are stored as plain text for demo purposes. For production, use hashing and secure storage.
- SQLite foreign keys are represented logically (via ID columns) but are not enforced with `FOREIGN KEY` constraints in the current schema.
