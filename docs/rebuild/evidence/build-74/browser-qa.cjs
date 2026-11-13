const {chromium}=require('/opt/codex/cua_node/lib/node_modules/playwright');const fs=require('fs');
(async()=>{
 const b=await chromium.connectOverCDP('http://127.0.0.1:9223'),ctx=b.contexts()[0],p=await ctx.newPage();
 for(const old of ctx.pages())if(old!==p&&old.url().includes('8083'))await old.close();
 p.setDefaultTimeout(12000);await p.setViewportSize({width:390,height:844});const errors=[];p.on('pageerror',e=>errors.push(e.message));
 const click=async(name)=>{await p.getByRole('button',{name:new RegExp('^'+name+'(?: '+name+')?$')}).click();await p.waitForTimeout(400)};
 const input=async(label,text)=>{const field=p.getByRole('textbox',{name:label});await field.click();await p.waitForTimeout(250);await p.keyboard.press('Control+A');await p.keyboard.type(text);await p.waitForTimeout(350)};
 const labels=()=>p.locator('flt-semantics').evaluateAll(els=>els.map(e=>e.getAttribute('aria-label')||e.textContent).join('\n'));
 const shot=async(name)=>{await p.mouse.move(1,1);await p.waitForTimeout(600);await p.screenshot({path:`/workspace/build74/${name}.png`})};
 await p.goto('http://127.0.0.1:8083');await p.waitForTimeout(4500);
 const version=await p.evaluate(async()=>await(await fetch('/version.json')).json());if(version.build_number!=='74')throw Error('Wrong build');
 await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());await p.waitForTimeout(400);
 await click('Organisation');await click('Aufgaben');await click('Aufgabe anlegen');await click('Rücklauf');
 await input('Bezeichnung','QA Build74: Anhänge');
 await p.getByRole('button',{name:/Schüler auswählen/}).click();await p.waitForTimeout(300);await click('Auswahl leeren');
 for(const name of ['Alex Beispiel 1','Alex Beispiel 5'])await p.getByRole('checkbox',{name,exact:true}).click();
 await click('Übernehmen');await shot('return-form-390');
 const chooser=p.waitForEvent('filechooser');await click('Bilder / PDF');await(await chooser).setFiles('/workspace/build74/test-form.png');
 await p.getByText('1 Seite',{exact:true}).waitFor();await p.waitForTimeout(1000);await shot('import-preview-390');await click('PDF speichern');
 await p.getByRole('button',{name:'Datei bearbeiten',exact:true}).waitFor();await shot('attached-pdf-390');
 await click('Aufgabe');await click('Rücklauf');
 if(!(await labels()).includes('QA Build74: Anhänge')||!(await labels()).includes('PDF'))throw Error('Attachment lost on switch');
 // Second image saved as a regular photograph rather than a PDF.
 const chooser2=p.waitForEvent('filechooser');await click('Bilder / PDF');await(await chooser2).setFiles('/workspace/build74/test-form.png');
 await p.getByText('1 Seite',{exact:true}).waitFor();await p.getByRole('checkbox',{name:'Fotos (JPG)',exact:true}).click();await p.waitForTimeout(300);await click('Fotos speichern');await p.getByRole('button',{name:'Datei bearbeiten',exact:true}).nth(1).waitFor();
 await p.waitForTimeout(700);await p.setViewportSize({width:320,height:844});await p.waitForTimeout(400);await shot('attachments-320');
 await click('Speichern');await p.waitForTimeout(600);
 // Search is collapsed on a fresh navigation.
 await click('Einträge durchsuchen');await input(/Einträge durchsuchen$/,'QA Build74: Anhänge');await p.keyboard.press('Enter');await p.waitForTimeout(400);
 await p.getByRole('button',{name:/^QA Build74: Anhänge/}).click();await p.waitForTimeout(500);await shot('saved-return-320');
 const all=await labels();if(!all.includes('QA Build74: Anhänge'))throw Error('Saved return missing');
 fs.writeFileSync('/workspace/build74/browser-check.json',JSON.stringify({version,syntheticData:true,viewports:[320,390],pdfImportedAndSaved:true,jpgImportedAndSaved:true,attachmentsSurviveTypeSwitch:true,savedReturnOpened:true,pageErrors:errors},null,2)+'\n');
 if(errors.length)throw Error(JSON.stringify(errors));await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
