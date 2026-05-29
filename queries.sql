-- Application queries for the room booking database

-- Query 1: Bookings for room A201 in Maarintie 8 in 2026, ordered by start time.
SELECT
    b.id AS booking_id,
    bld.name AS building,
    r.room_number,
    b.start_time,
    b.end_time,
    b.status,
    o.org_name
FROM booking AS b
JOIN room AS r ON b.room_id = r.id
JOIN organization AS o ON b.organization_id = o.id
JOIN building AS bld ON r.building_id = bld.id
WHERE bld.name = 'Maarintie 8'
  AND r.room_number = 'A201'
  AND b.start_time >= TIMESTAMP '2026-01-01 00:00:00'
  AND b.start_time <  TIMESTAMP '2027-01-01 00:00:00'
ORDER BY b.start_time;

-- Query 2: Find lecture rooms with capacity at least 50 that are free on 2026-06-10 from 09:00 to 12:00.
SELECT
    r.id AS room_id,
    bld.name AS building,
    r.room_number,
    r.capacity,
    r.room_type
FROM room AS r
JOIN building AS bld ON r.building_id = bld.id
WHERE r.room_type = 'lecture_room'
  AND r.capacity >= 50
  AND NOT EXISTS (
      SELECT 1
      FROM booking AS b
      WHERE b.room_id = r.id
        AND b.status IN ('pending', 'confirmed')
        AND COALESCE(b.override_start, b.start_time) < TIMESTAMP '2026-06-10 12:00:00'
        AND TIMESTAMP '2026-06-10 09:00:00' < COALESCE(b.override_end, b.end_time)
  )
ORDER BY bld.name, r.room_number;

-- Query 3: Room usage summary for 2026, including confirmed hours and cancellation count.
SELECT
    bld.name AS building,
    r.room_number,
    COUNT(b.id) AS total_bookings,
    COUNT(b.id) FILTER (WHERE b.status = 'cancelled') AS cancelled_bookings,
    ROUND(
        COALESCE(
            SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)
                FILTER (WHERE b.status = 'confirmed'),
            0
        )::numeric,
        1
    ) AS confirmed_hours
FROM room AS r
JOIN building AS bld ON r.building_id = bld.id
LEFT JOIN booking AS b
    ON b.room_id = r.id
   AND b.start_time >= TIMESTAMP '2026-01-01 00:00:00'
   AND b.start_time <  TIMESTAMP '2027-01-01 00:00:00'
GROUP BY bld.name, r.room_number
ORDER BY confirmed_hours DESC, total_bookings DESC, bld.name, r.room_number;

-- Query 4: For booking 5, list the equipment available in the booked room.
SELECT
    b.id AS booking_id,
    r.room_number,
    e.equipment_name
FROM booking AS b
JOIN room AS r ON b.room_id = r.id
JOIN room_equipment AS re ON r.id = re.room_id
JOIN equipment AS e ON re.equipment_id = e.id
WHERE b.id = 5
ORDER BY e.equipment_name;

-- Query 5: Count cancelled bookings per organization.
SELECT
    o.org_name,
    COUNT(b.id) AS cancelled_bookings
FROM booking AS b
JOIN organization AS o ON b.organization_id = o.id
WHERE b.status = 'cancelled'
GROUP BY o.org_name
ORDER BY cancelled_bookings DESC;

-- Query 6: List bookings that require approval and have not yet been reviewed.
SELECT
    b.id AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    o.org_name,
    u.display_name AS requested_by
FROM booking AS b
JOIN room AS r ON b.room_id = r.id
JOIN organization AS o ON b.organization_id = o.id
JOIN app_user AS u ON b.user_id = u.id
WHERE b.approval_required = TRUE
  AND b.approval_granted IS NULL
  AND b.status = 'pending'
ORDER BY b.start_time;

-- Query 7: Booking history for Salsa Club in 2026.
SELECT
    b.id AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    b.status,
    u.display_name AS requested_by
FROM booking AS b
JOIN organization AS o ON b.organization_id = o.id
JOIN room AS r ON b.room_id = r.id
JOIN app_user AS u ON b.user_id = u.id
WHERE o.org_name = 'Salsa Club'
  AND b.start_time >= TIMESTAMP '2026-01-01 00:00:00'
  AND b.start_time <  TIMESTAMP '2027-01-01 00:00:00'
ORDER BY b.start_time;

-- Query 8: Check whether any active bookings overlap in the same room.
-- Expected with the seed data: no rows, because the schema prevents active overlaps.
SELECT
    r.room_number,
    b1.id AS booking_1,
    b1.start_time AS booking_1_start,
    b1.end_time AS booking_1_end,
    b2.id AS booking_2,
    b2.start_time AS booking_2_start,
    b2.end_time AS booking_2_end
FROM booking AS b1
JOIN booking AS b2
    ON b1.room_id = b2.room_id
   AND b1.id < b2.id
   AND b1.status IN ('pending', 'confirmed')
   AND b2.status IN ('pending', 'confirmed')
   AND b1.start_time < b2.end_time
   AND b2.start_time < b1.end_time
JOIN room AS r ON b1.room_id = r.id
ORDER BY r.room_number, b1.start_time;