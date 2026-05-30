# Conceptual Model

## Entities
| Entity | Attributes |
|---|---|
| **building** | `id`, `name`, `address` |
| **room** | `id`, `building_id`, `room_number`, `capacity`, `room_type` |
| **equipment** | `id`, `equipment_name` |
| **room_equipment** | `room_id`, `equipment_id` |
| **organization** | `id`, `org_name` |
| **app_user** | `id`, `identifier`, `display_name` |
| **recurring_series** | `id`, `recurrence_rule`, `start_date`, `end_date` |
| **booking** | `id`, `room_id`, `organization_id`, `user_id`, `recurring_series_id`, `start_time`, `end_time`, `status`, `approval_required`, `approval_granted`, `cancelled_at`, `cancel_reason`, `override_start`, `override_end` |

## Relationships with Cardinalities
- A building contains one or more rooms; each room belongs to exactly one building (1 : N).
- A room may have zero or more equipment items listed through the room_equipment junction; each equipment type can appear in many rooms. Many-to-many relationship (M : N) resolved via the `room_equipment` linking table:
  - A room can be linked to many rows in `room_equipment` (1 : N).
  - An equipment type can be linked to many rows in `room_equipment` (1 : N).
- A room hosts zero or more bookings; each booking reserves exactly one room (1 : N).
- An organization makes zero or more bookings; each booking belongs to exactly one organization (1 : N).
- An app_user creates zero or more bookings; each booking is created by exactly one user (1 : N).
- A recurring_series optionally groups zero or more bookings; each booking may optionally belong to one recurring series (1 : N). Bookings with a `NULL` `recurring_series_id` are one-off reservations.

## ER Diagram
```mermaid
erDiagram
    Building ||--o{ Room : has
    Room ||--o{ RoomEquipment : has
    Equipment ||--o{ RoomEquipment : appears_in
    Room ||--o{ Booking : hosts
    Organization ||--o{ Booking : makes
    AppUser ||--o{ Booking : creates
    RecurringSeries |o--o{ Booking : groups
    Building {
        int id PK
        text name
        text address
    }
    Room {
        int id PK
        int building_id FK
        text room_number
        int capacity
        text room_type
    }
    Equipment {
        int id PK
        text equipment_name
    }
    RoomEquipment {
        int room_id PK_FK
        int equipment_id PK_FK
    }
    Organization {
        int id PK
        text org_name
    }
    AppUser {
        int id PK
        text identifier
        text display_name "nullable"
    }
    RecurringSeries {
        int id PK
        text recurrence_rule
        date start_date
        date end_date
    }
    Booking {
        int id PK
        int room_id FK
        int organization_id FK
        int user_id FK
        int recurring_series_id FK "nullable"
        timestamp start_time
        timestamp end_time
        text status
        boolean approval_required
        boolean approval_granted "nullable"
        timestamp cancelled_at "nullable"
        text cancel_reason "nullable"
        timestamp override_start "nullable"
        timestamp override_end "nullable"
    }
```