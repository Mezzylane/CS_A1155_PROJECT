-- University room booking database
-- PostgreSQL schema

-- Needed for the exclusion constraint that prevents overlapping room bookings.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Stores physical buildings on campus.
CREATE TABLE building (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT NOT NULL
);

-- Stores bookable spaces (rooms) inside a building.
CREATE TABLE room (
    id SERIAL PRIMARY KEY,
    building_id INTEGER NOT NULL REFERENCES building(id) ON DELETE RESTRICT,
    room_number TEXT NOT NULL,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    room_type TEXT NOT NULL CHECK (room_type IN ('meeting_room', 'lecture_room', 'studio', 'workshop')),
    UNIQUE (building_id, room_number)
);

-- Stores the fixed catalogue of equipment types.
CREATE TABLE equipment (
    id SERIAL PRIMARY KEY,
    equipment_name TEXT NOT NULL UNIQUE
);

-- Linking table: which room contains which equipment type (M:N).
CREATE TABLE room_equipment (
    room_id INTEGER NOT NULL REFERENCES room(id) ON DELETE CASCADE,
    equipment_id INTEGER NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
    PRIMARY KEY (room_id, equipment_id)
);

-- Stores student organizations that can book rooms.
CREATE TABLE organization (
    id SERIAL PRIMARY KEY,
    org_name TEXT NOT NULL UNIQUE
);

-- Stores individual users (students) who create bookings.
-- Named "app_user" to avoid collision with the reserved word user.
CREATE TABLE app_user (
    id SERIAL PRIMARY KEY,
    identifier TEXT NOT NULL UNIQUE,
    display_name TEXT
);

-- Stores the recurrence rule for bookings that repeat on a schedule. 
-- Individual occurrences are materialized as rows in the booking table.
CREATE TABLE recurring_series (
    id SERIAL PRIMARY KEY,
    recurrence_rule TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CHECK (end_date >= start_date)
);

-- Core table: stores individual room reservations.
-- Links a room, an organization, and a user creating the booking. 
-- May optionally belong to a recurring series.
CREATE TABLE booking (
    id SERIAL PRIMARY KEY,
    room_id INTEGER NOT NULL REFERENCES room(id) ON DELETE RESTRICT,
    organization_id INTEGER NOT NULL REFERENCES organization(id) ON DELETE RESTRICT,
    user_id INTEGER NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
    recurring_series_id INTEGER REFERENCES recurring_series(id) ON DELETE SET NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL CHECK (end_time > start_time),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'rejected')),
    approval_required BOOLEAN NOT NULL DEFAULT FALSE,
    approval_granted BOOLEAN,
    cancelled_at TIMESTAMP,
    cancel_reason TEXT,
    override_start TIMESTAMP,
    override_end TIMESTAMP,
    -- If approval is not required, there should not be an approval decision.
    CHECK (approval_required OR approval_granted IS NULL),
    -- A booking that requires approval cannot be confirmed before approval is granted.
    CHECK (status <> 'confirmed' OR NOT approval_required OR approval_granted IS TRUE),
    -- Cancellation fields are only used for cancelled bookings.
    CHECK (
        (status = 'cancelled' AND cancelled_at IS NOT NULL)
        OR
        (status <> 'cancelled' AND cancelled_at IS NULL AND cancel_reason IS NULL)
    ),
    -- Override fields must either both be set with a valid range, or both be null.
    CHECK (
        (override_start IS NULL AND override_end IS NULL)
        OR
        (override_start IS NOT NULL AND override_end IS NOT NULL AND override_end > override_start)
    ),
    -- Prevent active double-bookings, accounting for time overrides.
    EXCLUDE USING gist (
        room_id WITH =,
        tsrange(COALESCE(override_start, start_time), COALESCE(override_end, end_time), '[)') WITH &&
    ) WHERE (status IN ('pending', 'confirmed'))
);

CREATE INDEX idx_room_building ON room(building_id);
CREATE INDEX idx_booking_room_time ON booking(room_id, start_time, end_time);
CREATE INDEX idx_booking_organization_time ON booking(organization_id, start_time);
CREATE INDEX idx_booking_recurring_series ON booking(recurring_series_id);
CREATE INDEX idx_booking_user ON booking(user_id);