# Subject Analysis — University Room Booking System

## 1. Candidate Subjects

| Subject | Description | Key Attributes |
|---|---|---|
| **Building** | A physical building on campus. | name, address |
| **Room** | A bookable space inside a building. | room_number, capacity, room_type (meeting_room / lecture_room / studio / workshop) |
| **Equipment** | An item that may be present in a room. | equipment_name (projector, whiteboard, microphone, video camera) |
| **RoomEquipment** | Junction linking rooms to their equipment. | (room_id, equipment_id) |
| **Organization** | A student organisation that books rooms. | org_name |
| **User** | The individual (student) who creates a booking on behalf of an organisation. Minimal personal data. | (identifier only — likely student number or email hash) |
| **Booking** | A reservation of a room for a time period. | start_time, end_time, status (pending / confirmed / cancelled / rejected), cancelled_at, cancel_reason, approval_required (boolean), approval_granted (boolean) |
| **RecurringSeries** | Parent entity for a set of bookings that repeat on a schedule. | recurrence_rule (e.g. "weekly Wednesday"), end_date |
| **BookingOccurrence** | An individual booking that belongs to a recurring series. Supports independent cancellation or rescheduling. | override_start, override_end, occurrence_status (overrides series-level handling) |

## 2. Candidate Relationships

| From | To | Cardinality | Notes |
|---|---|---|---|
| Building | Room | 1 : N | A room belongs to exactly one building. |
| Room | RoomEquipment | 1 : N | A room can have many equipment items. |
| Equipment | RoomEquipment | 1 : N | An equipment type can appear in many rooms. |
| Organization | Booking | 1 : N | An organisation has many bookings. |
| User | Booking | 1 : N | One person creates many bookings. |
| Room | Booking | 1 : N | A room can be booked many times. |
| RecurringSeries | BookingOccurrence | 1 : N | A series owns many occurrences. |
| Booking | BookingOccurrence | 1 : 1 | Each occurrence maps to exactly one concrete booking record (or: BookingOccurrence *is-a* Booking with extra recurrence metadata). |

**Design choice for recurrence**: Either model `BookingOccurrence` as a separate child table of `RecurringSeries`, or fold recurrence fields directly into `Booking` with a nullable `recurring_series_id`. The latter is simpler and preferred for this project — see Assumptions.

## 3. Key Assumptions

1. **Minimal personal data**: A `User` record stores only a student/employee number (or a pseudonymous identifier). No name, email, or phone number is stored unless strictly required for contact about bookings. For the purposes of this project, we assume an opaque user ID is sufficient.

2. **One organisation per booking**: A booking belongs to exactly one organisation. Joint bookings (multiple orgs sharing a room) are not supported.

3. **Booking time granularity**: Bookings are recorded in 30-minute slots or exact timestamps. We assume exact `start_time` / `end_time` timestamps for maximum flexibility.

4. **Overlap prevention is an application concern**: The schema does not enforce non-overlapping bookings declaratively; the application or a stored procedure checks for conflicts before confirming.

5. **Cancellation handling**: Only `cancelled` bookings record `cancelled_at` and `cancel_reason`. `rejected` bookings do not need a reason stored (the system or admin rejects them).

6. **Recurrence model**: We fold recurrence into the `Booking` table with a nullable `recurring_series_id`. All occurrences are materialised as individual `Booking` rows. The `RecurringSeries` table holds the rule. Individual occurrences can override their time (`override_start`, `override_end`) or status independently.

7. **Equipment is a fixed catalogue**: Equipment types are pre-defined (projector, whiteboard, microphone, video camera). Adding new types requires an admin to insert into the `Equipment` table — no free-text entry.

8. **Special access approval**: The `approval_required` flag is set per booking based on the room type or room-level policy. `approval_granted` is set by an admin. Both are nullable booleans — `NULL` means not applicable.

## 4. Unclear / Ambiguous Requirements

