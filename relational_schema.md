# Relational Schema — University Room Booking System

All tables use PostgreSQL naming conventions. Primary keys use `SERIAL` for auto-incrementing integers. Timestamps use `TIMESTAMPTZ` for timezone-aware storage.

---

## Table: `building`

Stores physical buildings on campus.

| Column      | Type          | Constraints                          |
|-------------|---------------|--------------------------------------|
| `id`        | `SERIAL`      | `PRIMARY KEY`                        |
| `name`      | `VARCHAR(255)` | `NOT NULL`                           |
| `address`   | `TEXT`         | `NOT NULL`                           |

---

## Table: `room`

Stores bookable spaces inside a building.

An enum type `room_type` is used to constrain room categories.

```sql
CREATE TYPE room_type AS ENUM ('meeting_room', 'lecture_room', 'studio', 'workshop');
```

| Column        | Type          | Constraints                                    |
|---------------|---------------|------------------------------------------------|
| `id`          | `SERIAL`      | `PRIMARY KEY`                                  |
| `building_id` | `INTEGER`     | `NOT NULL, FOREIGN KEY → building(id)`         |
| `room_number` | `VARCHAR(50)` | `NOT NULL`                                     |
| `capacity`    | `INTEGER`     | `NOT NULL, CHECK (capacity > 0)`               |
| `room_type`   | `room_type`   | `NOT NULL`                                     |

- `building_id` is a foreign key referencing `building(id)`. A room must belong to exactly one building.
- `room_number` is unique per building (application-enforced unique constraint or composite unique on `(building_id, room_number)`).

---

## Table: `equipment`

Stores the fixed catalogue of equipment types.

| Column          | Type          | Constraints                  |
|-----------------|---------------|------------------------------|
| `id`            | `SERIAL`      | `PRIMARY KEY`                |
| `equipment_name`| `VARCHAR(100)` | `NOT NULL, UNIQUE`           |

Pre-seeded values: `projector`, `whiteboard`, `microphone`, `video camera`.

---

## Table: `room_equipment`

Linking table for the many-to-many relationship between `room` and `equipment`.  
Each row indicates that a particular room contains a particular equipment type.

| Column         | Type      | Constraints                                          |
|----------------|-----------|------------------------------------------------------|
| `room_id`      | `INTEGER` | `NOT NULL, FOREIGN KEY → room(id) ON DELETE CASCADE` |
| `equipment_id` | `INTEGER` | `NOT NULL, FOREIGN KEY → equipment(id) ON DELETE CASCADE` |

| Constraint                        | Columns                    |
|-----------------------------------|----------------------------|
| `PRIMARY KEY`                     | `(room_id, equipment_id)`  |

- Composite primary key enforces uniqueness — a room cannot have the same equipment type listed twice.
- `ON DELETE CASCADE` ensures that deleting a room or equipment row cleans up the linking table.

---

## Table: `organization`

Stores student organisations that can book rooms.

| Column     | Type          | Constraints            |
|------------|---------------|------------------------|
| `id`       | `SERIAL`      | `PRIMARY KEY`          |
| `org_name` | `VARCHAR(255)` | `NOT NULL, UNIQUE`     |

---

## Table: `app_user`

Stores individuals (students) who create bookings. Named `app_user` to avoid conflicts with the PostgreSQL `user` reserved word. Minimal personal data by design.

| Column          | Type          | Constraints                    |
|-----------------|---------------|--------------------------------|
| `id`            | `SERIAL`      | `PRIMARY KEY`                  |
| `identifier`    | `VARCHAR(100)` | `NOT NULL, UNIQUE`             |
| `display_name`  | `VARCHAR(255)` | `NULL`                         |

- `identifier` stores an opaque student/employee number or hashed email.
- `display_name` is an optional human-readable label.

---

## Table: `recurring_series`

Stores the recurrence rule for a set of bookings that repeat on a schedule.  
Individual occurrences are materialised as rows in the `booking` table (see below).

| Column            | Type           | Constraints        |
|-------------------|----------------|--------------------|
| `id`              | `SERIAL`       | `PRIMARY KEY`      |
| `recurrence_rule` | `VARCHAR(255)` | `NOT NULL`         |
| `end_date`        | `DATE`         | `NOT NULL`         |

- `recurrence_rule` stores a human-readable or iCalendar RRULE string (e.g. `"weekly Wednesday"` or `"FREQ=WEEKLY;BYDAY=WE"`).
- `end_date` is the date after which no more occurrences are generated.

---

## Table: `booking`

