from pathlib import Path
from playwright.sync_api import sync_playwright, expect
import json,re
expect.set_options(timeout=45000)
out=Path('/workspace/features46/browser');out.mkdir(exist_ok=True)
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
 c=b.new_context(viewport={'width':390,'height':844},accept_downloads=True)
 page=c.new_page();page.set_default_timeout(45000);errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 def button(name): return page.get_by_role('button',name=name,exact=True)
 def click(loc):
  loc.wait_for(state='visible');loc.scroll_into_view_if_needed();page.wait_for_timeout(250);box=loc.bounding_box();page.mouse.click(box['x']+box['width']/2,box['y']+box['height']/2);page.wait_for_timeout(350)
 def text(loc,value):
  click(loc);page.wait_for_timeout(250);page.keyboard.press('Control+A');page.keyboard.insert_text(value);page.wait_for_timeout(250)
 try:
  page.goto('http://127.0.0.1:8084',wait_until='domcontentloaded')
  page.locator('flt-semantics-placeholder').dispatch_event('click',timeout=30000)
  expect(button('Aktuell')).to_be_visible(timeout=60000)
  click(button('Aufzeichnung'));click(button('Neuer Schüler'))
  print('PUPIL',page.locator('body').aria_snapshot(),flush=True)
  text(page.get_by_role('textbox',name='Name',exact=True),'Scanner Testkind')
  click(button('Hinzufügen'))
  click(page.get_by_role('button',name=re.compile('HÜ für Scanner Testkind öffnen')))
  print('HOMEWORK',page.locator('body').aria_snapshot(),flush=True)
  text(page.get_by_role('textbox',name=re.compile('^Aufgabe')), 'Übungsblatt')
  click(button('Teilaufgabe hinzufügen'))
  text(page.get_by_role('textbox',name=re.compile('^Teilaufgabe')), 'Lösung Teil A')
  page.screenshot(path=str(out/'task-editor-phone.png'))
  click(button('Speichern & scannen').nth(1))
  expect(button('Bilder / PDF hinzufügen')).to_be_visible()
  print('SCANNER',page.locator('body').aria_snapshot(),flush=True)
  expect(page.get_by_text('Scanner Testkind · Teilaufgabe · Lösung Teil A',exact=False)).to_be_visible()
  with page.expect_file_chooser() as fc: click(button('Bilder / PDF hinzufügen'))
  fc.value.set_files(['/workspace/features44/browser/probe.jpg'])
  expect(page.get_by_text('1 Seite',exact=True)).to_be_visible(timeout=90000)
  page.screenshot(path=str(out/'task-scanner-phone.png'))
  click(button('PDF speichern'));expect(button('Öffnen')).to_be_visible(timeout=90000)
  with page.expect_download() as dl: click(button('Teilen / Exportieren'))
  dl.value.save_as(str(out/'task-scan.pdf'))
  click(button('Schließen und Eingaben sichern').last)
  print('AFTER_SAVE',page.locator('body').aria_snapshot(),flush=True)
  # Return to the homework list and open the exact file directly from its task.
  if page.get_by_role('dialog').count(): click(button('Schließen und Eingaben sichern').last)
  click(page.get_by_role('button',name=re.compile('HÜ für Scanner Testkind öffnen')))
  expect(page.get_by_role('button',name=re.compile('^Aufgegebene Hausübungen'))).to_be_visible()
  click(page.get_by_role('button',name=re.compile('^Aufgegebene Hausübungen')))
  expect(page.get_by_role('button',name=re.compile(r'^2026-11-07 · Scanner Testkind · Hausübung · Lösung Teil A$'))).to_be_visible()
  print('REOPEN',page.locator('body').aria_snapshot(),flush=True)
  page.screenshot(path=str(out/'task-attachments-phone.png'))
  click(page.get_by_role('button',name=re.compile(r'^2026-11-07 · Scanner Testkind · Hausübung · Lösung Teil A$')))
  expect(button('Hausübung einklappen')).to_have_count(0)
  expect(button('Schließen und Eingaben sichern')).to_be_visible()
  page.wait_for_timeout(3500)
  page.screenshot(path=str(out/'task-pdf-open-phone.png'))
  assert not errors, errors
  (out/'result.json').write_text(json.dumps({'viewport':[390,844],'new_homework_subtask_capture':True,'context_label':True,'pdf_export':True,'attachment_visible_on_subtask':True,'attachment_reopened':True,'page_errors':errors},indent=2))
 except Exception:
  print('FAILED',page.locator('body').aria_snapshot(),flush=True)
  page.screenshot(path=str(out/'failure.png'))
  raise
 finally: b.close()
