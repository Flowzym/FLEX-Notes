// Pure domain helpers. No DOM, storage or network access. Legacy input is retained
// in revisions; new fields are additive so old exports remain importable.
function stableJSON(value){if(value===undefined)return 'null';if(value===null||typeof value!=='object')return JSON.stringify(value);if(Array.isArray(value))return '['+value.map(stableJSON).join(',')+']';return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+stableJSON(value[k])).join(',')+'}';}
function sameValue(a,b){return stableJSON(a)===stableJSON(b);}
function domainHash(value){let h=2166136261;for(const ch of stableJSON(value)){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0).toString(36);}
function unionRecords(...lists){const result=[],seen=new Set();for(const item of lists.flat()){if(!item)continue;const key=stableJSON(item);if(!seen.has(key)){result.push(copy(item));seen.add(key);}}return result;}
function unionHistory(...lists){return unionRecords(...lists).sort((a,b)=>String(a.changedAt||'').localeCompare(String(b.changedAt||''))||stableJSON(a).localeCompare(stableJSON(b)));}
function recordContent(value){const out=copy(value);for(const key of ['history','_updatedAt','_importUpdatedAt'])delete out[key];if(out.category==='Ziele')out.goalReviews||=[];return out;}
function contextCode(label){return {'Vor dem Unterricht':'before','Während des Unterrichts':'during','Nach dem Unterricht':'after','Pause':'break'}[label]||'';}
function contextLabel(code){return {before:'Vor dem Unterricht',during:'Während des Unterrichts',after:'Nach dem Unterricht',break:'Pause'}[code]||'';}
function normalizeObservation(e){if(e.category==='Sozialverhalten'){const parts=splitSocialContext(e.text||'');if(parts.tags.length){e.contextCode=contextCode(parts.tags.at(-1));e.text=parts.text;}e.contextCode||='';}e.sourceKind||='own';e.documentationStatus=pendingFollowUp(e)?'needs_completion':'saved';return e;}
function observationText(e){return [contextLabel(e.contextCode),e.situation||'',e.text||''].filter(Boolean).join('\n\n');}
function orgBlocks(text,previous=[],prefix='list'){
 const remaining=[...previous];return String(text||'').split('\n').map((raw,index)=>{const parsed=orgListLine(raw);let i=remaining.findIndex(x=>x&&x.type===parsed.type&&x.text===parsed.text);if(i<0&&remaining[index]?.type===parsed.type)i=index;const old=i<0?null:remaining[i];if(i>=0)remaining[i]=null;return {id:old?.id||prefix+':'+index+':'+domainHash(raw),type:parsed.type,text:parsed.text,indent:parsed.indent||'',number:parsed.number||1,checked:!!parsed.checked};});
}
function orgBlocksText(items){return items.filter(x=>!x.deletedAt).map(x=>x.type==='text'?x.text:(x.indent||'')+(x.type==='check'?'- ['+(x.checked?'x':' ')+'] ':x.type==='number'?x.number+'. ':'- ')+x.text).join('\n');}
function normalizeDomainState(state){
 normalizeOrga(state);
 state.situations||=[];state.classTasks||=[];state.conflicts||=[];state.schemaVersion=5;for(const t of state.classTasks)if(t.text!==orgBlocksText(t.orgItems||[]))t.orgItems=orgBlocks(t.text,t.orgItems||[],t.id);
 for(const e of state.entries){normalizeObservation(e);if(e.category==='Organisatorisches'&&!sameValue(e.text,orgBlocksText(e.orgItems||[])))e.orgItems=orgBlocks(e.text,e.orgItems||[],e.id);if(['Sozialverhalten','Arbeitsverhalten'].includes(e.category)&&!e.situationId&&(e.participants?.length||e.bulkGroupId))attachSituation(state,e,{situationId:'legacy-situation:'+(e.bulkGroupId||e.id)});}
 return state;
}
// Deterministic, additive migration: reminders keep their identity and history.
// Only the source entry is actionable; old generated projections remain hidden.
function normalizeOrga(state){
 for(const r of state.reminders||[]){
  let source=state.entries.find(e=>e.id===r.sourceEntryId)||state.entries.find(e=>e.linkedReminderId===r.id)||state.entries.find(e=>e.id===state.entries.find(p=>p.reminderId===r.id&&p.sourceEntryId)?.sourceEntryId);
  const projections=state.entries.filter(e=>e.reminderId===r.id);
  if(!source){source=projections.find(e=>!e.sourceEntryId);if(!source){source={id:'orga-reminder:'+r.id,studentId:r.studentId,category:'Organisatorisches',text:r.text,choices:[],at:r.createdAt||r.due,orgTask:true,orgDone:!!r.done,orgDue:'',deletedAt:r.deletedAt||null};state.entries.push(source);}else{
   const original=copy(source);delete original.history;
   source.history=unionHistory(source.history||[],[{changedAt:source.recordedAt||source.at,record:original}]);
   source.category='Organisatorisches';source.orgTask=true;source.orgDone=!!r.done;source.orgDue='';
   const suffix='\nErinnern am ';const pos=source.text.lastIndexOf(suffix);if(pos>=0&&source.text.slice(0,pos)===r.text)source.text=r.text;
   source.legacyReminderId=r.id;delete source.reminderId;delete source.sourceEntryId;
  }source.linkedReminderId=r.id;}
  r.sourceEntryId=source.id;if(!r.deletedAt)source.linkedReminderId=r.id;
  for(const e of projections)if(e.id!==source.id)e.sourceEntryId=source.id;
  if(source.deletedAt&&!r.deletedAt)r.deletedAt=source.deletedAt;
  if(source.orgTask&&source.orgDone&&!r.done){r.done=true;r.cancelledByTask=true;}
 }
 for(const e of state.entries||[]){if(e.category==='Erinnerung'&&!e.sourceEntryId){const original=copy(e);delete original.history;e.history=unionHistory(e.history||[],[{changedAt:e.recordedAt||e.at,record:original}]);e.category='Organisatorisches';e.orgTask=true;e.orgDone??=false;}if(e.category==='Organisatorisches'){e.orgTask??=false;e.orgDone??=false;e.orgDue??='';}}
 for(const t of state.classTasks||[]){t.orgTask??=true;t.reminderAt??='';t.reminderDismissed??=false;if(t.orgTask&&t.done)t.reminderDismissed=true;}
 return state;
}
function orgTaskOpen(e){return e.category==='Organisatorisches'&&!e.deletedAt&&!!e.orgTask&&!e.orgDone;}
function orgMatchesFilter(e,filter){return filter==='all'||!!e.orgTask&&(filter==='done'?!!e.orgDone:!e.orgDone);}
function legacyOrgaDraft(d){return {...d,orgTask:true,orgDone:false,orgDue:'',orgReminderEnabled:true,orgReminderDue:d.due||'',orgReminderDone:false};}
function addConflict(state,entity,field,base,current,incoming,opId){
 state.conflicts||=[];const value={entityId:entity.id,field,base:copy(base??null),current:copy(current??null),incoming:copy(incoming??null),operationId:opId};value.id='conflict:'+domainHash(value);if(!state.conflicts.some(x=>x.id===value.id))state.conflicts.push(value);
}
function mergeItems(current,incoming,base,state,entity,field,opId){
 const out=copy(current||[]),old=new Map((base||[]).map(x=>[x.id,x]));
 for(const item of incoming||[]){let target=out.find(x=>x.id===item.id),before=old.get(item.id);if(!target){out.push(copy(item));continue;}for(const [key,value]of Object.entries(item)){if(key==='id'||sameValue(before?.[key],value))continue;if(before&&!sameValue(target[key],before[key])&&!sameValue(target[key],value))addConflict(state,entity,field+'.'+item.id+'.'+key,before[key],target[key],value,opId);else target[key]=copy(value);}}
 // Deletions of lines are represented explicitly; concurrent edits are retained.
 for(const before of base||[]){if((incoming||[]).some(x=>x.id===before.id))continue;const target=out.find(x=>x.id===before.id);if(!target)continue;if(sameValue(target,before))target.deletedAt='removed';else addConflict(state,entity,field+'.'+before.id,before,target,null,opId);}
 return out;
}
function applyDomainPatch(state,current,patch,op){
 const fields=copy(patch.fields||{}),base=patch.base||{};
 if(fields.history){current.history=unionHistory(current.history||[],fields.history);delete fields.history;}
 if(fields.goalReviews){current.goalReviews=unionRecords(current.goalReviews||[],fields.goalReviews).sort((a,b)=>a.at.localeCompare(b.at)||a.id.localeCompare(b.id));delete fields.goalReviews;}
 if(fields.orgItems){current.orgItems=mergeItems(current.orgItems,fields.orgItems,base.orgItems,state,current,'orgItems',op.id);current.text=orgBlocksText(current.orgItems);delete fields.orgItems;delete fields.text;}
 for(const [key,value]of Object.entries(fields)){
  if(patch.base&&Object.hasOwn(base,key)&&!sameValue(current[key],base[key])&&!sameValue(current[key],value)){
   addConflict(state,current,key,base[key],current[key],value,op.id);
   // Deletion wins visibility, but the edited version remains in the conflict.
   if(key==='deletedAt'&&value)current[key]=value;
  }else current[key]=value;
 }
}
function validDomainState(state){
 if(state.schemaVersion!=null&&state.schemaVersion!==5)return false;
 if(state.situations!=null&&(!Array.isArray(state.situations)||state.situations.length>50000||new Set(state.situations.map(s=>s.id)).size!==state.situations.length||!state.situations.every(s=>plainRecord(s)&&typeof s.id==='string'&&typeof s.text==='string'&&validTime(s.at)&&Array.isArray(s.participants)&&s.participants.every(p=>typeof p.studentId==='string'&&typeof p.name==='string')&&(!s.contextCode||['before','during','after','break'].includes(s.contextCode)))))return false;
 if(state.conflicts!=null&&(!Array.isArray(state.conflicts)||state.conflicts.length>50000||!state.conflicts.every(x=>plainRecord(x)&&typeof x.id==='string'&&typeof x.entityId==='string'&&typeof x.field==='string')))return false;
 if(state.classTasks!=null&&(!Array.isArray(state.classTasks)||state.classTasks.length>50000||new Set(state.classTasks.map(t=>t.id)).size!==state.classTasks.length||!state.classTasks.every(t=>commonRecordFields(t)&&typeof t.text==='string'&&typeof t.done==='boolean'&&(!t.due||t.due.length===10&&validTime(t.due)))))return false;
 const entries=new Map(state.entries.map(e=>[e.id,e]));
 return state.entries.every(e=>(!e.goalId||(entries.get(e.goalId)?.category==='Ziele'&&entries.get(e.goalId)?.studentId===e.studentId))&&(!e.situationId||state.situations?.some(s=>s.id===e.situationId))&&(!e.contextCode||['before','during','after','break'].includes(e.contextCode))&&(!e.sourceKind||['own','reported','interpretation'].includes(e.sourceKind))&&(!e.orgItems||Array.isArray(e.orgItems)&&new Set(e.orgItems.map(x=>x.id)).size===e.orgItems.length&&e.orgItems.every(x=>typeof x.id==='string'&&typeof x.text==='string'&&['text','check','number','bullet'].includes(x.type)&&typeof x.checked==='boolean')));
}
function attachSituation(state,entry,values={}){
 if(!['Sozialverhalten','Arbeitsverhalten'].includes(entry.category))return;
 state.situations||=[];let situation=state.situations.find(s=>s.id===(entry.situationId||values.situationId));
 if(!situation){situation={id:values.situationId||uid(),text:values.sharedContext||'',at:entry.at,contextCode:entry.contextCode||'',participants:[]};state.situations.push(situation);entry.situationId=situation.id;}
 entry.situationId=situation.id;if(values.sharedContext!==undefined)situation.text=values.sharedContext;
 const people=[{studentId:entry.studentId,name:state.students.find(s=>s.id===entry.studentId)?.name||entry.studentId},...(entry.participants||[])];
 situation.participants=cleanParticipants([...situation.participants,...people]);return situation;
}
function visibleEntries(state,studentId){
 const own=live(state.entries).filter(e=>e.studentId===studentId&&!e.sourceEntryId);
 const linked=(state.situations||[]).filter(s=>!s.deletedAt&&s.participants.some(p=>p.studentId===studentId)&&!own.some(e=>e.situationId===s.id)&&state.entries.some(e=>!e.deletedAt&&e.situationId===s.id)).map(s=>({id:'situation:'+s.id,studentId,category:'Sozialverhalten',at:s.at,recordedAt:s.at,text:s.text||'Als beteiligt genannt',contextCode:s.contextCode,choices:[],participants:s.participants,situationId:s.id,contextOnly:true}));
 return [...own,...linked].sort((a,b)=>b.at.localeCompare(a.at)||(b.recordedAt||b.at).localeCompare(a.recordedAt||a.at));
}

function localDeviceId(){const key=KEY+':device-id';let id=localStorage.getItem(key);if(!id){id=uid();localStorage.setItem(key,id);}return id;}
function nextLogicalClock(){return Math.max(0,...keysStarting(OP_PREFIX).map(k=>{try{return JSON.parse(localStorage.getItem(k)).logical||0;}catch{return 0;}}))+1;}
