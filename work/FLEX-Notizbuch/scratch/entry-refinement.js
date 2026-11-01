function goalPresetDate(kind,base=new Date()){
 const d=new Date(base.getFullYear(),base.getMonth(),base.getDate(),12);
 if(kind==='friday')d.setDate(d.getDate()+(5-d.getDay()+7)%7);
 if(kind==='week')d.setDate(d.getDate()+7);
 if(kind==='fortnight')d.setDate(d.getDate()+14);
 if(kind==='month'){const original=d.getDate();d.setDate(1);d.setMonth(d.getMonth()+1);d.setDate(Math.min(original,new Date(d.getFullYear(),d.getMonth()+1,0).getDate()));}
 return day(d);
}
function enhanceEntryRefinements(){
 document.querySelectorAll('details.meta-details,details.entry-edit-meta,details.goal-edit-meta,details.hw-extra').forEach(details=>{
  const summary=details.querySelector(':scope>summary');if(!summary)return;
  const section=document.createElement('section');section.className=details.className+' entry-additional';section.hidden=details.hidden;
  const heading=document.createElement('h3');heading.textContent=summary.textContent==='Zeitpunkt & Kontext'?'Weitere Angaben':summary.textContent;section.append(heading);
  for(const child of [...details.childNodes])if(child!==summary)section.append(child);details.replaceWith(section);
 });
 for(const id of ['goalDue','recordGoalDue']){const input=document.getElementById(id);if(!input||document.querySelector('[data-goal-presets="'+id+'"]'))continue;
  const source=document.createElement('div');source.className='goal-date-presets';source.dataset.goalPresets=id;source.setAttribute('role','group');source.setAttribute('aria-label','Zieltermin auswählen');
  source.innerHTML=[['friday','Bis Freitag'],['week','Eine Woche'],['fortnight','Zwei Wochen'],['month','Ein Monat']].map(([key,label])=>`<button type="button" data-goal-preset="${key}" aria-pressed="${input.value===goalPresetDate(key)}">${label}</button>`).join('');
  input.closest('.field').querySelector('label').after(source);
  source.onclick=e=>{const b=e.target.closest('[data-goal-preset]');if(!b)return;input.value=goalPresetDate(b.dataset.goalPreset);emitDateChange(input);};
  input.addEventListener('change',()=>source.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(input.value===goalPresetDate(b.dataset.goalPreset)))));
 }
 document.querySelectorAll('#newGoal,[data-homemode="new"],#newOptionForm button[type=submit]').forEach(button=>{
  if(button.dataset.addRefined)return;button.dataset.addRefined='true';button.classList.add('add-action');const label=button.textContent.trim().replace(/^\+\s*/,'');button.innerHTML='<span class="add-action-icon" aria-hidden="true">+</span><span></span>';button.lastElementChild.textContent=label;
 });
 const archive=$('#showArchive');if(archive){archive.classList.add('entry-switch');archive.setAttribute('role','switch');}
}
AppFlows.use('renderModal','entry-refinement',entryRefinedRender=>function(){entryRefinedRender();enhanceEntryRefinements();});
AppFlows.use('editRecord','entry-refinement',entryRefinedEdit=>function(id){entryRefinedEdit(id);enhanceEntryRefinements();});
const entryRefinedBulk=renderBulkForm;renderBulkForm=function(){entryRefinedBulk();if(bulkCategory==='Hausübung'){
 const field=$('#bulkTitleInput'),d=bulkData;if(!Array.isArray(d.hwRows)||homeworkTasksTitle(d.hwRows)!==d.title)d.hwRows=homeworkLinesToTasks(d.title);if(!d.hwRows.length)d.hwRows=[{id:uid(),text:'',parentId:null}];field.hidden=true;field.insertAdjacentHTML('afterend',taskEditorRows(d.hwRows,'bulk'));
 }enhanceEntryRefinements();};
const entryRefinementObserver=new MutationObserver(enhanceEntryRefinements);entryRefinementObserver.observe(document.body,{childList:true,subtree:true});enhanceEntryRefinements();
