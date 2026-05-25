-- ============================================================
-- Application Queries — University Room Booking System
-- ============================================================

-- Query 1: Bookings per room — List all bookings for room A201,
--          ordered by start time.
SELECT
    b.id              AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    b.status,
    o.org_name
FROM booking b
JOIN room r         ON b.room_id = r.id
JOIN organization o ON b.organization_id = o.id
WHERE r.room_number = 'A201'
ORDER BY b.start_time DESC;

-- Query 2: Most active organisations — Rank organisations by
--          number of confirmed bookings, showing the top 3.
SELECT
    o.org_name,
    COUNT(b.id) AS confirmed_bookings
FROM booking b
JOIN organization o ON b.organization_id = o.id
WHERE b.status = 'confirmed'
GROUP BY o.org_name
ORDER BY confirmed_bookings DESC
LIMIT 3;

-- Query 3: Most used rooms — Rank rooms by total hours booked
--          (confirmed only), showing the top 3.
SELECT
    r.room_number,
    bld.name                                 AS building,
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS total_hours
FROM booking b
JOIN room r     ON b.room_id = r.id
JOIN building bld ON r.building_id = bld.id
WHERE b.status = 'confirmed'
GROUP BY r.room_number, bld.name
ORDER BY total_hours DESC
LIMIT 3;

-- Query 4: Equipment in booked rooms — For a specific booking (id = 5),
--          list the equipment available in the booked room.
SELECT
    b.id            AS booking_id,
    r.room_number,
    e.equipment_name
FROM booking b
JOIN room r             ON b.room_id = r.id
JOIN room_equipment re  ON r.id = re.room_id
JOIN equipment e        ON re.equipment_id = e.id
WHERE b.id = 5;

-- Query 5: Cancellation counts — Count cancelled bookings per
--          organisation.
SELECT
    o.org_name,
    COUNT(b.id) AS cancelled_bookings
FROM booking b
JOIN organization o ON b.organization_id = o.id
WHERE b.status = 'cancelled'
GROUP BY o.org_name
ORDER BY cancelled_bookings DESC;

-- Query 6: Pending approvals — List all bookings that require
--          approval but have not yet been reviewed.
SELECT
    b.id            AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    o.org_name,
    u.display_name  AS requested_by
FROM booking b
JOIN room r         ON b.room_id = r.id
JOIN organization o ON b.organization_id = o.id
JOIN app_user u     ON b.user_id = u.id
WHERE b.approval_required = TRUE
  AND b.approval_granted IS NULL
ORDER BY b.start_time;

-- Query 7: Organisation booking history — Retrieve all bookings
--          for the Photography Club in 2026.
SELECT
    b.id          AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    b.status,
    u.display_name AS booked_by
FROM booking b
JOIN organization o ON b.organization_id = o.id
JOIN room r         ON b.room_id = r.id
JOIN app_user u     ON b.user_id = u.id
WHERE o.org_name = 'Photography Club'
  AND b.start_time >= '2026-01-01'
  AND b.start_time <  '2027-01-01'
ORDER BY b.start_time;

-- Query 8: Conflict detection — Find bookings for the same room
--          whose time intervals overlap.
SELECT
    r.room_number,
    a.id          AS booking_a,
    a.start_time  AS a_start,
    a.end_time    AS a_end,
    b.id          AS booking_b,
    b.start_time  AS b_start,
    b.end_time    AS b_end
FROM booking a
JOIN booking b ON a.room_id = b.room_id
              AND a.id < b.id
              AND a.start_time < b.end_time
              AND b.start_time < a.end_time
JOIN room r ON a.room_id = r.id
ORDER BY r.room_number, a.start_time;