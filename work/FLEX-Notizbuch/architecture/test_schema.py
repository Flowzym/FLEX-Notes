from pathlib import Path
import sqlite3

db=sqlite3.connect(':memory:')
db.executescript(Path(__file__).with_name('schema-v1.sql').read_text('utf-8'))
db.execute("INSERT INTO workspaces VALUES ('w','Test',1)")
db.execute("INSERT INTO devices(id,workspace_id,public_key) VALUES ('d','w',X'01')")
for pupil in ['a','b']:
    db.execute('INSERT INTO pupils(id,workspace_id,name) VALUES (?,\'w\',?)',(pupil,pupil))
db.execute("INSERT INTO situations(id,workspace_id,observed_date,captured_at_utc) VALUES ('s','w','2026-10-30','2026-10-30T12:00:00Z')")
db.execute("INSERT INTO goals(id,workspace_id,pupil_id,text,status) VALUES ('g','w','a','Goal','active')")
db.commit()
try:
    db.execute("INSERT INTO observations(id,workspace_id,situation_id,pupil_id,narrative,source_kind,documentation_status,goal_id) VALUES ('bad','w','s','b','','own','saved','g')")
    raise AssertionError('Cross-pupil goal accepted')
except sqlite3.IntegrityError:
    db.rollback()
try:
    with db:
        db.execute("INSERT INTO tasks(id,workspace_id,kind,title,status) VALUES ('t','w','organization','Class task','open')")
        db.execute("INSERT INTO operations VALUES ('o','w','d',1,1,'not-json')")
    raise AssertionError('Invalid operation accepted')
except sqlite3.IntegrityError:
    assert db.execute("SELECT COUNT(*) FROM tasks WHERE id='t'").fetchone()[0]==0
with db:
    db.execute("INSERT INTO tasks(id,workspace_id,kind,title,status) VALUES ('t','w','organization','Class task','open')")
    db.execute("INSERT INTO operations VALUES ('o','w','d',1,1,'{}')")
    db.execute("INSERT INTO outbox VALUES ('o')")
try:
    db.execute("INSERT INTO operations VALUES ('o2','w','d',1,1,'{}')")
    raise AssertionError('Duplicate origin sequence accepted')
except sqlite3.IntegrityError:
    db.rollback()
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
print('PASS schema, goal ownership, atomic data/outbox rollback, class task and unique origin sequence')
