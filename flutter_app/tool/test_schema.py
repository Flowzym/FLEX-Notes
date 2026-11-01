"""Actual SQLite contract tests; these do not execute the Dart repository."""
import pathlib
import sqlite3
import tempfile
import unittest

SCHEMA = (pathlib.Path(__file__).resolve().parents[1] / 'assets/schema.sql').read_text()

class SchemaTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript(SCHEMA)
        self.db.execute("INSERT INTO devices VALUES ('synthetic-device')")
        self.db.execute("INSERT INTO pupils VALUES ('synthetic-pupil','Testkind Alpha',4289248128,0,1)")
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def orga(self, **changes):
        row = dict(id='synthetic-task', pupil_id=None, title='Synthetischer Vorgang', body='Nur Testdaten', is_task=1, done=0, due_date='2026-11-10', reminder_at_utc='2026-11-08T15:00:00Z', reminder_zone='Europe/Vienna', reminder_state='planned', needs_completion=0, revision=1, created_at_utc='2026-10-31T12:00:00Z', updated_at_utc='2026-10-31T12:00:00Z')
        row.update(changes)
        self.db.execute(f"INSERT INTO orga({','.join(row)}) VALUES ({','.join('?' for _ in row)})", list(row.values()))

    def test_class_orga_without_pupil(self):
        self.orga()
        self.assertIsNone(self.db.execute('SELECT pupil_id FROM orga').fetchone()[0])

    def test_note_with_reminder_is_not_task(self):
        self.orga(is_task=0, due_date=None)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM orga WHERE is_task=1 AND done=0').fetchone()[0], 0)

    def test_invalid_owner_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError): self.orga(pupil_id='not-a-pupil')

    def test_note_cannot_be_done_or_have_deadline(self):
        with self.assertRaises(sqlite3.IntegrityError): self.orga(is_task=0)
        with self.assertRaises(sqlite3.IntegrityError): self.orga(is_task=0, due_date=None, done=1, reminder_state='cancelled')

    def test_done_task_cannot_have_active_reminder(self):
        self.orga()
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute('UPDATE orga SET done=1')
        self.db.execute("UPDATE orga SET done=1, reminder_state='cancelled'")
        self.assertEqual(self.db.execute('SELECT done,reminder_state FROM orga').fetchone(), (1,'cancelled'))

    def test_reminder_acknowledgment_keeps_task_open(self):
        self.orga()
        self.db.execute("UPDATE orga SET reminder_state='acknowledged'")
        self.assertEqual(self.db.execute('SELECT done FROM orga').fetchone()[0], 0)

    def test_invalid_reminder_tuple_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError): self.orga(reminder_at_utc=None)
        with self.assertRaises(sqlite3.IntegrityError): self.orga(reminder_state='none')

    def test_item_identity_and_position_unique(self):
        self.orga()
        self.db.execute("INSERT INTO orga_items VALUES ('synthetic-item','synthetic-task',0,'Testpunkt',0)")
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO orga_items VALUES ('other','synthetic-task',0,'Testpunkt 2',0)")
        self.db.execute("UPDATE orga SET done=1,reminder_state='cancelled'")
        self.assertEqual(self.db.execute('SELECT checked FROM orga_items').fetchone()[0], 0)

    def test_revision_operation_outbox_atomic_rollback(self):
        with self.assertRaises(sqlite3.IntegrityError):
            with self.db:
                self.orga()
                self.db.execute("INSERT INTO revisions VALUES ('r','orga','synthetic-task',0,1,NULL,'{}','2026-10-31T12:00:00Z','synthetic-device')")
                self.db.execute("INSERT INTO operations VALUES ('o','synthetic-device',1,1,'r','{}')")
                self.db.execute("INSERT INTO outbox VALUES ('nonexistent-operation')")
        for table in ['orga','revisions','operations','outbox']:
            self.assertEqual(self.db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0], 0)

    def test_logical_sequence_not_clock_is_unique(self):
        self.db.execute("INSERT INTO revisions VALUES ('r','orga','synthetic-task',0,1,NULL,'{}','2026-10-31T12:00:00Z','synthetic-device')")
        self.db.execute("INSERT INTO operations VALUES ('o','synthetic-device',1,1,'r','{}')")
        with self.assertRaises(sqlite3.IntegrityError): self.db.execute("INSERT INTO operations VALUES ('o2','synthetic-device',1,1,'r','{}')")

    def test_file_persistence_after_reopen(self):
        self.orga()
        self.db.commit()
        with tempfile.TemporaryDirectory(prefix='flex-synthetic-') as folder:
            path = pathlib.Path(folder)/'test.sqlite'
            disk = sqlite3.connect(path); self.db.backup(disk); disk.close()
            disk = sqlite3.connect(path)
            self.assertEqual(disk.execute('SELECT title,due_date,reminder_at_utc FROM orga').fetchone(), ('Synthetischer Vorgang','2026-11-10','2026-11-08T15:00:00Z'))
            self.assertEqual(disk.execute('PRAGMA integrity_check').fetchone()[0], 'ok'); disk.close()

if __name__ == '__main__': unittest.main(verbosity=2)
