-- Seed data for University room booking system

-- 1. Buildings
INSERT INTO building (name, address) VALUES
  ('Otakaari 1', 'Otakaari 1, 02150 Espoo'),
  ('Maarintie 8', 'Maarintie 8, 02150 Espoo');

-- 2. Rooms
INSERT INTO room (building_id, room_number, capacity, room_type) VALUES
  (1, 'A101', 30, 'meeting_room'),
  (2, 'A201', 60, 'lecture_room'),
  (1, 'B110', 15, 'workshop'),
  (2, 'M205', 80, 'lecture_room'),
  (2, 'M310', 20, 'studio');

-- 3. Equipment
INSERT INTO equipment (equipment_name) VALUES
  ('Projector'),
  ('Whiteboard'),
  ('Video Conference System'),
  ('3D Printer');

-- 4. Room-Equipment links
INSERT INTO room_equipment (room_id, equipment_id) VALUES
  (1, 1), (1, 2),
  (2, 1), (2, 2), (2, 3),
  (3, 2), (3, 4),
  (4, 1), (4, 2), (4, 3),
  (5, 2);

-- 5. Organizations
INSERT INTO organization (org_name) VALUES
  ('Aalto Game Developers'),
  ('Salsa Club'),
  ('Data Science Guild');

-- 6. Users
INSERT INTO app_user (identifier, display_name) VALUES
  ('user_001', 'Requester 1'),
  ('user_002', 'Requester 2'),
  ('user_003', 'Requester 3');

-- 7. Recurring series
INSERT INTO recurring_series (recurrence_rule, start_date, end_date) VALUES
  ('FREQ=WEEKLY;BYDAY=MO', '2026-02-09', '2026-03-01');

-- 8. Bookings
-- Recurring occurrence 1: confirmed
INSERT INTO booking (room_id, organization_id, user_id, recurring_series_id,
  start_time, end_time, status, approval_required, approval_granted)
VALUES (2, 1, 1, 1,
  '2026-02-09 14:00:00', '2026-02-09 16:00:00',
  'confirmed', FALSE, NULL);

-- Recurring occurrence 2: cancelled
INSERT INTO booking (room_id, organization_id, user_id, recurring_series_id,
  start_time, end_time, status, approval_required, approval_granted,
  cancelled_at, cancel_reason)
VALUES (2, 1, 1, 1,
  '2026-02-16 14:00:00', '2026-02-16 16:00:00',
  'cancelled', FALSE, NULL,
  '2026-02-15 10:30:00', 'Game jam rescheduled');

-- Recurring occurrence 3: confirmed
INSERT INTO booking (room_id, organization_id, user_id, recurring_series_id,
  start_time, end_time, status, approval_required, approval_granted)
VALUES (2, 1, 1, 1,
  '2026-02-23 14:00:00', '2026-02-23 16:00:00',
  'confirmed', FALSE, NULL);

-- Single booking: confirmed, no approval needed
INSERT INTO booking (room_id, organization_id, user_id,
  start_time, end_time, status, approval_required, approval_granted)
VALUES (1, 2, 2,
  '2026-06-04 10:00:00', '2026-06-04 12:00:00',
  'confirmed', FALSE, NULL);

-- Single booking: confirmed, approval required and granted
INSERT INTO booking (room_id, organization_id, user_id,
  start_time, end_time, status, approval_required, approval_granted)
VALUES (4, 3, 3,
  '2026-06-10 09:00:00', '2026-06-10 17:00:00',
  'confirmed', TRUE, TRUE);

-- Single booking: pending, approval not yet reviewed
INSERT INTO booking (room_id, organization_id, user_id,
  start_time, end_time, status, approval_required, approval_granted)
VALUES (5, 2, 2,
  '2026-06-24 13:00:00', '2026-06-24 15:00:00',
  'pending', TRUE, NULL);

-- Single booking: rejected
INSERT INTO booking (room_id, organization_id, user_id,
  start_time, end_time, status, approval_required, approval_granted)
VALUES (3, 1, 1,
  '2026-07-01 08:00:00', '2026-07-01 16:00:00',
  'rejected', TRUE, FALSE);

-- Single booking: cancelled
INSERT INTO booking (room_id, organization_id, user_id,
  start_time, end_time, status, approval_required, approval_granted,
  cancelled_at, cancel_reason)
VALUES (2, 3, 3,
  '2026-08-15 12:00:00', '2026-08-15 14:00:00',
  'cancelled', FALSE, NULL,
  '2026-08-14 09:00:00', 'Speaker cancelled');

-- Single booking: with time override
INSERT INTO booking (room_id, organization_id, user_id,
  start_time, end_time, status, approval_required, approval_granted,
  override_start, override_end)
VALUES (1, 2, 2,
  '2026-06-04 14:00:00', '2026-06-04 16:00:00',
  'confirmed', FALSE, NULL,
  '2026-06-04 15:00:00', '2026-06-04 17:00:00');