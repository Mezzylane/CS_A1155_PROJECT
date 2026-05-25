-- ============================================================
-- Seed data for University Room Booking System
-- ============================================================

-- -----------------------------------------------------------
-- 1. Buildings
-- -----------------------------------------------------------
INSERT INTO building (id, name, address) VALUES
  (1, 'Otakaari 1',    'Otakaari 1, 02150 Espoo'),
  (2, 'Maarintie 8',   'Maarintie 8, 02150 Espoo');

SELECT setval(pg_get_serial_sequence('building', 'id'), 2);

-- -----------------------------------------------------------
-- 2. Rooms
-- -----------------------------------------------------------
INSERT INTO room (id, building_id, room_number, capacity, room_type) VALUES
  (1, 1, 'A101',  30,  'meeting_room'),
  (2, 1, 'A201',  60,  'lecture_room'),
  (3, 1, 'B110',  15,  'workshop'),
  (4, 2, 'M205',  80,  'lecture_room'),
  (5, 2, 'M310',  20,  'studio');

SELECT setval(pg_get_serial_sequence('room', 'id'), 5);

-- -----------------------------------------------------------
-- 3. Equipment
-- -----------------------------------------------------------
INSERT INTO equipment (id, equipment_name) VALUES
  (1, 'Projector'),
  (2, 'Whiteboard'),
  (3, 'Video Conferencing System'),
  (4, '3D Printer');

SELECT setval(pg_get_serial_sequence('equipment', 'id'), 4);

-- -----------------------------------------------------------
-- 4. Room-Equipment links
-- -----------------------------------------------------------
INSERT INTO room_equipment (room_id, equipment_id) VALUES
  (1, 1), (1, 2),                -- A101: Projector, Whiteboard
  (2, 1), (2, 2), (2, 3),        -- A201: Projector, Whiteboard, VC
  (3, 2), (3, 4),                -- B110: Whiteboard, 3D Printer
  (4, 1), (4, 2), (4, 3),        -- M205: Projector, Whiteboard, VC
  (5, 2);                        -- M310: Whiteboard

-- -----------------------------------------------------------
-- 5. Organizations
-- -----------------------------------------------------------
INSERT INTO organization (id, org_name) VALUES
  (1, 'Aalto Game Developers'),
  (2, 'Photography Club'),
  (3, 'Data Science Guild');

SELECT setval(pg_get_serial_sequence('organization', 'id'), 3);

-- -----------------------------------------------------------
-- 6. Users
-- -----------------------------------------------------------
INSERT INTO app_user (id, identifier, display_name) VALUES
  (1, 'matti.meikäläinen@aalto.fi', 'Matti Meikäläinen'),
  (2, 'liisa.virtanen@aalto.fi',    'Liisa Virtanen'),
  (3, 'arif.nurmi@aalto.fi',        'Arif Nurmi');

SELECT setval(pg_get_serial_sequence('app_user', 'id'), 3);

-- -----------------------------------------------------------
-- 7. Recurring series
-- -----------------------------------------------------------
INSERT INTO recurring_series (id, recurrence_rule, end_date) VALUES
  (1, 'FREQ=WEEKLY;BYDAY=MO', '2026-03-01');

SELECT setval(pg_get_serial_sequence('recurring_series', 'id'), 1);

-- -----------------------------------------------------------
-- 8. Bookings
-- -----------------------------------------------------------

-- 8a. Recurring series #1 – 3 occurrences (Mondays)
-- Occurrence 1: confirmed
INSERT INTO booking (id, room_id, organization_id, user_id,
                     recurring_series_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted)
VALUES
  (1, 2, 1, 1, 1,
   '2026-02-09 14:00:00+02', '2026-02-09 16:00:00+02',
   'confirmed', FALSE, NULL);

-- Occurrence 2: cancelled
INSERT INTO booking (id, room_id, organization_id, user_id,
                     recurring_series_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted,
                     cancelled_at,         cancel_reason)
VALUES
  (2, 2, 1, 1, 1,
   '2026-02-16 14:00:00+02', '2026-02-16 16:00:00+02',
   'cancelled', FALSE, NULL,
   '2026-02-15 10:30:00+02', 'Game jam rescheduled to next month');

-- Occurrence 3: confirmed
INSERT INTO booking (id, room_id, organization_id, user_id,
                     recurring_series_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted)
VALUES
  (3, 2, 1, 1, 1,
   '2026-02-23 14:00:00+02', '2026-02-23 16:00:00+02',
   'confirmed', FALSE, NULL);

-- 8b. Single booking – confirmed, no approval needed
INSERT INTO booking (id, room_id, organization_id, user_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted)
VALUES
  (4, 1, 2, 2,
   '2026-06-04 10:00:00+03', '2026-06-04 12:00:00+03',
   'confirmed', FALSE, NULL);

-- 8c. Single booking – confirmed, approval required & granted
INSERT INTO booking (id, room_id, organization_id, user_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted)
VALUES
  (5, 4, 3, 3,
   '2026-06-10 09:00:00+03', '2026-06-10 17:00:00+03',
   'confirmed', TRUE, TRUE);

-- 8d. Single booking – pending, approval required (not yet reviewed)
INSERT INTO booking (id, room_id, organization_id, user_id,
                     start_time,           end_time,
                     status,    approval_required, approval_granted)
VALUES
  (6, 5, 2, 2,
   '2026-06-24 13:00:00+03', '2026-06-24 15:00:00+03',
   'pending', TRUE, NULL);

-- 8e. Single booking – rejected
INSERT INTO booking (id, room_id, organization_id, user_id,
                     start_time,           end_time,
                     status,    approval_required, approval_granted)
VALUES
  (7, 3, 1, 1,
   '2026-07-01 08:00:00+03', '2026-07-01 16:00:00+03',
   'rejected', TRUE, FALSE);

-- 8f. Single booking – cancelled (standalone, no series)
INSERT INTO booking (id, room_id, organization_id, user_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted,
                     cancelled_at,         cancel_reason)
VALUES
  (8, 2, 3, 3,
   '2026-08-15 12:00:00+03', '2026-08-15 14:00:00+03',
   'cancelled', FALSE, NULL,
   '2026-08-14 09:00:00+03', 'Speaker cancelled — will reschedule');

-- 8g. Single booking with time override – confirmed
INSERT INTO booking (id, room_id, organization_id, user_id,
                     start_time,           end_time,
                     status,      approval_required, approval_granted,
                     override_start,              override_end)
VALUES
  (9, 1, 2, 2,
   '2026-06-04 14:00:00+03', '2026-06-04 16:00:00+03',
   'confirmed', FALSE, NULL,
   '2026-06-04 15:00:00+03', '2026-06-04 17:00:00+03');

SELECT setval(pg_get_serial_sequence('booking', 'id'), 9);