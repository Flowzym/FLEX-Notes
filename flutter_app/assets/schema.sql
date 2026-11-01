-- Flutter schema 1. The prototype's proposed schema remains untouched.
-- One workspace per database. No invented public key or pairing credentials.
CREATE TABLE devices (id TEXT PRIMARY KEY);
CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE pupils (
 id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 80),
 color INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
 revision INTEGER NOT NULL CHECK(revision > 0)
);
CREATE TABLE orga (
 id TEXT PRIMARY KEY, pupil_id TEXT REFERENCES pupils(id),
 title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 160),
 body TEXT NOT NULL, is_task INTEGER NOT NULL CHECK(is_task IN (0,1)),
 done INTEGER NOT NULL CHECK(done IN (0,1)), due_date TEXT,
 reminder_at_utc TEXT, reminder_zone TEXT NOT NULL,
 reminder_state TEXT NOT NULL CHECK(reminder_state IN ('none','planned','acknowledged','cancelled')),
 needs_completion INTEGER NOT NULL CHECK(needs_completion IN (0,1)),
 revision INTEGER NOT NULL CHECK(revision>0), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL,
 CHECK(is_task=1 OR (done=0 AND due_date IS NULL)),
 CHECK(done=0 OR reminder_state!='planned'),
 CHECK((reminder_at_utc IS NULL AND reminder_state='none') OR (reminder_at_utc IS NOT NULL AND reminder_state!='none')),
 CHECK(due_date IS NULL OR (length(due_date)=10 AND due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'))
);
CREATE TABLE orga_items (
 id TEXT PRIMARY KEY, orga_id TEXT NOT NULL REFERENCES orga(id),
 position INTEGER NOT NULL CHECK(position>=0), text TEXT NOT NULL CHECK(length(trim(text))>0),
 checked INTEGER NOT NULL CHECK(checked IN (0,1)), UNIQUE(orga_id,position)
);
CREATE TABLE drafts (
 id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, base_revision INTEGER NOT NULL CHECK(base_revision>=0),
 payload TEXT NOT NULL CHECK(json_valid(payload)), updated_at_utc TEXT NOT NULL
);
CREATE TABLE revisions (
 id TEXT PRIMARY KEY, entity_kind TEXT NOT NULL, entity_id TEXT NOT NULL,
 base_revision INTEGER NOT NULL CHECK(base_revision>=0), revision INTEGER NOT NULL CHECK(revision=base_revision+1),
 before_payload TEXT CHECK(before_payload IS NULL OR json_valid(before_payload)),
 after_payload TEXT NOT NULL CHECK(json_valid(after_payload)), captured_at_utc TEXT NOT NULL,
 device_id TEXT NOT NULL REFERENCES devices(id), UNIQUE(entity_kind,entity_id,revision)
);
CREATE TABLE operations (
 id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id),
 sequence INTEGER NOT NULL CHECK(sequence>0), protocol_version INTEGER NOT NULL CHECK(protocol_version=1),
 revision_id TEXT NOT NULL REFERENCES revisions(id), payload TEXT NOT NULL CHECK(json_valid(payload)), UNIQUE(device_id,sequence)
);
CREATE TABLE outbox (operation_id TEXT PRIMARY KEY REFERENCES operations(id));
CREATE TABLE preferences (key TEXT PRIMARY KEY, payload TEXT NOT NULL CHECK(json_valid(payload)));
CREATE TABLE legacy_backups (id TEXT PRIMARY KEY, original_json TEXT NOT NULL CHECK(json_valid(original_json)), captured_at_utc TEXT NOT NULL);
CREATE INDEX orga_pupil ON orga(pupil_id);
CREATE INDEX orga_due ON orga(due_date,done);
CREATE INDEX orga_reminder ON orga(reminder_at_utc,reminder_state);
