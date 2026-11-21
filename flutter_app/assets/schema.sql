-- FLEX storage schema 8. Changes are migrated transactionally.
-- One workspace per database. No invented public key or pairing credentials.
-- flex:statement
CREATE TABLE devices (
 id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '', platform TEXT NOT NULL DEFAULT '',
 created_at_utc TEXT, last_seen_at_utc TEXT,
 public_key_metadata TEXT CHECK(public_key_metadata IS NULL OR json_valid(public_key_metadata))
);
-- flex:statement
CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- flex:statement
CREATE TABLE pupils (
 id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 80),
 color INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
 revision INTEGER NOT NULL CHECK(revision > 0),
 created_at_utc TEXT, updated_at_utc TEXT,
 deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)), deleted_at_utc TEXT,
 CHECK(deleted=0 OR archived=1)
);
-- flex:statement
CREATE TABLE orga (
 id TEXT PRIMARY KEY, pupil_id TEXT REFERENCES pupils(id),
 title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 160),
 deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)),
 body TEXT NOT NULL, reminder_text TEXT NOT NULL DEFAULT '', observed_on TEXT NOT NULL DEFAULT '', observed_time TEXT NOT NULL DEFAULT '', is_task INTEGER NOT NULL CHECK(is_task IN (0,1)),
 done INTEGER NOT NULL CHECK(done IN (0,1)), due_date TEXT,
 reminder_at_utc TEXT, reminder_zone TEXT NOT NULL,
 reminder_state TEXT NOT NULL CHECK(reminder_state IN ('none','planned','acknowledged','cancelled')),
 needs_completion INTEGER NOT NULL CHECK(needs_completion IN (0,1)),
 revision INTEGER NOT NULL CHECK(revision>0), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL,
 CHECK(is_task=1 OR (done=0 AND due_date IS NULL)),
 CHECK((done=0 AND deleted=0) OR reminder_state!='planned'),
 CHECK((reminder_at_utc IS NULL AND reminder_state='none') OR (reminder_at_utc IS NOT NULL AND reminder_state!='none')),
 CHECK(due_date IS NULL OR (length(due_date)=10 AND due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'))
);
-- flex:statement
CREATE TABLE orga_items (
 id TEXT PRIMARY KEY, orga_id TEXT NOT NULL REFERENCES orga(id),
 position INTEGER NOT NULL CHECK(position>=0), text TEXT NOT NULL CHECK(length(trim(text))>0),
 checked INTEGER NOT NULL CHECK(checked IN (0,1)), UNIQUE(orga_id,position)
);
-- flex:statement
CREATE TABLE drafts (
 id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, base_revision INTEGER NOT NULL CHECK(base_revision>=0),
 payload TEXT NOT NULL CHECK(json_valid(payload)), updated_at_utc TEXT NOT NULL
);
-- flex:statement
CREATE TABLE revisions (
 id TEXT PRIMARY KEY, entity_kind TEXT NOT NULL, entity_id TEXT NOT NULL,
 base_revision INTEGER NOT NULL CHECK(base_revision>=0), revision INTEGER NOT NULL CHECK(revision=base_revision+1),
 before_payload TEXT CHECK(before_payload IS NULL OR json_valid(before_payload)),
 after_payload TEXT NOT NULL CHECK(json_valid(after_payload)), captured_at_utc TEXT NOT NULL,
 device_id TEXT NOT NULL REFERENCES devices(id), UNIQUE(entity_kind,entity_id,revision)
);
-- flex:statement
CREATE TABLE operations (
 id TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(id),
 sequence INTEGER NOT NULL CHECK(sequence>0), protocol_version INTEGER NOT NULL CHECK(protocol_version BETWEEN 1 AND 65535),
 revision_id TEXT NOT NULL REFERENCES revisions(id), payload TEXT NOT NULL CHECK(json_valid(payload)), UNIQUE(device_id,sequence)
);
-- flex:statement
CREATE TABLE outbox (operation_id TEXT PRIMARY KEY REFERENCES operations(id));
-- flex:statement
CREATE TABLE preferences (key TEXT PRIMARY KEY, payload TEXT NOT NULL CHECK(json_valid(payload)));
-- flex:statement
CREATE TABLE legacy_backups (id TEXT PRIMARY KEY, original_json TEXT NOT NULL CHECK(json_valid(original_json)), captured_at_utc TEXT NOT NULL);
-- flex:statement
CREATE INDEX orga_pupil ON orga(pupil_id);
-- flex:statement
CREATE INDEX orga_due ON orga(due_date,done);
-- flex:statement
CREATE INDEX orga_reminder ON orga(reminder_at_utc,reminder_state);

-- flex:statement
CREATE TABLE situations (id TEXT PRIMARY KEY, revision INTEGER NOT NULL CHECK(revision>0), payload TEXT NOT NULL CHECK(json_valid(payload)));
-- flex:statement
CREATE TABLE situation_pupils (situation_id TEXT NOT NULL REFERENCES situations(id), pupil_id TEXT NOT NULL REFERENCES pupils(id), PRIMARY KEY(situation_id,pupil_id));
-- flex:statement
CREATE TABLE context_drafts (id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, payload TEXT NOT NULL CHECK(json_valid(payload)), updated_at_utc TEXT NOT NULL);
-- flex:statement
CREATE TABLE group_drafts (id TEXT PRIMARY KEY, payload TEXT NOT NULL CHECK(json_valid(payload)), updated_at_utc TEXT NOT NULL);
-- flex:statement
CREATE TABLE group_saves (id TEXT PRIMARY KEY, request TEXT NOT NULL CHECK(json_valid(request)), saved_at_utc TEXT NOT NULL, undone_at_utc TEXT, recovery_draft_id TEXT);
-- flex:statement
CREATE TABLE school_records (id TEXT PRIMARY KEY, pupil_id TEXT NOT NULL REFERENCES pupils(id), situation_id TEXT REFERENCES situations(id), revision INTEGER NOT NULL CHECK(revision>0), payload TEXT NOT NULL CHECK(json_valid(payload)));
-- flex:statement
CREATE TABLE school_drafts (id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, payload TEXT NOT NULL CHECK(json_valid(payload)), updated_at_utc TEXT NOT NULL);
-- flex:statement
CREATE TABLE pupil_drafts (id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, revision INTEGER NOT NULL CHECK(revision>0), payload TEXT NOT NULL CHECK(json_valid(payload)), updated_at_utc TEXT NOT NULL);

-- flex:statement
CREATE INDEX pupils_state ON pupils(deleted,archived,name COLLATE NOCASE);
-- flex:statement
CREATE INDEX school_pupil ON school_records(pupil_id);
-- flex:statement
CREATE INDEX school_kind_date ON school_records(json_extract(payload,'$.kind'),json_extract(payload,'$.deleted'),json_extract(payload,'$.observedOn'));
-- flex:statement
CREATE INDEX import_archive_date ON legacy_backups(captured_at_utc);
-- flex:statement
CREATE INDEX revisions_entity ON revisions(entity_kind,entity_id,revision);
-- flex:statement
CREATE VIRTUAL TABLE entry_search USING fts5(kind UNINDEXED,entity_id UNINDEXED,pupil_id UNINDEXED,body,tokenize='unicode61 remove_diacritics 2');
-- flex:statement
CREATE TRIGGER search_school_records_insert AFTER INSERT ON school_records WHEN 1 BEGIN
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('school',new.id,new.pupil_id,COALESCE((SELECT group_concat(value,' ') FROM json_tree(new.payload) WHERE type='text' AND (key IN ('title','body','subject','taskFree','text','note','context','situation','criterion','support','pupilPerspective','nextStep') OR path IN ('$.positive','$.neutral','$.negative','$.taskTags','$.tags'))),''));
END;
-- flex:statement
CREATE TRIGGER search_school_records_update AFTER UPDATE ON school_records WHEN 1 BEGIN
 DELETE FROM entry_search WHERE kind='school' AND entity_id=old.id;
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('school',new.id,new.pupil_id,COALESCE((SELECT group_concat(value,' ') FROM json_tree(new.payload) WHERE type='text' AND (key IN ('title','body','subject','taskFree','text','note','context','situation','criterion','support','pupilPerspective','nextStep') OR path IN ('$.positive','$.neutral','$.negative','$.taskTags','$.tags'))),''));
END;
-- flex:statement
CREATE TRIGGER search_school_records_delete AFTER DELETE ON school_records WHEN 1 BEGIN
 DELETE FROM entry_search WHERE kind='school' AND entity_id=old.id;
END;
-- flex:statement
CREATE TRIGGER search_situations_insert AFTER INSERT ON situations WHEN 1 BEGIN
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('situation',new.id,'',COALESCE((SELECT group_concat(value,' ') FROM json_tree(new.payload) WHERE type='text' AND (key IN ('title','body','subject','taskFree','text','note','context','situation','criterion','support','pupilPerspective','nextStep') OR path IN ('$.positive','$.neutral','$.negative','$.taskTags','$.tags'))),''));
END;
-- flex:statement
CREATE TRIGGER search_situations_update AFTER UPDATE ON situations WHEN 1 BEGIN
 DELETE FROM entry_search WHERE kind='situation' AND entity_id=old.id;
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('situation',new.id,'',COALESCE((SELECT group_concat(value,' ') FROM json_tree(new.payload) WHERE type='text' AND (key IN ('title','body','subject','taskFree','text','note','context','situation','criterion','support','pupilPerspective','nextStep') OR path IN ('$.positive','$.neutral','$.negative','$.taskTags','$.tags'))),''));
END;
-- flex:statement
CREATE TRIGGER search_situations_delete AFTER DELETE ON situations WHEN 1 BEGIN
 DELETE FROM entry_search WHERE kind='situation' AND entity_id=old.id;
END;
-- flex:statement
CREATE TRIGGER search_preferences_insert AFTER INSERT ON preferences WHEN new.key LIKE 'classroom:%' BEGIN
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('classroom',substr(new.key,11),'',COALESCE((SELECT group_concat(value,' ') FROM json_tree(new.payload) WHERE type='text' AND (key IN ('title','body','subject','taskFree','text','note','context','situation','criterion','support','pupilPerspective','nextStep') OR path IN ('$.positive','$.neutral','$.negative','$.taskTags','$.tags'))),''));
END;
-- flex:statement
CREATE TRIGGER search_preferences_update AFTER UPDATE ON preferences WHEN new.key LIKE 'classroom:%' BEGIN
 DELETE FROM entry_search WHERE kind='classroom' AND entity_id=substr(old.key,11);
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('classroom',substr(new.key,11),'',COALESCE((SELECT group_concat(value,' ') FROM json_tree(new.payload) WHERE type='text' AND (key IN ('title','body','subject','taskFree','text','note','context','situation','criterion','support','pupilPerspective','nextStep') OR path IN ('$.positive','$.neutral','$.negative','$.taskTags','$.tags'))),''));
END;
-- flex:statement
CREATE TRIGGER search_preferences_delete AFTER DELETE ON preferences WHEN old.key LIKE 'classroom:%' BEGIN
 DELETE FROM entry_search WHERE kind='classroom' AND entity_id=substr(old.key,11);
END;
-- flex:statement
CREATE TRIGGER search_orga_insert AFTER INSERT ON orga BEGIN
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('orga',new.id,new.pupil_id,new.title || ' ' || new.body || ' ' || COALESCE((SELECT group_concat(text,' ') FROM orga_items WHERE orga_id=new.id),''));
END;
-- flex:statement
CREATE TRIGGER search_orga_update AFTER UPDATE ON orga BEGIN
 DELETE FROM entry_search WHERE kind='orga' AND entity_id=old.id;
 INSERT INTO entry_search(kind,entity_id,pupil_id,body) VALUES ('orga',new.id,new.pupil_id,new.title || ' ' || new.body || ' ' || COALESCE((SELECT group_concat(text,' ') FROM orga_items WHERE orga_id=new.id),''));
END;
-- flex:statement
CREATE TRIGGER search_orga_delete AFTER DELETE ON orga BEGIN
 DELETE FROM entry_search WHERE kind='orga' AND entity_id=old.id;
END;
-- flex:statement
CREATE TRIGGER search_orga_items_insert AFTER INSERT ON orga_items BEGIN
 UPDATE orga SET body=body WHERE id=new.orga_id;
END;
-- flex:statement
CREATE TRIGGER search_orga_items_update AFTER UPDATE ON orga_items BEGIN
 UPDATE orga SET body=body WHERE id=new.orga_id;
END;
-- flex:statement
CREATE TRIGGER search_orga_items_delete AFTER DELETE ON orga_items BEGIN
 UPDATE orga SET body=body WHERE id=old.orga_id;
END;
