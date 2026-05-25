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