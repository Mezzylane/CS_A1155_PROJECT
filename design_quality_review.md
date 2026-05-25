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