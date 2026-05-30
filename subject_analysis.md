# Subject Analysis

## Candidate Subjects

| Subject | Description | Main Attributes |
|---|---|---|
| **Building** | A physical building on campus. | name, address |
| **Room** | A bookable space inside a building. | room number, capacity, room type |
| **Equipment** | An item that may be present in a room. | equipment name |
| **RoomEquipment** | The link between rooms and equipment. | room id, equipment id |
| **Organization** | A student organization that books rooms. | organization name |
| **AppUser** | The person who creates a booking for an organization. | identifier, optional display name |
| **RecurringSeries** | Parent entity for a set of repeated bookings. | recurrence rule, start date, end date |
| **Booking** | A reservation of a room for a time period. | room, organization, user, start time, end time, status, approval fields, cancellation fields, optional time override |

## Candidate Relationships

| Relationship | Cardinality | Notes |
|---|---|---|
| Building to room | 1 : N | A room belongs to one building. A building can contain many rooms. |
| Room to equipment | M : N | Implemented with `room_equipment`. A room can have many equipment items; an equipment type can appear in many rooms. |
| Room to equipment via room_equipment | 1 : N | A room can be linked to many rows in `room_equipment`. |
| Equipment to room_equipment | 1 : N | An equipment type can be linked to many rows in `room_equipment`. |
| Room to booking | 1 : N | A room can be booked many times. A booking reserves exactly one room. |
| Organization to booking | 1 : N | An organization has many bookings. Each booking belongs to one organization. |
| AppUser to booking | 1 : N | One person creates many bookings. Each booking is created by one user. |
| Recurring series to booking | optional 1 : N | A booking can be a one-off booking or part of one recurring series. |

## Key Assumptions

1. A booking belongs to one organization only. Joint bookings are outside this design.
2. Each booking uses exact start and end timestamps. The schema does not force 30-minute slots.
3. Equipment is a property of the room, not of a single booking.
4. Recurring bookings are stored as separate booking rows. The `recurring_series` row stores the repeating rule and date range, while each occurrence stores its own actual start and end time. An individual occurrence can also be moved to a different time using override start and end fields, without affecting the rest of the series.
5. A cancelled booking remains in the database with `status = 'cancelled'`, `cancelled_at`, and an optional reason. This keeps booking history available for reports.
6. Approval is stored on the booking because approval can depend on the room, date, organization, or other local rules. The schema prevents impossible combinations such as a granted approval when approval is not required.
7. The database prevents overlapping active bookings in the same room. The normal booking workflow should still check availability before trying to insert or confirm a booking.
8. User data is kept small. The schema stores a unique identifier and an optional display name only.

## Ambiguous points and chosen interpretation

| Ambiguity | Interpretation chosen |
|---|---|
| What personal data is needed for users? | Only a unique identifier is required. A display name is optional and only helps with readable reports. |
| Are approval details mandatory? | No. The design supports approval when needed, but ordinary bookings can have `approval_required = false`. |
| How should recurring bookings be represented? | A recurring series has a rule and date range, and every generated occurrence is stored as a normal booking row. This makes cancellation and reporting simple. |
| Can an occurrence in a recurring series be changed by itself? | Yes. Since each occurrence is a booking row, its time or status can be changed without changing the whole series. |
| Should the database store an approver or rejection reason? | Not in this version. The case does not clearly require it, so the design stays smaller. |
| Should the database delete old cancelled bookings? | No automatic deletion is included. Retention would be a policy decision outside this project. |

## Application queries covered by `queries.sql`

1. List bookings for a given room in a date range.
2. Find rooms of a given type and minimum capacity that are free in a given time window.
3. Summarize room usage, including confirmed hours and cancellation counts.
4. List the equipment available for the room used by a booking.
5. List bookings that still need an approval decision.
6. Show one organization's booking history in a date range.
7. List which equipment types appear most often in rooms that have had confirmed bookings.
8. Find active bookings that overlap in the same room.