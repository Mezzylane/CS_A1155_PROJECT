-- University room booking system application queries

-- Query 1: List all bookings for room A201, ordered by start time.
SELECT
    b.id AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    b.status,
    o.org_name
FROM booking AS b
JOIN room AS r ON b.room_id = r.id
JOIN organization AS o ON b.organization_id = o.id
WHERE r.room_number = 'A201'
ORDER BY b.start_time DESC;

-- Query 2: Rank organizations by number of confirmed bookings, showing the top 3.
SELECT
    o.org_name,
    COUNT(b.id) AS confirmed_bookings
FROM booking AS b
JOIN organization AS o ON b.organization_id = o.id
WHERE b.status = 'confirmed'
GROUP BY o.org_name
ORDER BY confirmed_bookings DESC
LIMIT 3;

-- Query 3: Rank rooms by total hours booked (confirmed only), showing the top 3.
SELECT
    r.room_number,
    bld.name AS building,
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS total_hours
FROM booking AS b
JOIN room AS r ON b.room_id = r.id
JOIN building AS bld ON r.building_id = bld.id
WHERE b.status = 'confirmed'
GROUP BY r.room_number, bld.name
ORDER BY total_hours DESC
LIMIT 3;

-- Query 4: For a specific booking (id = 5), list the equipment available in the booked room.
SELECT
    b.id AS booking_id,
    r.room_number,
    e.equipment_name
FROM booking AS b
JOIN room AS r ON b.room_id = r.id
JOIN room_equipment AS re ON r.id = re.room_id
JOIN equipment AS e ON re.equipment_id = e.id
WHERE b.id = 5;

-- Query 5: Count cancelled bookings per organization.
SELECT
    o.org_name,
    COUNT(b.id) AS cancelled_bookings
FROM booking AS b
JOIN organization AS o ON b.organization_id = o.id
WHERE b.status = 'cancelled'
GROUP BY o.org_name
ORDER BY cancelled_bookings DESC;

-- Query 6: List all bookings that require approval but have not yet been reviewed.
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
ORDER BY b.start_time;

-- Query 7: Retrieve all bookings for the Photography Club in 2026.
SELECT
    b.id AS booking_id,
    r.room_number,
    b.start_time,
    b.end_time,
    b.status,
    u.display_name AS booked_by
FROM booking AS b
JOIN organization AS o ON b.organization_id = o.id
JOIN room AS r ON b.room_id = r.id
JOIN app_user AS u ON b.user_id = u.id
WHERE o.org_name = 'Salsa Club'
  AND b.start_time >= '2026-01-01'
  AND b.start_time < '2027-01-01'
ORDER BY b.start_time;

-- Query 8: Find bookings for the same room whose time intervals overlap.
SELECT 
    r.room_number,
    b1.id AS booking_1,
    b1.start_time AS b1_start,
    b1.end_time AS b1_end,
    b2.id AS booking_2,
    b2.start_time AS b2_start,
    b2.end_time AS b2_end
FROM booking AS b1
JOIN booking AS b2 ON b1.room_id = b2.room_id AND b1.id < b2.id AND b1.start_time < b2.end_time AND b2.start_time < b1.end_time
JOIN room AS r ON b1.room_id = r.id 
ORDER BY r.room_number, b1.start_time;