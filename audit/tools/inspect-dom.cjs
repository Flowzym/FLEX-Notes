// Source inspection in Node/jsdom. No browser, CSS layout, renderer or Flutter tests.
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM, VirtualConsole} = require(process.env.FLEX_JSDOM || 'jsdom');
const root=path.resolve(__dirname,'..');
const html=fs.readFileSync(path.join(root,'reference/FLEX-Notizbuch-37.html'),'utf8');
const code=html.match(/<script[^>]*>([\s\S]*?)<\/script>/)[1];
const errors=[];
const vc=new VirtualConsole();
vc.on('jsdomError',e=>errors.push(String(e)));
const dom=new JSDOM(html.replace(/<style[^>]*>[\s\S]*?<\/style>/g,'').replace(/<script[^>]*>[\s\S]*?<\/script>/g,''),{url:'https://flex.invalid/',runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc});
const w=dom.window;
const NativeDate=w.Date;
w.Date=class extends NativeDate {constructor(...args){super(...(args.length?args:['2026-11-01T12:00:00Z']));}static now(){return new NativeDate('2026-11-01T12:00:00Z').getTime();}};
w.matchMedia=q=>({matches:false,media:q,addEventListener(){},removeEventListener(){},addListener(){}});
w.CSS={escape:s=>String(s).replace(/[^\w-]/g,c=>'\\'+c),supports:()=>false};
w.ResizeObserver=class {observe(){} disconnect(){}};
w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};
w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
w.HTMLElement.prototype.scrollIntoView=function(){};
w.HTMLElement.prototype.animate=function(){return {cancel(){},finished:Promise.resolve()};};
w.scrollTo=()=>{};
w.requestAnimationFrame=f=>w.setTimeout(f,0);
w.eval(code+`\nwindow.auditEval=source=>eval(source);`);
const tick=()=>new Promise(r=>setTimeout(r,20));
const run=s=>w.auditEval(s);
function snapshot(id){
 const e=w.document.getElementById(id);
 if(!e)throw Error('Missing '+id);
 let order=0;
 const elements=[];
 function visit(n,hidden=false,collapsed=false){
  if(n.nodeType===3){const text=n.textContent.replace(/\s+/g,' ').trim();if(text)elements.push({order:++order,kind:'text',text,hidden,collapsed});return;}
  if(n.nodeType!==1)return;
  // These display:none rules were traced in the original CSS. This is deliberately
  // not a general CSS/layout implementation; the JSON retains that limitation.
  const cssHidden=n.matches('.visually-hidden,#studentDialog .identity .avatar,#studentDialog .identity small,#modalBody>.section-top,#modalBody>.section-title,dialog .date-control>input[type=date],.entry-additional .entry-additional>h3,#studentDialog .option-wrap:has(.option[aria-pressed=true]),.entry-experience #saveHint');
  hidden ||= n.hidden || n.classList.contains('hidden') || n.type==='hidden' || n.style.display==='none' || cssHidden;
  if(n.matches('button,input,textarea,select,summary,h2,h3,label,legend,[role=alert]')){
   const row={order:++order,kind:n.tagName.toLowerCase(),id:n.id||undefined,text:n.tagName==='INPUT'?undefined:n.textContent.replace(/\s+/g,' ').trim()||undefined,aria:n.getAttribute('aria-label')||undefined,title:n.title||undefined,placeholder:n.getAttribute('placeholder')||undefined,type:n.getAttribute('type')||undefined,value:'value'in n?n.value:undefined,checked:['checkbox','radio'].includes(n.type)?n.checked:undefined,disabled:n.disabled||undefined,required:n.required||undefined,maxlength:n.getAttribute('maxlength')||undefined,pressed:n.getAttribute('aria-pressed')||undefined,expanded:n.getAttribute('aria-expanded')||undefined,hidden,collapsed};
   if(n.tagName==='SELECT')row.options=[...n.options].map(o=>({value:o.value,text:o.text,selected:o.selected}));
   elements.push(row);
   if(n.matches('button,input,textarea,select,summary,h2,h3,legend'))return;
  }
  for(const c of n.childNodes)visit(c,hidden,collapsed||(n.tagName==='DETAILS'&&!n.open&&c.tagName!=='SUMMARY'));
 }
 visit(e);
 return {id,classes:e.className,elements};
}
(async()=>{
 await tick();
 const inventory=[...w.document.querySelectorAll('dialog')].map(e=>({id:e.id,title:e.querySelector('h2')?.textContent,classes:e.className}));
 const states={};
 async function capture(name,action,id='studentDialog'){run(action);await tick();states[name]=snapshot(id);}
 await capture('add-empty',`$('#addStudent').click()`,'addDialog');
 run(`db.students.push({id:'audit-a',name:'Anna Beispiel',archived:false,color:'#65846c'},{id:'audit-b',name:'Ben Beispiel',archived:false,color:'#53747e'});persist();openStudent('audit-a');`);
 await capture('overview-empty',`section='';renderModal()`);
 for(const category of ['Sozialverhalten','Arbeitsverhalten','Organisatorisches','Ziele','Hausübung','Verlauf']){
  await capture(category+'-empty',`section=${JSON.stringify(category)};tone='positive';feedbackId=null;homeMode='feedback';renderModal()`);
  if(['Sozialverhalten','Arbeitsverhalten'].includes(category)){
   await capture(category+'-negative',`tone='negative';renderModal()`);
   await capture(category+'-filled',`Object.assign(draft(),{text:'Synthetische Beobachtung',task:'Lesen',choices:[{tone:'positive',text:behaviorOptions(section,'positive')[0]},{tone:'negative',text:behaviorOptions(section,'negative')[0]}],support:true,supportNote:'Synthetische Unterstützung',needsFollowUp:true,sourceKind:'reported',sharedContext:'Synthetischer Kontext',participants:[{studentId:'audit-b',name:'Ben Beispiel'}],participantsEnabled:true});renderModal()`);
  }
 }
 await capture('goal-new',`section='Ziele';draft().goalComposer=true;renderModal()`);
 await capture('homework-new',`section='Hausübung';homeMode='new';renderModal()`);
 await capture('orga-expanded',`section='Organisatorisches';Object.assign(draft(),{text:'Synthetische Notiz',orgTask:true,orgReminderEnabled:true,orgDue:'2026-11-04',orgReminderDue:'2026-11-03T10:30'});renderModal()`);
 await capture('options-positive',`section='Sozialverhalten';tone='positive';openOptions()`,'optionsDialog');
 await capture('options-negative',`editorTone='negative';drawEditor()`,'optionsDialog');
 await capture('pupil',`managePupil()`,'pupilDialog');
 await capture('drafts',`showDrafts()`,'draftDialog');
 await capture('brief-empty',`showBrief()`,'briefDialog');
 await capture('class-list-empty',`drawClassTasks()`,'classTasksDialog');
 await capture('class-new',`openClassTask('')`,'classTaskDialog');
 await capture('trash-empty',`drawTrash()`,'trashDialog');
 await capture('maintenance',`openMaintenance('compact')`,'maintenanceDialog');
 await capture('purge',`openMaintenance('purge')`,'maintenanceDialog');
 await capture('conflicts-empty',`drawConflicts()`,'conflictDialog');
 await capture('backup',`$('#backupDialog').showModal()`,'backupDialog');
 for(const category of ['Sozialverhalten','Arbeitsverhalten','Organisatorisches','Ziele']){
  run(`section=${JSON.stringify(category)};record(section,'Synthetischer Eintrag',BEHAVIOR[section]?[{tone:'positive',text:behaviorOptions(section,'positive')[0]}]:[],section==='Ziele'?{kind:'goal',goalCriterion:'Synthetisches Kriterium',goalStep:'Synthetischer Schritt',goalDue:'2026-11-10',goalReviewDue:'2026-11-08',goalStatus:'active'}:{});window.lastAuditRecord=db.entries.at(-1).id;persist();`);
  await capture(category+'-edit',`editRecord(window.lastAuditRecord)`,'recordDialog');
  if(category==='Ziele'){
   await capture('goal-review-continue',`openGoalReview(window.lastAuditRecord)`,'goalReviewDialog');
   await capture('goal-review-reached',`$('#goalReviewOutcome').value='reached';$('#goalReviewOutcome').dispatchEvent(new Event('change'))`,'goalReviewDialog');
   await capture('goal-review-error',`$('#goalReviewOutcome').value='continue';$('#goalReviewOutcome').dispatchEvent(new Event('change'));$('#goalReviewDue').value='';$('#goalReviewForm').dispatchEvent(new Event('submit',{cancelable:true}))`,'goalReviewDialog');
  }
 }
 await capture('goal-list-filled',`section='Ziele';draft().goalComposer=false;renderModal()`);
 run(`section='Hausübung';homeMode='new';Object.assign(draft(),{title:'Aufgabe A\\n  Teilaufgabe B',subject:'Deutsch',due:'2026-11-05',targets:['audit-a'],hwRows:[{id:'audit-task-a',text:'Aufgabe A',parentId:null},{id:'audit-task-b',text:'Teilaufgabe B',parentId:'audit-task-a'}]});save();window.lastAuditHomework=db.homework.at(-1).id;`);
 await capture('homework-list-filled',`section='Hausübung';homeMode='feedback';feedbackId=null;renderModal()`);
 await capture('homework-edit',`openHomeworkEditor(window.lastAuditHomework)`,'homeworkEditDialog');
 await capture('homework-comment-open',`openHomeworkTaskComment(window.lastAuditHomework,homeworkTasks(db.homework.at(-1))[0].id)`,'homeworkTaskDialog');
 await capture('homework-note-history',`feedbackId=window.lastAuditHomework;homeMode='feedback';renderModal()`);
 for(const category of ['Sozialverhalten','Arbeitsverhalten','Hausübung','Organisatorisches']){
  await capture('bulk-'+category,`startBulk(newBulkData(['audit-a','audit-b']),${JSON.stringify(category)})`,'bulkDialog');
 }
 await capture('bulk-error',`bulkCategory='Arbeitsverhalten';bulkData=newBulkData(['audit-a','audit-b']);renderBulkForm();saveBulkEntry()`,'bulkDialog');
 await capture('calendar-date',`section='Ziele';draft().goalComposer=true;renderModal();enhanceDates();openCalendar($('#goalDue'),$('#goalDue').parentElement.querySelector('button'))`,'calendarDialog');
 await capture('calendar-time',`section='Sozialverhalten';renderModal();enhanceDates();openCalendar($('#observedAtDate'),$('#observedAtDate').parentElement.querySelector('button'))`,'calendarDialog');
 run(`db.situations.push({id:'audit-situation',text:'Gemeinsamer synthetischer Ablauf',at:day(),participants:[{studentId:'audit-a',name:'Anna Beispiel'},{studentId:'audit-b',name:'Ben Beispiel'}]});db.entries.find(e=>e.category==='Sozialverhalten').situationId='audit-situation';persist();`);
 await capture('situation',`openSituation('audit-situation')`,'situationDialog');
 await capture('history-filled',`section='Verlauf';renderModal()`);
 await capture('brief-filled',`showBrief();$('#selectBriefAll').click();$('#createBrief').click()`,'briefDialog');
 await capture('import-configured',`pendingImport=copy(db);configureImportReview()`,'importReview');
 await capture('import-recovery',`canStore=false;configureImportReview()`,'importReview');
 run(`canStore=true;configureImportReview();`);
 await capture('maintenance-error',`openMaintenance('purge');$('#commitMaintenance').click()`,'maintenanceDialog');
 await capture('calendar-midnight',`calendarTime='00:00';drawCalendar()`,'calendarDialog');
 await capture('conflicts-filled',`db.conflicts.push({id:'audit-conflict',entityId:db.entries[0].id,field:'text',current:db.entries[0].text,incoming:'Andere synthetische Fassung'});drawConflicts()`,'conflictDialog');
 await capture('trash-filled',`db.entries.find(e=>e.category==='Organisatorisches').deletedAt=now();drawTrash()`,'trashDialog');
 await capture('editor-draft-resume',`openHomeworkTaskComment(window.lastAuditHomework,homeworkTasks(db.homework.at(-1))[0].id);`,'homeworkTaskDialog');
 run(`$('#hwTaskComment').value='Unfertiger synthetischer Kommentar';$('#hwTaskComment').dispatchEvent(new Event('input',{bubbles:true}));`);
 await tick();
 await capture('editor-draft-offer',`requestEditorClose(homeworkTaskDialog);openHomeworkTaskComment(window.lastAuditHomework,homeworkTasks(db.homework.at(-1))[0].id)`,'homeworkTaskDialog');
 await capture('editor-draft-resumed',`$('#homeworkTaskDialog [data-resume]').click()`,'homeworkTaskDialog');
 await capture('drafts-filled',`saveDrafts();showDrafts()`,'draftDialog');
 await capture('comment-save-error',`canStore=false;$('#homeworkTaskForm').dispatchEvent(new Event('submit',{cancelable:true}))`,'homeworkTaskDialog');
 await capture('draft-close-error',`window.auditOriginalStorageSet=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw Error('synthetic full storage')};$('#hwTaskComment').value+='!';requestEditorClose(homeworkTaskDialog)`,'discardEditDialog');
 run(`Storage.prototype.setItem=window.auditOriginalStorageSet;canStore=true;setSaveStatus(true);`);
 for(const title of ['Sicherung öffnen','Sicherung verschlüsseln']){
  run(`askBackupPassword(${JSON.stringify(title)});document.querySelector('dialog:not([id])').id='audit-password';`);
  await tick();states[title]=snapshot('audit-password');
  run(`$('#audit-password').close()`);
 }
 states['settings-page']=await (async()=>{run(`switchPage('settings');renderSettings()`);await tick();return snapshot('settingsPage');})();
 const catalogs=run(`({behavior:BEHAVIOR,source:[['own','Selbst beobachtet'],['reported','Berichtet'],['interpretation','Eigene Einordnung']],delivery:DELIVERY,status:STATUS,reminders:DEFAULT_REMINDER_OPTIONS,pupilColors:pupilColorPalette()})`);
 states['discardEditDialog']=snapshot('discardEditDialog');
 fs.writeFileSync(path.join(root,'evidence/dom-inventory.json'),JSON.stringify({method:'Node/jsdom source inspection; CSS removed; synthetic data; NOT rendered/browser/Flutter evidence',inventory,catalogs,states,errors},null,2)+'\n');
 console.log(JSON.stringify({dialogs:inventory,states:Object.keys(states),errors},null,2));
 dom.window.close();
})().catch(e=>{console.error(e);dom.window.close();process.exitCode=1;});
