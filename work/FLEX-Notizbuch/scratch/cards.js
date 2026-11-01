function studentCard(s,entries,hw,due){
 const color=pupilColor(s);
 const openReminders=live(db.reminders).filter(r=>r.studentId===s.id&&!r.done);
 const counts={
  'Sozialverhalten':{value:entries.filter(e=>e.category==='Sozialverhalten'&&pendingFollowUp(e)).length,label:'Sozial-Dokumentationen zu ergänzen'},
  'Arbeitsverhalten':{value:entries.filter(e=>e.category==='Arbeitsverhalten'&&pendingFollowUp(e)).length,label:'Arbeits-Dokumentationen zu ergänzen'},
  'Hausübung':{value:hw.length,label:hw.length===1?'offene Hausübung':'offene Hausübungen',due:hw.some(h=>h.due&&h.due<=day())},
  'Ziele':{value:entries.filter(e=>e.category==='Ziele'&&goalIsActive(e)).length,label:'aktive Ziele'},
  'Organisatorisches':{value:entries.filter(e=>e.category==='Organisatorisches'&&e.orgTask&&!e.orgDone).length,label:'offene Orga-Aufgaben',due:entries.some(e=>e.category==='Organisatorisches'&&e.orgTask&&!e.orgDone&&e.orgDue&&e.orgDue<=day())},
  'Erinnerung':{value:openReminders.length,label:openReminders.length===1?'offene Erinnerung':'offene Erinnerungen',due:due.length>0}
 };
 const countLabel=category=>counts[category]?.value?`, ${counts[category].value} ${counts[category].value===1&&category==='Ziele'?'aktives Ziel':counts[category].value===1&&category==='Organisatorisches'?'offene Orga-Aufgabe':counts[category].label}`:'';
 const countBadge=category=>{const c=counts[category];return c?.value?`<span class="shortcut-count${c.due?' is-due':''}">${c.value>99?'99+':c.value}</span>`:'';};
 const shortcuts=[['Ziele','goal','Ziele'],['Sozialverhalten','social','Sozial'],['Arbeitsverhalten','work','Arbeit'],['Hausübung','home','HÜ'],['Organisatorisches','org','Orga']];
 if(typeof appPreferences!=='undefined')shortcuts.sort((a,b)=>appPreferences.shortcutOrder.indexOf(a[0])-appPreferences.shortcutOrder.indexOf(b[0]));
 return `<article style="--card-accent:${color};--card-tint:${color}18" class="student-card${s.archived?' is-archived':''}" aria-label="${esc(s.name)}"><button type="button" class="card-open student-line" data-student="${esc(s.id)}" aria-label="${esc(s.name)} öffnen"><span class="student-name">${esc(s.name)}</span><span class="arrow" aria-hidden="true">${icon('arrow')}</span></button>${s.archived?'<span class="student-meta">Archiviert</span>':''}<div class="card-shortcuts" role="group" aria-label="Schnelleintrag für ${esc(s.name)}">${shortcuts.map(([category,glyph,label])=>`<button type="button" class="card-shortcut" data-quick-student="${esc(s.id)}" data-quick-category="${esc(category)}" title="${esc(category+countLabel(category))}" aria-label="${esc(category)} für ${esc(s.name)} öffnen${esc(countLabel(category))}"><span class="shortcut-icon" aria-hidden="true">${icon(glyph)}${countBadge(category)}</span><span>${label}</span>${counts[category]?.value?'<small class="shortcut-meaning">'+(['Sozialverhalten','Arbeitsverhalten'].includes(category)?'ergänzen':category==='Ziele'?'in Arbeit':'offen')+'</small>':''}</button>`).join('')}</div></article>`;
}
document.addEventListener('click',e=>{const button=e.target.closest('[data-quick-student]');if(!button)return;openStudent(button.dataset.quickStudent);section=button.dataset.quickCategory;tone='positive';feedbackId=null;if(section==='Hausübung')homeMode=db.homework.some(h=>h.studentId===active&&!h.deletedAt)?'feedback':'new';renderModal();});

