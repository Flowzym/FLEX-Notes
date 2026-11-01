function configureImportReview(){
 configureAppearanceImport();
 let notice=$('#recoveryNotice');
 if(!notice){notice=document.createElement('section');notice.id='recoveryNotice';notice.innerHTML='<p>Die vorhandenen Daten konnten nicht sicher geladen werden. Die Sicherung wird als neuer Datenstand wiederhergestellt. Der bisherige Speicher bleibt zur Diagnose erhalten.</p><button type="button" id="exportDamagedStorage">Bisherigen Speicher als Datei sichern</button><label class="import-choice"><input type="checkbox" id="confirmRecovery">Diese Sicherung als neuen Datenstand verwenden</label>';$('#importSummary').after(notice);$('#exportDamagedStorage').onclick=()=>{const raw={format:'FLEX-Rohdaten',capturedAt:new Date().toISOString(),storage:{}};for(const key of Object.keys(localStorage).filter(k=>k===KEY||k.startsWith(KEY+':')))raw.storage[key]=localStorage.getItem(key);downloadText('FLEX-Rohdaten-'+day()+'.json',JSON.stringify(raw,null,2),'application/json');};}
 notice.hidden=canStore;$('#confirmRecovery').checked=false;
 $('#importReview').querySelectorAll('input[name="importPolicy"]').forEach(input=>input.closest('label').hidden=!canStore);
 $('#confirmImport').textContent=canStore?'Import übernehmen':'Sicherung wiederherstellen';
}
function mergeImportedState(current,incoming,policy,options){
 const merged=normalizeDomainState(copy(current)),source=normalizeDomainState(copy(incoming));
 for(const key of COLLECTIONS){merged[key]||=[];const indices=new Map(merged[key].map((item,index)=>[item.id,index]));for(const item of source[key]||[]){const index=indices.get(item.id),old=index===undefined?null:merged[key][index];if(!old){indices.set(item.id,merged[key].length);merged[key].push(copy(item));continue;}
  const useIncoming=policy==='incoming'||(policy!=='keep'&&item._updatedAt&&(!old._updatedAt||item._updatedAt>old._updatedAt)),chosen=copy(useIncoming?item:old);
  if(key!=='conflicts'&&!sameValue(old,item)){for(const field of new Set([...Object.keys(old),...Object.keys(item)])){if(['history','goalReviews','_updatedAt','_importUpdatedAt'].includes(field)||sameValue(old[field],item[field]))continue;addConflict(merged,chosen,field,null,old[field],item[field],'import:'+domainHash(item));}}
  if(key!=='conflicts'){const snapshots=[];for(const row of (sameValue(recordContent(old),recordContent(item))?[]:[old,item])){const record=copy(row);delete record.history;snapshots.push({id:'import:'+domainHash(record),changedAt:row._updatedAt||row.recordedAt||row.at||now(),record});}chosen.history=unionHistory(old.history||[],item.history||[],snapshots);if(key==='entries')chosen.goalReviews=unionRecords(old.goalReviews||[],item.goalReviews||[]);}
  if(key==='students'&&!validPupilColor(chosen.color)&&validPupilColor(old.color))chosen.color=old.color;
  if(useIncoming)chosen._importUpdatedAt=item._updatedAt||new Date().toISOString();merged[key][index]=chosen;
 }}
 merged.legacy||=[];const ids=new Set(merged.legacy.map(item=>item.id));for(const item of incoming.legacy||[])if(!ids.has(item.id)){merged.legacy.push(copy(item));ids.add(item.id);}
 if(options)for(const key of ['behaviorOptions','reminderOptions','favorites'])if(incoming[key]!=null)merged[key]=copy(incoming[key]);
 return merged;
}
function importDrafts(incoming){
 let failed=false;for(const original of incoming.savedDrafts||[]){const item={...copy(original),updated:validTime(original.updated)?original.updated:now()};if(!db.students.some(s=>s.id===item.studentId)||!CATS.some(c=>c[0]===item.category))continue;const key=DRAFT_PREFIX+'import:'+domainHash(item);try{localStorage.setItem(key,JSON.stringify(item));}catch{failed=true;retainUnstoredDraft(key,item);}}
 for(const item of incoming.editorDrafts||[])if(!saveImportedEditorDraft(item))failed=true;
 restoreLatestDrafts();drawDraftBanner();if(failed)setSaveStatus(false,'Importierte Entwürfe nur in dieser Sitzung – bitte exportieren');return !failed;
}
function recoverImportedState(incoming){
 const recovered=derive(copy(incoming));delete recovered.savedDrafts;delete recovered.preferences;delete recovered.backupMeta;assignStudentColors(recovered.students);
 if(!valid(recovered))throw Error('Die Sicherung enthält einen ungültigen Datenstand.');
 const nextRoot=KEY+':store:'+uid(),seed=nextRoot+':seed-v4',raw=JSON.stringify(recovered);
 // The only commit is the pointer. Old seeds, operations and drafts are untouched.
 localStorage.setItem(seed,raw);
 if(localStorage.getItem(seed)!==raw)throw Error('Der neue Datenstand konnte nicht geprüft werden.');
 localStorage.setItem(KEY+':active-store',nextRoot);
 storageRoot=nextRoot;SEED_KEY=seed;OP_PREFIX=nextRoot+':op:';DRAFT_PREFIX=nextRoot+':draft-v4:';
 db=recovered;baseline=copy(db);canStore=true;drafts.clear();restoredSources.clear();
 try{localStorage.setItem(KEY,JSON.stringify(db));}catch{}
 $('#error').textContent='';$('#error').classList.add('hidden');setSaveStatus(true,'Sicherung wiederhergestellt');
}
function commitImportRecords(){
 if(!pendingImport)return;
 if(!valid(pendingImport)){toast('Die Sicherung enthält ungültige Daten. Es wurde nichts übernommen.');return;}
 if(!canStore){
  if(!$('#confirmRecovery')?.checked){toast('Bitte die Wiederherstellung als neuen Datenstand bestätigen.');return;}
  try{recoverImportedState(pendingImport);}catch{toast('Wiederherstellung nicht gespeichert. Der bisherige Speicher bleibt erhalten.');return;}
 }else{
  const prior=db,merged=mergeImportedState(db,pendingImport,$('input[name="importPolicy"]:checked').value,$('#importOptionLists').checked);
  if(!valid(merged)){toast('Die zusammengeführten Daten sind ungültig oder überschreiten die Grenze von 500 Schülern bzw. 50.000 Einträgen je Bereich. Es wurde nichts übernommen.');return;}
  db=merged;if(!persist()){db=prior;toast('Import nicht gespeichert. Bitte erneut versuchen.');return;}
 }
 const draftsSaved=importDrafts(pendingImport);const appearanceFailed=!!pendingImport.preferences&&$('#importAppearance')?.checked&&!savePreferences(pendingImport.preferences);
 pendingImport=null;$('#importReview').close();$('#backupDialog').close();renderStudents();toast(appearanceFailed?'Daten übernommen. Darstellung konnte nicht gespeichert werden.':'Sicherung übernommen.');if(appearanceFailed){warn('Die Unterrichtsdaten wurden übernommen. Darstellung und Hintergrundbild konnten nicht gespeichert werden. Bitte Speicherplatz prüfen und die Darstellung erneut importieren.');}
}
window.addEventListener('storage',event=>{
 if(event.key===KEY+':active-store'&&(localStorage.getItem(event.key)||KEY)!==storageRoot){canStore=false;setSaveStatus(false,'Datenstand wurde in anderem Tab wiederhergestellt');warn('Eine Sicherung wurde in einem anderen Tab wiederhergestellt. Bitte diesen Tab neu laden. Ungespeicherte Bearbeitungen vorher sichern.');}
});