| Ambiguity | Interpretation Chosen |
|---|---|
| What constitutes a "user" — is it just a student number, or do we need names, email, phone? | The case says "minimal personal data — only what is needed." We store only a unique identifier (e.g. Aalto student number or a hashed email) and optionally a display name. No contact details. |
| Can a booking span multiple days? | Yes — `start_time` and `end_time` are full timestamps. Multi-day bookings are allowed unless business rules restrict them. |
| Does "special access approval" apply to the room, the booking, or the organisation? | It applies to the booking. Some rooms require approval for any booking; the `approval_required` flag is set when the booking targets such a room. |
| Can equipment be added to a booking, or is it just a room property? | Equipment is a property of the room, not the booking. The reporting requirement "equipment in booked rooms" implies joining through the room. |
| For recurring bookings, what does "managed as a whole" mean? | The `RecurringSeries` table allows operations on the entire series (e.g. cancel all future occurrences). Individual rows can still be modified independently. |
| What happens to cancelled occurrences in a recurring series — do they leave a gap? | Yes. The occurrence remains with status `cancelled`, but other occurrences in the series are unaffected. |
| Should the system track *who* approved or rejected a booking? | The case does not mention this. We do not store an approver field. |

## 5. Likely Application Queries

1. **Bookings per room** — List all bookings (past and upcoming) for a given room, ordered by date.
2. **Most active organisations** — Rank organisations by total number of confirmed bookings in a given time period.
3. **Most used rooms** — Rank rooms by total hours booked (confirmed only) in a given time period.
4. **Equipment in booked rooms** — For a given booking (or set of bookings), list the equipment available in the booked room.
5. **Cancellation counts** — Count cancelled bookings per organisation, room, or time period; optionally average `cancelled_at - created_at` to measure lead time.
6. **Pending approvals** — List all bookings where `approval_required = true` and `approval_granted IS NULL` (awaiting decision).
7. **Room availability search** — Find all rooms of a given type with a given capacity that are free in a specified time window.
8. **Recurring series overview** — For a given recurring series, list all occurrences with their individual statuses and any overrides.
9. **Organisation booking history** — Retrieve all bookings (any status) for a specific organisation within a date range.
10. **Conflict detection** — Find any bookings for the same room whose time intervals overlap (used during booking creation and audit).

# Conceptual Model — University Room Booking System

## 1. Entities

| Entity | Attributes |
|---|---|
| **building** | `id` (PK), `name`, `address` |
| **room** | `id` (PK), `building_id` (FK), `room_number`, `capacity`, `room_type` |
| **equipment** | `id` (PK), `equipment_name` |
| **room_equipment** | `room_id` (PK, FK), `equipment_id` (PK, FK) — linking table |
| **organization** | `id` (PK), `org_name` |
| **app_user** | `id` (PK), `identifier`, `display_name` |
| **recurring_series** | `id` (PK), `recurrence_rule`, `end_date` |
| **booking** | `id` (PK), `room_id` (FK), `organization_id` (FK), `user_id` (FK), `recurring_series_id` (FK, nullable), `start_time`, `end_time`, `status`, `approval_required` (nullable), `approval_granted` (nullable), `cancelled_at` (nullable), `cancel_reason` (nullable), `override_start` (nullable), `override_end` (nullable) |

## 2. Relationships with Cardinalities

- A **building** contains one or more **rooms**; each room belongs to exactly one building **(1 : N)**.
- A **room** may have zero or more equipment items listed through the **room_equipment** junction; each equipment type can appear in many rooms. This is a many-to-many relationship **(M : N)** resolved via the `room_equipment` linking table:
  - A room can be linked to many rows in `room_equipment` **(1 : N)**.
  - An equipment type can be linked to many rows in `room_equipment` **(1 : N)**.
- A **room** hosts zero or more **bookings**; each booking reserves exactly one room **(1 : N)**.
- An **organization** makes zero or more **bookings**; each booking belongs to exactly one organization **(1 : N)**.
- An **app_user** creates zero or more **bookings**; each booking is created by exactly one user **(1 : N)**.
- A **recurring_series** optionally groups zero or more **bookings**; each booking may optionally belong to one recurring series **(1 : N, nullable FK)**. Bookings with a `NULL` `recurring_series_id` are one-off reservations.

## 3. ER Diagram

