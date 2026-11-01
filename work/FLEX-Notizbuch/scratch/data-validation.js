// Shared by startup, import and recovery. Optional legacy fields may be absent.
function validTime(value){
 if(typeof value!=='string')return false;
 const match=/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?(?:Z|[+-]\d{2}:\d{2})?)?$/.exec(value);
 if(!match)return false;
 const [year,month,date]=match.slice(1,4).map(Number);
 const leap=year%4===0&&(year%100!==0||year%400===0);
 return year>0&&month>=1&&month<=12&&date>=1&&date<=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31][month-1]&&(!match[4]||(Number(match[4])<24&&Number(match[5])<60&&(!match[6]||Number(match[6])<60)))&&Number.isFinite(new Date(value).getTime());
}
function plainRecord(value){return !!value&&typeof value==='object'&&!Array.isArray(value);}
function safeDataTree(value,depth=0){
 if(depth>24)return false;
 if(!value||typeof value!=='object')return true;
 return Object.entries(value).every(([key,item])=>!['__proto__','prototype','constructor'].includes(key)&&safeDataTree(item,depth+1));
}
function optionalFields(row,names,predicate){return names.every(key=>row[key]==null||predicate(row[key]));}
function textFields(row,names){return optionalFields(row,names,value=>typeof value==='string');}
function commonRecordFields(row){return plainRecord(row)&&typeof row.id==='string'&&!!row.id&&
 textFields(row,['studentId','goalId','goalText','homeworkId','reminderId','linkedReminderId','sourceEntryId','taskId','text','task','situation','supportNote','unit','feedbackText','taskComment','goalCriterion','goalStep','kind','delivery'])&&
 optionalFields(row,['archived','needsFollowUp','reviewed','support','done','taskDone','homeworkNote','orgTask','orgDone','reminderDismissed','cancelledByTask'],value=>typeof value==='boolean')&&
 optionalFields(row,['_updatedAt','_importUpdatedAt','recordedAt','createdAt','deletedAt','goalReachedAt'],value=>value===''||validTime(value))&&
 optionalFields(row,['goalDue','goalReviewDue','orgDue'],value=>value===''||(value.length===10&&validTime(value)))&&
 optionalFields(row,['reminderAt'],value=>value===''||validTime(value))&&
 optionalFields(row,['tagFields'],value=>plainRecord(value)&&Object.values(value).every(field=>plainRecord(field)&&Array.isArray(field.tags)&&field.tags.every(t=>typeof t==='string')&&typeof field.free==='string'));
}
function validChoices(value){return Array.isArray(value)&&value.every(c=>plainRecord(c)&&['positive','negative'].includes(c.tone)&&typeof c.text==='string');}
function validEntry(entry,revision=false){
 return commonRecordFields(entry)&&typeof entry.studentId==='string'&&CATS.some(c=>c[0]===entry.category)&&typeof entry.text==='string'&&validTime(entry.at)&&validChoices(entry.choices)&&
 optionalFields(entry,['participants'],v=>Array.isArray(v)&&v.length<=1000&&v.every(p=>plainRecord(p)&&typeof p.name==='string'&&p.name.trim().length>0&&p.name.length<=12000&&typeof p.studentId==='string'))&&
 optionalFields(entry,['goalStatus'],v=>['active','reached','closed'].includes(v))&&
 optionalFields(entry,['goalReviews'],v=>Array.isArray(v)&&v.length<=2000&&v.every(r=>plainRecord(r)&&typeof r.id==='string'&&validTime(r.at)&&['continue','reached','closed','reopen'].includes(r.outcome)&&textFields(r,['note','nextStep'])&&optionalFields(r,['nextDue'],d=>d===''||(d.length===10&&validTime(d)))))&&
 optionalFields(entry,['history'],history=>!revision&&Array.isArray(history)&&history.every(v=>plainRecord(v)&&validTime(v.changedAt)&&validEntry(v.record,true)));
}
function validTaskList(tasks){
 if(!Array.isArray(tasks))return false;
 const ids=new Set();
 for(const task of tasks){if(!plainRecord(task)||typeof task.id!=='string'||!task.id||ids.has(task.id)||typeof task.text!=='string'||!optionalFields(task,['createdAt'],v=>v===''||validTime(v))||!optionalFields(task,['initialStatus'],v=>['offen','erledigt','teilweise','nicht'].includes(v))||!optionalFields(task,['initialDone'],v=>typeof v==='boolean')||!textFields(task,['initialComment']))return false;ids.add(task.id);}
 return tasks.every(task=>!task.parentId||(typeof task.parentId==='string'&&task.parentId!==task.id&&tasks.some(parent=>parent.id===task.parentId&&!parent.parentId)));
}
function valid(value){
 try{
 if(!plainRecord(value)||!safeDataTree(value)||value.version!==3)return false;
 if(!optionalFields(value,['preferences'],validBackupPreferences)||!optionalFields(value,['backupMeta'],v=>plainRecord(v)&&v.format==='FLEX-Backup'&&v.version===1&&validTime(v.createdAt)&&typeof v.includesAppearance==='boolean'&&v.includesAppearance===!!value.preferences))return false;
 for(const [key,limit] of [['students',500],['entries',50000],['homework',50000],['reminders',50000]]){
  if(!Array.isArray(value[key])||value[key].length>limit||value[key].some(row=>!plainRecord(row)||typeof row.id!=='string'||!row.id)||new Set(value[key].map(row=>row.id)).size!==value[key].length)return false;
 }
 if(!optionalFields(value,['behaviorOptions'],validBehaviorOptions)||!optionalFields(value,['reminderOptions'],validReminderOptions))return false;
 if(!value.students.every(s=>commonRecordFields(s)&&typeof s.name==='string'&&s.name.trim().length>0&&s.name.length<=80&&optionalFields(s,['previousNames'],v=>Array.isArray(v)&&v.every(n=>typeof n==='string'))&&textFields(s,['color'])))return false;
 if(!value.entries.every(e=>validEntry(e))||!validDomainState(value))return false;
 if(!value.homework.every(h=>{
  // Homework.taskDone is a dictionary, unlike an entry's taskDone flag.
  const row={...h};delete row.taskDone;
  return commonRecordFields(row)&&typeof h.title==='string'&&typeof h.subject==='string'&&typeof h.due==='string'&&(!h.due||(h.due.length===10&&validTime(h.due)))&&Object.hasOwn(STATUS,h.status)&&optionalFields(h,['tasks'],validTaskList)&&optionalFields(h,['taskDone'],v=>plainRecord(v)&&Object.values(v).every(x=>typeof x==='boolean'))&&optionalFields(h,['taskStatus'],v=>plainRecord(v)&&Object.values(v).every(x=>['offen','erledigt','teilweise','nicht'].includes(x)))&&optionalFields(h,['taskComments'],v=>plainRecord(v)&&Object.values(v).every(x=>typeof x==='string'));
 }))return false;
 if(!value.reminders.every(r=>commonRecordFields(r)&&typeof r.text==='string'&&validTime(r.due)))return false;
 const students=new Set(value.students.map(s=>s.id)),homework=new Map(value.homework.map(h=>[h.id,h])),reminders=new Map(value.reminders.map(r=>[r.id,r]));
 if(![...value.entries,...value.homework,...value.reminders].every(e=>students.has(e.studentId)))return false;
 if(!value.entries.every(e=>(!e.homeworkId||homework.get(e.homeworkId)?.studentId===e.studentId)&&(!e.reminderId||reminders.get(e.reminderId)?.studentId===e.studentId)&&(!e.linkedReminderId||reminders.get(e.linkedReminderId)?.studentId===e.studentId)))return false;
 if(!optionalFields(value,['legacy'],v=>Array.isArray(v)&&v.every(plainRecord)))return false;
 if(!optionalFields(value,['favorites'],v=>plainRecord(v)&&Object.values(v).every(category=>plainRecord(category)&&Object.values(category).every(list=>Array.isArray(list)&&list.every(t=>typeof t==='string')))))return false;
 if(!optionalFields(value,['editorDrafts'],v=>Array.isArray(v)&&v.every(validEditorDraft)))return false;
 if(!optionalFields(value,['savedDrafts'],v=>Array.isArray(v)&&v.every(d=>plainRecord(d)&&plainRecord(d.data)&&typeof d.studentId==='string'&&typeof d.category==='string')))return false;
 return true;
 }catch{return false;}
}
function validBackupPreferences(p){
 if(!plainRecord(p))return false;
 if(!optionalFields(p,['background','backgroundTint'],v=>typeof v==='string'&&/^#[\da-f]{6}$/i.test(v)))return false;
 if(!optionalFields(p,['headerColor','cardColor','buttonColor','fieldColor','modalColor'],v=>v===''||typeof v==='string'&&/^#[\da-f]{6}$/i.test(v)))return false;
 if(!optionalFields(p,['headerTransparency','cardTransparency','modalHeaderTransparency','modalFooterTransparency','buttonTransparency','fieldTransparency','modalTransparency'],v=>Number.isFinite(v)&&v>=0&&v<=100))return false;
 if(!optionalFields(p,['backgroundDim','backgroundTintStrength'],v=>Number.isFinite(v)&&v>=0&&v<=.8))return false;
 if(!optionalFields(p,['backgroundImage'],v=>typeof v==='string'&&v.length<=1200000&&(v===''||/^data:image\/(?:jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(v))))return false;
 return optionalFields(p,['backgroundImageName'],v=>typeof v==='string'&&v.length<=120)&&optionalFields(p,['backgroundMode'],v=>['image','color'].includes(v))&&optionalFields(p,['readabilityProtection','appearanceLinked'],v=>typeof v==='boolean')&&optionalFields(p,['shortcutOrder'],v=>Array.isArray(v)&&v.length<=6&&new Set(v).size===v.length&&v.every(x=>CATS.some(c=>c[0]===x)));
}
