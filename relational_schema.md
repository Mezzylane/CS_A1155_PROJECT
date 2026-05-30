# Relational Schema

The schema is written for PostgreSQL. It uses `SERIAL` integer primary keys, `TEXT` columns for names and labels, and `CHECK` constraints for controlled values such as room type and booking status. It also uses PostgreSQL's `btree_gist` extension for the room-overlap exclusion constraint. The table definitions below match `schema.sql`.

## `building`

Stores campus buildings.

| Column | Type | Constraints |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `name` | `TEXT` | not null |
| `address` | `TEXT` | not null |

## `room`

Stores bookable rooms.

| Column | Type | Constraints |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `building_id` | `INTEGER` | not null, foreign key to `building(id)` |
| `room_number` | `TEXT` | not null |
| `capacity` | `INTEGER` | not null, `capacity > 0` |
| `room_type` | `TEXT` | not null, one of `meeting_room`, `lecture_room`, `studio`, `workshop` |

`UNIQUE (building_id, room_number)` means the same room number can appear in different buildings, but not twice in the same building.

## `equipment`

Stores the equipment catalogue.

| Column | Type | Constraints |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `equipment_name` | `TEXT` | not null, unique |

The seed data uses Projector, Whiteboard, Video Conference System, and 3D Printer.

## `room_equipment`

Links rooms to equipment. This resolves the many-to-many relationship.

| Column | Type | Constraints |
|---|---|---|
| `room_id` | `INTEGER` | not null, foreign key to `room(id)`, `ON DELETE CASCADE` |
| `equipment_id` | `INTEGER` | not null, foreign key to `equipment(id)`, `ON DELETE CASCADE` |

The primary key is `(room_id, equipment_id)`, so the same equipment type cannot be listed twice for the same room.

## `organization`

Stores student organizations.

| Column | Type | Constraints |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `org_name` | `TEXT` | not null, unique |

## `app_user`

Stores the person who creates a booking. The table is called `app_user` because `user` is a PostgreSQL keyword.

| Column | Type | Constraints |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `identifier` | `TEXT` | not null, unique |
| `display_name` | `TEXT` | nullable |

## `recurring_series`

Stores the rule for repeated bookings.

| Column | Type | Constraints |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `recurrence_rule` | `TEXT` | not null |
| `start_date` | `DATE` | not null |
| `end_date` | `DATE` | not null, must be on or after `start_date` |

The actual occurrences are stored in `booking`. This makes each occurrence easy to cancel, reject, or report on, while the series row keeps the overall recurrence rule and date range.

## `booking`

Stores each room reservation.

| Column | Type | Constraints / meaning |
|---|---|---|
| `id` | `SERIAL` | primary key |
| `room_id` | `INTEGER` | not null, foreign key to `room(id)` |
| `organization_id` | `INTEGER` | not null, foreign key to `organization(id)` |
| `user_id` | `INTEGER` | not null, foreign key to `app_user(id)` |
| `recurring_series_id` | `INTEGER` | nullable, foreign key to `recurring_series(id)`, `ON DELETE SET NULL` |
| `start_time` | `TIMESTAMP` | not null |
| `end_time` | `TIMESTAMP` | not null, must be after `start_time` |
| `status` | `TEXT` | not null, one of `pending`, `confirmed`, `cancelled`, `rejected` |
| `approval_required` | `BOOLEAN` | not null, default false |
| `approval_granted` | `BOOLEAN` | nullable |
| `cancelled_at` | `TIMESTAMP` | nullable, required only when status is `cancelled` |
| `cancel_reason` | `TEXT` | nullable, allowed only when status is `cancelled` |
| `override_start` | `TIMESTAMP` | nullable, overrides `start_time` for a moved occurrence |
| `override_end` | `TIMESTAMP` | nullable, overrides `end_time` for a moved occurrence, must be after `override_start` if both are set |

Important checks in `schema.sql`:

- `end_time > start_time`.
- If both override fields are set, `override_end` must be after `override_start`.
- If approval is not required, `approval_granted` must be null.
- A booking that requires approval cannot be confirmed unless approval has been granted.
- Cancellation fields are only used for cancelled bookings.
- Active bookings for the same room cannot overlap. This is enforced with a PostgreSQL exclusion constraint over `room_id` and the effective time range, using `override_start`/`override_end` when set and falling back to `start_time`/`end_time` otherwise.

## Foreign key summary

| Child table | Column | Parent table | Delete behavior |
|---|---|---|---|
| `room` | `building_id` | `building` | restrict |
| `room_equipment` | `room_id` | `room` | cascade |
| `room_equipment` | `equipment_id` | `equipment` | cascade |
| `booking` | `room_id` | `room` | restrict |
| `booking` | `organization_id` | `organization` | restrict |
| `booking` | `user_id` | `app_user` | restrict |
| `booking` | `recurring_series_id` | `recurring_series` | set null |

Indexes are added for the most common joins and filters: room/time searches, organization history, user lookups, and recurring-series lookups. The exclusion constraint also supports the no-overlap rule for active bookings.