# Design-Quality Review

## Redundancy and anomaly risk

One risk is the pair `approval_required` and `approval_granted` in `booking`. Without checks, the table could store a booking where approval is not required but approval is still marked as granted. That would make the row hard to interpret and could lead to wrong approval reports. We revised the schema instead of leaving this only to application code. `schema.sql` has a check that keeps `approval_granted` null when approval is not required. It also prevents a booking that requires approval from becoming `confirmed` before `approval_granted = true`.

A second related risk is cancellation data. If `cancelled_at` or `cancel_reason` were allowed on non-cancelled rows, cancellation reports would become unreliable. The schema checks that cancellation fields are only used when `status = 'cancelled'`.

A third risk is double-booking a room. If two active bookings for the same room could overlap, the database would allow an impossible schedule even if reports could later detect it. The schema prevents this with a PostgreSQL exclusion constraint for bookings whose status is `pending` or `confirmed`.

## Functional dependencies

1. **`booking.id → room_id, organization_id, user_id, start_time, end_time, status`**  
   The booking id identifies one booking row, so it determines the room, organization, creator, time interval, and status of that booking.

2. **`room.building_id, room.room_number → room.id, capacity, room_type`**  
   Room numbers are unique inside a building, so a building and room number identify one room and its room facts.

3. **`room_id, COALESCE(override_start, start_time), COALESCE(override_end, end_time) → booking.id`** Because the database preserves cancelled and rejected reservations, the same room time-slot can technically map to multiple historical booking IDs over time. However, for any active or pending reservation, a specific room at a specific point in time maps uniquely to a single, distinct booking ID.

These dependencies connect to the anomaly discussion. Booking rows store `room_id` instead of repeating the building name, room number, and capacity, so room facts stay in `room` and booking facts stay in `booking`. The active-booking dependency also explains why overlapping bookings are treated as an integrity problem rather than only as a reporting problem.

## Privacy and data minimization

The user table stores only `identifier` and an optional `display_name`. It does not store phone numbers, home addresses, date of birth, or other personal details because those are not needed for booking rooms. The seed data uses synthetic users such as `user_001` rather than real names or emails. Cancellation reasons are optional free text, so in a real deployment they should be kept short and reviewed by a retention policy, especially if users might type personal information into them.