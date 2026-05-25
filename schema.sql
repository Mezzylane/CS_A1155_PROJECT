-- University Room Booking System

-- Custom enum types
CREATE TYPE room_type AS ENUM ('meeting_room', 'lecture_room', 'studio', 'workshop');

CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'cancelled', 'rejected');

-- Stores physical buildings on campus.
CREATE TABLE building (
    id      SERIAL       PRIMARY KEY,
    name    VARCHAR(255) NOT NULL,
    address TEXT         NOT NULL
);

-- Stores bookable spaces (rooms) inside a building.
CREATE TABLE room (
    id          SERIAL       PRIMARY KEY,
    building_id INTEGER      NOT NULL REFERENCES building(id) ON DELETE RESTRICT,
    room_number VARCHAR(50)  NOT NULL,
    capacity    INTEGER      NOT NULL CHECK (capacity > 0),
    room_type   room_type    NOT NULL,
    UNIQUE (building_id, room_number)
);

-- Stores the fixed catalogue of equipment types.
CREATE TABLE equipment (
    id             SERIAL       PRIMARY KEY,
    equipment_name VARCHAR(100) NOT NULL UNIQUE
);

-- Linking table: which room contains which equipment type (M:N).
CREATE TABLE room_equipment (
    room_id      INTEGER NOT NULL REFERENCES room(id)      ON DELETE CASCADE,
    equipment_id INTEGER NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
    PRIMARY KEY (room_id, equipment_id)
);

-- Stores student organisations that can book rooms.
CREATE TABLE organization (
    id       SERIAL       PRIMARY KEY,
    org_name VARCHAR(255) NOT NULL UNIQUE
);

-- Stores individual users (students) who create bookings.
-- Named "app_user" to avoid collision with the reserved word "user".
CREATE TABLE app_user (
    id           SERIAL       PRIMARY KEY,
    identifier   VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(255)
);

-- Stores the recurrence rule for bookings that repeat on a schedule. 
-- Individual occurrences are materialised as rows in the booking table.
CREATE TABLE recurring_series (
    id              SERIAL       PRIMARY KEY,
    recurrence_rule VARCHAR(255) NOT NULL,
    end_date        DATE         NOT NULL
);

-- Core table: stores individual room reservations.
-- Links a room, an organisation, and a user creating the booking. 
-- May optionally belong to a recurring series.
CREATE TABLE booking (
    id                  SERIAL         PRIMARY KEY,
    room_id             INTEGER        NOT NULL REFERENCES room(id)           ON DELETE RESTRICT,
    organization_id     INTEGER        NOT NULL REFERENCES organization(id)   ON DELETE RESTRICT,
    user_id             INTEGER        NOT NULL REFERENCES app_user(id)       ON DELETE RESTRICT,
    recurring_series_id INTEGER                                             REFERENCES recurring_series(id) ON DELETE SET NULL,
    start_time          TIMESTAMPTZ    NOT NULL,
    end_time            TIMESTAMPTZ    NOT NULL CHECK (end_time > start_time),
    status              booking_status NOT NULL DEFAULT 'pending',
    approval_required   BOOLEAN,
    approval_granted    BOOLEAN,
    cancelled_at        TIMESTAMPTZ,
    cancel_reason       TEXT,
    override_start      TIMESTAMPTZ,
    override_end        TIMESTAMPTZ    CHECK (override_end IS NULL OR override_start IS NULL OR override_end > override_start)
);