erDiagram
    Building ||--o{ Room : "has"
    Room ||--o{ RoomEquipment : "has"
    Equipment ||--o{ RoomEquipment : "appears in"
    Room ||--o{ Booking : "hosts"
    Organization ||--o{ Booking : "makes"
    AppUser ||--o{ Booking : "creates"
    RecurringSeries ||--o{ Booking : "groups"

    Building {
        int id PK
        varchar name
        text address
    }

    Room {
        int id PK
        int building_id FK
        varchar room_number
        int capacity
        enum room_type
    }

    Equipment {
        int id PK
        varchar equipment_name UK
    }

    RoomEquipment {
        int room_id PK_FK
        int equipment_id PK_FK
    }

    Organization {
        int id PK
        varchar org_name UK
    }

    AppUser {
        int id PK
        varchar identifier UK
        varchar display_name "nullable"
    }

    RecurringSeries {
        int id PK
        varchar recurrence_rule
        date end_date
    }

    Booking {
        int id PK
        int room_id FK
        int organization_id FK
        int user_id FK
        int recurring_series_id FK "nullable"
        timestamptz start_time
        timestamptz end_time
        enum status
        boolean approval_required "nullable"
        boolean approval_granted "nullable"
        timestamptz cancelled_at "nullable"
        text cancel_reason "nullable"
        timestamptz override_start "nullable"
        timestamptz override_end "nullable"
    }

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

# Design Quality Review

## Redundancy and Anomaly Risks

The `booking` table contains a **redundant relationship between `approval_required` and `approval_granted`**. In the current design, both are independent nullable booleans. This creates a risk of inconsistent states — for example, a booking can hold `approval_required = FALSE` (explicitly not required) while simultaneously storing `approval_granted = TRUE`, which is logically meaningless. The schema relies entirely on application logic to prevent these combinations, and no `CHECK` constraint enforces that `approval_granted` is only set when `approval_required IS TRUE`. A concrete **update anomaly**: if a room's policy changes mid-semester, individual bookings already created for that room could have their `approval_required` column toggled `FALSE` to `TRUE` or vice versa in isolation, without the corresponding `approval_granted` value being updated or reset — leaving bookings in contradictory states that no query can reliably interpret.

## Functional Dependencies

1. **`room_id, start_time → end_time, organization_id, user_id, status`**  
   In the `booking` table, for a given room and a given start time, there is at most one active booking. Assuming no double-booking is enforced at the application level, the combination of room and start time uniquely determines the booking's end time, the organisation making the booking, the user who created it, and its current status.

2. **`building_id, room_number → capacity, room_type`**  
   In the `room` table, a room number is unique within a building (enforced by the `UNIQUE (building_id, room_number)` constraint). Therefore, given a building and a room number, the room's capacity and type are uniquely determined — a particular room cannot have two different capacities or types simultaneously.

## Schema Revision

The schema was kept as-is for the scope of this student project. The anomaly risk around `approval_required` / `approval_granted` is acknowledged, but the nullable-boolean approach was deliberately chosen because it mirrors real-world ambiguity: a booking can be in a state where approval is "not applicable" (both `NULL`), "required but not yet decided" (`TRUE` / `NULL`), and so on. Introducing a separate approval-status entity or a composite type would add complexity disproportionate to a project of this size. A production system would benefit from a `CHECK` constraint such as `CHECK (approval_granted IS NULL OR approval_required IS TRUE)` to close the inconsistency gap, but for the purposes of demonstrating relational design and writing working queries, the risk does not prevent the schema from functioning correctly with well-behaved seed data and application code.

## Privacy and Data Minimisation

The schema follows a data-minimisation approach: the `app_user` table stores only an opaque `identifier` (student/employee number or hashed email) and an optional `display_name`. Fields such as phone number, physical address, date of birth, or emergency contact were intentionally excluded because they are not needed to create or manage room bookings. The optional `cancel_reason` column in `booking` is stored as free-text but only populated when a booking is cancelled — it is not collected for active or completed bookings, and organisations are not required to provide a reason at all (the column is nullable). No automated retention or purging logic is built into the schema itself; in a deployed system, cancelled bookings with their reasons would be subject to a retention policy (e.g. anonymised or deleted after one academic year), but that enforcement would live at the application or database-administration level rather than in the table definitions.

# Short Rationale

## Main Idea

This database design supports a university room booking system in which student organisations reserve rooms for events, meetings, and lectures. The core of the design is the `booking` table, which ties together a room, an organisation, and the individual user who creates the reservation. Supporting tables model the physical campus layout — buildings contain rooms, and rooms may hold catalogue-listed equipment — while small reference tables for organisations and users provide just enough contextual data to make bookings meaningful without drifting into unnecessary personal-data collection. The schema deliberately balances completeness against simplicity: it handles one-off bookings and recurring series, tracks approval workflows, and records cancellations, all while remaining compact enough for a student project.

## Difficult Modeling Decision: Recurring Bookings

The most consequential design choice concerned how to represent recurring bookings. The subject description states that bookings can repeat weekly, that their individual occurrences may be cancelled or rescheduled independently, and that the system must sometimes operate on the series as a whole — for example, cancelling all future occurrences at once. This dual requirement — treat the series as a unit, yet allow per-occurrence overrides — forced a decision between two competing structures.

One option was a two-table design: a `recurring_series` parent table and a separate `booking_occurrence` child table, where each occurrence is structurally distinct from a one-off booking. This approach cleanly separates recurrence metadata from booking data and makes series-wide operations natural, but it creates an awkward asymmetry: a one-off booking is one kind of row, and an occurrence is another kind, even though both represent a reservation of a room at a specific time. A second option — the one ultimately adopted — folds recurrence into the `booking` table itself. A nullable `recurring_series_id` foreign key links individual bookings to their parent series when they belong to one, and two nullable `override_start` and `override_end` columns allow individual occurrences to deviate from the series schedule. One-off bookings simply leave `recurring_series_id` as `NULL`. This unified approach means every reservation, regardless of whether it is part of a series, lives in the same table and shares the same columns. Queries for availability, conflict detection, and reporting treat all bookings uniformly, avoiding the need for `UNION`-based queries over two structurally-similar tables. The trade-off is that series-wide operations — such as deleting a series and all its occurrences — require two `DELETE` statements or application-level logic, but this is a modest cost relative to the simplification gained in everyday querying.

## Choice of Primary Keys

Every table uses `SERIAL` integer surrogate keys as its primary key. This choice was made for consistency, simplicity, and practical join performance. In several places, natural composite keys could have served — for example, `(building_id, room_number)` uniquely identifies a room, and `(room_id, equipment_id)` could serve as the primary key of the linking table `room_equipment` without an additional surrogate column. The latter composite key is in fact used as the primary key of `room_equipment` precisely because the table has no other attributes and the pair naturally defines each row. For entity tables like `room`, `app_user`, and `organization`, however, a surrogate integer key was preferred because these IDs are widely referenced in foreign key columns across the `booking` table. Joining on a single integer column is simpler and more readable than multi-column joins, and a surrogate key remains stable even if the natural attributes change — for instance, a room might be renumbered or an organisation might change its name. The `booking` table itself uses a surrogate `SERIAL` key for the same reason, and because no natural combination of its attributes guarantees uniqueness without additional constraints that are better enforced at the application level.

## Normalisation in Practice: Equipment as a Separate Entity

One clear instance where normalisation shaped the design is the handling of room equipment. The initial subject model described equipment items — projectors, whiteboards, microphones, video cameras — as attributes of a room. A naïve design might store them as comma-separated values in a single `equipment_list` text column on the `room` table, or as a fixed set of boolean columns (`has_projector`, `has_whiteboard`, and so on). Either approach violates first normal form and makes queries about equipment — such as "find all rooms with a projector and a whiteboard" — needlessly awkward. The normalised solution extracts equipment names into their own `equipment` catalogue table and connects rooms to equipment through a `room_equipment` junction table with a composite primary key of `(room_id, equipment_id)`. This three-table structure allows the equipment catalogue to grow without schema changes, supports efficient queries in both directions (rooms for a given piece of equipment, equipment for a given room), and prevents the duplication and update anomalies that would arise if equipment names were repeated across room rows.

## An Assumption in the Face of Incompleteness

The subject description states that bookings require "special access approval" for certain rooms but does not specify whether approval is a property of the room, the booking, or the organisation. The design assumes that approval applies at the booking level: the `approval_required` column is set per booking, presumably based on the room's policy at the time the booking is created. A `NULL` value means approval is not relevant for that booking, `TRUE` means it is needed, and `approval_granted` tracks the decision. This is a pragmatic choice that keeps the schema simple and avoids introducing a separate room-policy table or an organisation-level approval flag. It does, however, leave room for the inconsistency discussed in the Design Quality Review — where `approval_granted` can be set even when `approval_required` is `FALSE` — a trade-off acknowledged and left for application-level enforcement in the scope of this project.