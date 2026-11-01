// Presentation only: existing records and work items are never mutated here.
function pupilCategoryLabel(category){return {Organisatorisches:'Orga',Sozialverhalten:'Sozial',Arbeitsverhalten:'Arbeit',Hausübung:'HÜ',Ziele:'Ziele',Erinnerung:'Orga'}[category]||category;}
function pupilRecordText(e){if(e.category==='Organisatorisches')return String(e.text||'').split('\n').map(orgListLine).map(x=>x.text).filter(x=>x.trim()).join(' · ');return overviewPreview(e);}
function pupilWorkKey(item){return item.action==='data-open-hw'?'hw:'+item.id:'entry:'+item.id;}
function pupilEntryKey(e){return e.kind==='assigned'&&e.homeworkId?'hw:'+e.homeworkId:'entry:'+e.id;}
function pupilWorkPriority(item){if(!item.due)return 3;const date=item.due.slice(0,10);return date<day()?0:date===day()?1:2;}
function pupilOverviewModel(){
 const query=pupilOverviewQuery.trim().toLocaleLowerCase('de'),all=entriesFor(),byKey=new Map();
 for(const e of all)if(!byKey.has(pupilEntryKey(e)))byKey.set(pupilEntryKey(e),e);
 const work=new Map();
 for(const item of workItems().filter(x=>x.studentId===active&&!x.documentation)){
  const key=pupilWorkKey(item);let entry=byKey.get(key);
  if(!entry&&item.action==='data-open-hw'){const h=db.homework.find(h=>h.id===item.id&&!h.deletedAt);if(h)entry={id:key,category:'Hausübung',studentId:active,kind:'assigned',homeworkId:h.id,text:h.title,choices:[],at:h.createdAt||day(),overviewSynthetic:true};}
  if(!entry)continue;
  if(!work.has(key))work.set(key,{entry,events:[]});work.get(key).events.push(item);
 }
 const pending=[...work.values()];for(const row of pending)row.events.sort((a,b)=>pupilWorkPriority(a)-pupilWorkPriority(b)||(a.due||'9999').localeCompare(b.due||'9999')||a.kind.localeCompare(b.kind));
 pending.sort((a,b)=>pupilWorkPriority(a.events[0])-pupilWorkPriority(b.events[0])||(a.events[0].due||'9999').localeCompare(b.events[0].due||'9999')||b.entry.at.localeCompare(a.entry.at)||a.entry.id.localeCompare(b.entry.id));
 const pendingKeys=new Set(pending.map(x=>pupilEntryKey(x.entry)));
 const docs=all.filter(e=>!e.contextOnly&&pendingFollowUp(e)&&!pendingKeys.has(pupilEntryKey(e)));
 const matches=e=>!query||overviewSearchText(e).includes(query)||pupilCategoryLabel(e.category).toLocaleLowerCase('de').includes(query);
 const candidates=[...all,...pending.filter(x=>x.entry.overviewSynthetic).map(x=>x.entry)];
 const filtered=candidates.filter(e=>(overviewFilter==='all'||overviewFilter==='week'&&inOverviewWeek(e.at)||overviewFilter==='open'&&overviewRecordOpen(e))&&matches(e));
 const recent=all.filter(e=>!pendingKeys.has(pupilEntryKey(e))&&!docs.some(d=>d.id===e.id));
 const student=db.students.find(s=>s.id===active),names=[student?.name,...(student?.previousNames||[])];
 const legacy=(db.legacy||[]).filter(e=>e&&Array.isArray(e.people)&&e.people.some(n=>names.includes(n))&&(overviewFilter==='all'||overviewFilter==='week'&&inOverviewWeek(e.date))&&(!query||[...(Array.isArray(e.values)?e.values:[]),e.task,e.text].filter(Boolean).join(' ').toLocaleLowerCase('de').includes(query)));
 return {all,pending,docs,recent,filtered,legacy,query};
}
function pupilPreviewHTML(e){
 if(e.category!=='Organisatorisches')return '<span class="pupil-preview-text">'+esc(pupilRecordText(e))+'</span>';
 const lines=String(e.text||'').split('\n').map(orgListLine).filter(x=>x.text.trim()),checks=lines.filter(x=>x.type==='check');
 return '<span class="pupil-list-preview">'+lines.slice(0,3).map(x=>'<span class="pupil-preview-line'+(x.checked?' is-checked':'')+'">'+(x.type==='check'?'<span class="pupil-check-mark" aria-label="'+(x.checked?'erledigt':'offen')+'">'+(x.checked?'☑':'☐')+'</span>':x.type==='bullet'?'<span aria-hidden="true">•</span>':x.type==='number'?'<span>'+x.number+'.</span>':'')+'<span>'+esc(x.text)+'</span></span>').join('')+'</span>'+(checks.length?'<span class="pupil-list-progress">'+checks.filter(x=>x.checked).length+' / '+checks.length+' Listenpunkte</span>':'')+(lines.length>3?'<span class="pupil-list-progress">+'+(lines.length-3)+' weitere Zeilen</span>':'');
}
function pupilEventLabel(item){const label={'Orga-Aufgabe':'Termin','Erinnerung':'Erinnerung','Ziel überprüfen':'Überprüfung','Hausübung prüfen':'Abgabe'}[item.kind]||item.kind;if(!item.due)return '';const date=item.due.slice(0,10),when=date===day()?'Heute':shortDay(date),time=item.due.length>10?new Date(item.due).toLocaleTimeString('de-AT',{hour:'2-digit',minute:'2-digit'}):'';return label+': '+when+(time?' · '+time:'')+(date<day()?' · überfällig':'');}
function pupilOverviewRecord(e,events=[]){
 const state=overviewState(e),expanded=overviewExpandedRecords.has(e.id),due=events.some(x=>x.due&&pupilWorkPriority(x)<=1),label=e.contextOnly?'Beteiligt':state?.text||'',recordTitle=pupilRecordText(e).slice(0,100)||pupilCategoryLabel(e.category);
 const meta='<span class="pupil-record-meta"><span>'+esc(pupilCategoryLabel(e.category))+'</span>'+(label?'<span class="pupil-record-status '+(state?.tone||'')+'">'+esc(label)+'</span>':'')+'</span>';
 const dates=events.map(pupilEventLabel).filter(Boolean),timing=dates.length?dates.map(x=>'<span>'+esc(x)+'</span>').join(''):'<time datetime="'+esc(e.at)+'">'+esc(shortDay(e.at.slice(0,10)))+'</time>';
 const preview=meta+pupilPreviewHTML(e)+'<span class="pupil-record-dates">'+timing+'</span>'+(pendingFollowUp(e)?'<span class="pupil-needs-completion">Dokumentation ergänzen</span>':'');
 if(e.overviewSynthetic)return '<article class="pupil-record'+(due?' is-due':'')+'"><button type="button" class="pupil-record-open" data-open-hw="'+esc(e.homeworkId)+'">'+preview+'</button></article>';
 let action='';if(orgTaskOpen(e))action='<button type="button" data-org-complete="'+esc(e.id)+'">Erledigen</button>';else if(e.category==='Ziele'&&goalIsActive(e))action='<button type="button" data-goal-review="'+esc(e.id)+'">Überprüfen</button>';else if(e.kind==='assigned'&&events.length)action='<button type="button" data-open-hw="'+esc(e.homeworkId)+'">Prüfen</button>';
 return '<article class="pupil-record'+(due?' is-due':'')+'"><details class="overview-record" data-overview-record="'+esc(e.id)+'" '+(expanded?'open':'')+'><summary aria-label="'+esc(recordTitle)+' – Details"><span class="pupil-record-summary">'+preview+'</span><span class="pupil-record-chevron" aria-hidden="true">⌄</span></summary><div class="overview-record-full">'+entryMarkup(e)+'</div></details>'+(action?'<div class="pupil-record-action">'+action+'</div>':'')+'</article>';
}
function pupilOverviewSection(key,title,rows,limit,render,empty=''){
 if(!rows.length)return empty?'<p class="pupil-section-empty">'+esc(empty)+'</p>':'';
 const stateKey=active+'|pupil-'+key,expanded=overviewShowAll.has(stateKey),shown=expanded?rows:rows.slice(0,limit);
 return '<section class="pupil-summary-section"><h3>'+esc(title)+' <span>'+rows.length+'</span></h3><div class="pupil-record-list">'+shown.map(render).join('')+'</div>'+(rows.length>limit?'<button type="button" class="overview-more" data-overview-more="'+esc(stateKey)+'">'+(expanded?'Weniger anzeigen':(rows.length-limit)+' weitere anzeigen')+'</button>':'')+'</section>';
}
function pupilOverviewResults(model){
 let html='';if(model.query||overviewFilter==='week')html=pupilOverviewSection('results',model.query?'Suchergebnisse':'Diese Woche',model.filtered,20,e=>pupilOverviewRecord(e),model.query?'Keine passenden Einträge.':'Diese Woche noch keine Einträge.');
 else{
  html=pupilOverviewSection('pending','Anstehend',model.pending,overviewFilter==='open'?12:3,row=>pupilOverviewRecord(row.entry,row.events),'Keine offenen Aufgaben, Ziele oder Erinnerungen.');
  html+=pupilOverviewSection('docs','Noch ergänzen',model.docs,overviewFilter==='open'?12:2,e=>pupilOverviewRecord(e));
  if(overviewFilter==='all')html+=pupilOverviewSection('recent','Zuletzt',model.recent,3,e=>pupilOverviewRecord(e));
 }
 if(model.legacy.length)html+='<details class="pupil-legacy"><summary>Frühere Einträge · '+model.legacy.length+'</summary>'+model.legacy.slice().reverse().map(e=>'<article class="entry">'+(e.date&&validTime(e.date)?'<time>'+esc(fullDate(e.date))+'</time>':'')+'<p>'+esc([...(Array.isArray(e.values)?e.values:[]),e.task,e.text].filter(Boolean).join('\n'))+'</p></article>').join('')+'</details>';
 return '<div id="pupilOverviewResults">'+html+'<button type="button" class="pupil-history-link" data-history>Gesamter Verlauf <span aria-hidden="true">→</span></button></div>';
}
function pupilOverviewHTML(){const model=pupilOverviewModel();return '<div class="pupil-overview-toolbar">'+overviewFilterControls()+'<button type="button" id="overviewSearchToggle" class="overview-icon" aria-label="Einträge durchsuchen" aria-expanded="'+!!pupilOverviewQuery+'" title="Einträge durchsuchen">'+icon('search')+'</button><details class="overview-menu" id="overviewTools"><summary aria-label="Schüleraktionen" title="Schüleraktionen"><span aria-hidden="true">•••</span></summary><div><button type="button" id="managePupil">Schüler bearbeiten</button><button type="button" id="prepareBrief">Gespräch vorbereiten</button><button type="button" id="pupilDrafts">Gesicherte Entwürfe</button></div></details></div><div class="overview-search" '+(pupilOverviewQuery?'':'hidden')+'><input id="pupilOverviewSearch" type="search" value="'+esc(pupilOverviewQuery)+'" placeholder="Suchen …" aria-label="Schülereinträge durchsuchen"><button type="button" id="overviewSearchClear" aria-label="Suche schließen">×</button></div><nav class="pupil-category-links" aria-label="Eintrag erfassen">'+[['Ziele','goal','Ziele'],['Sozialverhalten','social','Sozial'],['Arbeitsverhalten','work','Arbeit'],['Hausübung','home','HÜ'],['Organisatorisches','org','Orga']].map(([key,glyph,label])=>'<button type="button" data-category="'+key+'" aria-label="'+esc(key)+' öffnen">'+icon(glyph)+'<span>'+label+'</span></button>').join('')+'</nav>'+pupilOverviewResults(model);}