Stores individual room reservations. This is the core table.  
Recurrence is handled by an optional link to `recurring_series`. Individual occurrences in a recurring series are materialised as separate `booking` rows.

An enum type `booking_status` is used for the booking lifecycle.

```sql
CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'cancelled', 'rejected');
```

| Column                 | Type             | Constraints                                                       | Nullable |
|------------------------|------------------|-------------------------------------------------------------------|----------|
| `id`                   | `SERIAL`         | `PRIMARY KEY`                                                     | NO       |
| `room_id`              | `INTEGER`        | `NOT NULL, FOREIGN KEY → room(id)`                                | NO       |
| `organization_id`      | `INTEGER`        | `NOT NULL, FOREIGN KEY → organization(id)`                        | NO       |
| `user_id`              | `INTEGER`        | `NOT NULL, FOREIGN KEY → app_user(id)`                            | NO       |
| `recurring_series_id`  | `INTEGER`        | `FOREIGN KEY → recurring_series(id) ON DELETE SET NULL`           | YES      |
| `start_time`           | `TIMESTAMPTZ`    | `NOT NULL`                                                        | NO       |
| `end_time`             | `TIMESTAMPTZ`    | `NOT NULL, CHECK (end_time > start_time)`                         | NO       |
| `status`               | `booking_status` | `NOT NULL, DEFAULT 'pending'`                                     | NO       |
| `approval_required`    | `BOOLEAN`        | —                                                                 | YES      |
| `approval_granted`     | `BOOLEAN`        | —                                                                 | YES      |
| `cancelled_at`         | `TIMESTAMPTZ`    | —                                                                 | YES      |
| `cancel_reason`        | `TEXT`           | —                                                                 | YES      |
| `override_start`       | `TIMESTAMPTZ`    | —                                                                 | YES      |
| `override_end`         | `TIMESTAMPTZ`    | `CHECK (override_end > override_start)`                           | YES      |

**Notes on nullable columns:**

- `recurring_series_id` — `NULL` for one-off (non-recurring) bookings. When set, this booking is part of a recurring series.
- `approval_required` — `NULL` means not applicable (room does not require approval). `TRUE` means approval is needed; `FALSE` means explicitly not required.
- `approval_granted` — `NULL` means no decision yet. `TRUE` = approved, `FALSE` = denied.
- `cancelled_at` — only populated when `status = 'cancelled'`.
- `cancel_reason` — only populated when `status = 'cancelled'`.
- `override_start` / `override_end` — only populated for recurring-series bookings that have been rescheduled from the series default time. When both are `NULL`, the occurrence uses the time computed from `recurring_series.recurrence_rule`.

---

## Summary of Foreign Key Relationships

| Child Table       | Column                | Parent Table      | Parent Column | On Delete       |
|-------------------|-----------------------|-------------------|---------------|-----------------|
| `room`            | `building_id`         | `building`        | `id`          | _(default: restrict)_ |
| `room_equipment`  | `room_id`             | `room`            | `id`          | `CASCADE`       |
| `room_equipment`  | `equipment_id`        | `equipment`       | `id`          | `CASCADE`       |
| `booking`         | `room_id`             | `room`            | `id`          | _(default: restrict)_ |
| `booking`         | `organization_id`     | `organization`    | `id`          | _(default: restrict)_ |
| `booking`         | `user_id`             | `app_user`        | `id`          | _(default: restrict)_ |
| `booking`         | `recurring_series_id` | `recurring_series`| `id`          | `SET NULL`      |

- `ON DELETE CASCADE` on `room_equipment` means deleting a room or equipment type automatically removes the link.
- `ON DELETE SET NULL` on `booking.recurring_series_id` means deleting a recurring series does not delete the individual bookings — they become standalone one-off bookings.
- All other foreign keys default to `ON DELETE RESTRICT` (or `NO ACTION`), preventing deletion of parent records while child records exist.

---

## Entity-Relationship-to-Table Mapping Summary

| ER Entity / Relationship | Relational Table    | Notes                                  |
|--------------------------|---------------------|----------------------------------------|
| Building                 | `building`          |                                        |
| Room                     | `room`              | FK to `building`                       |
| Equipment                | `equipment`         |                                        |
| Room–Equipment (M:N)     | `room_equipment`    | Linking table, composite PK            |
| Organization             | `organization`      |                                        |
| User                     | `app_user`          | Renamed from `user` (reserved word)    |
| Booking                  | `booking`           | Core table, FK to room, org, user      |
| RecurringSeries          | `recurring_series`  | Optional parent for recurring bookings |
| BookingOccurrence        | _(folded into `booking`)_ | Via nullable `recurring_series_id` + override columns |