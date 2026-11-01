function updateStorageFeedback(){
 const header=document.querySelector('.workspace-header');if(!header)return;
 const owners=[header,...document.querySelectorAll('dialog[open]')];
 for(const owner of owners){let alert=owner.querySelector(':scope > .storage-alert');if(saveHealthy){alert?.remove();continue;}if(!alert){alert=document.createElement('div');alert.className='storage-alert';alert.setAttribute('role','alert');alert.innerHTML='<span></span><button type="button" data-export-unsaved>Sicherung exportieren</button>';const head=owner.matches('dialog')?owner.querySelector('.modal-head'):null;if(head)head.after(alert);else owner.prepend(alert);}const text=saveText+'. Bitte Fenster offen lassen und erneut speichern.';if(alert.firstElementChild.textContent!==text)alert.firstElementChild.textContent=text;}
 if(saveHealthy)document.querySelectorAll('.storage-alert').forEach(el=>el.remove());
}
document.addEventListener('click',event=>{if(event.target.closest('[data-export-unsaved]'))$('#exportData').click();});
AppFlows.use('renderModal','storage-feedback',next=>function(...args){const result=next.apply(this,args);updateStorageFeedback();return result;});
AppFlows.use('editRecord','storage-feedback',next=>function(...args){const result=next.apply(this,args);updateStorageFeedback();return result;});
updateStorageFeedback();

const storageFeedbackObserver=new MutationObserver(updateStorageFeedback);storageFeedbackObserver.observe(document.body,{attributes:true,attributeFilter:['open'],subtree:true});
