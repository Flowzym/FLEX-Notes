function pillNavigationState(view){
 const primary=view==='today'||view==='students';
 return {primary,moreActive:!primary,moreLabel:primary?'…':({archive:'Archiv',settings:'Einstellungen'}[view]||'…')};
}
function movePageActions(view){
 const actions=$('.head-actions'),host=$(view==='students'||view==='archive'?'.student-tools':'.page-head');
 if(actions&&host&&actions.parentElement!==host)host.append(actions);
}
function setPageMenu(open,focusFirst=false){
 pageMoreMenu.hidden=!open;pageMoreButton.setAttribute('aria-expanded',String(open));
 if(open&&focusFirst)pageMoreMenu.querySelector('#nav button:not(:disabled):not([hidden])')?.focus();
}
function refreshPillNavigation(){
 const state=pillNavigationState(pageView);
 pagePills.classList.toggle('has-more-active',state.moreActive);
 pagePills.querySelectorAll('[data-page]').forEach(button=>{const active=button.dataset.page===pageView;button.classList.toggle('active',active);if(active)button.setAttribute('aria-current','page');else button.removeAttribute('aria-current');});
 pageMoreButton.textContent=state.moreLabel;pageMoreButton.classList.toggle('active',state.moreActive);
 pageMoreButton.setAttribute('aria-label',state.moreActive?state.moreLabel+' – weitere Seiten':'Weitere Seiten');
 if(state.moreActive)pageMoreButton.setAttribute('aria-current','page');else pageMoreButton.removeAttribute('aria-current');
}
function handlePageMenuKeydown(event){
 if(event.key==='Escape'&&!pageMoreMenu.hidden){event.preventDefault();event.stopImmediatePropagation();setPageMenu(false);pageMoreButton.focus();return;}
 if(event.target===pageMoreButton&&['ArrowDown','ArrowUp'].includes(event.key)){
  event.preventDefault();setPageMenu(true,true);
  if(event.key==='ArrowUp')[...pageMoreMenu.querySelectorAll('#nav button:not(:disabled):not([hidden])')].at(-1)?.focus();return;
 }
 if(pageMoreMenu.hidden||!pageMoreMenu.contains(event.target)||!['ArrowDown','ArrowUp','Home','End'].includes(event.key))return;
 const buttons=[...pageMoreMenu.querySelectorAll('#nav button:not(:disabled):not([hidden])')];if(!buttons.length)return;
 const index=buttons.indexOf(document.activeElement),next=event.key==='Home'?0:event.key==='End'?buttons.length-1:(index+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length;
 event.preventDefault();buttons[next].focus();
}
const pagePills=document.createElement('div');pagePills.className='page-pills';
pagePills.innerHTML='<nav class="page-pill-track" aria-label="Hauptnavigation"><button type="button" data-page="today">Übersicht</button><button type="button" data-page="students">Schüler</button><button type="button" id="pageMoreButton" aria-label="Weitere Seiten" aria-controls="pageMoreMenu" aria-expanded="false">…</button></nav><section id="pageMoreMenu" aria-label="Weitere Seiten" hidden></section>';
const pageMoreButton=pagePills.querySelector('#pageMoreButton'),pageMoreMenu=pagePills.querySelector('#pageMoreMenu');
const legacyNavigation=$('#nav');legacyNavigation.setAttribute('aria-label','Weitere Seiten');
legacyNavigation.querySelectorAll('[data-page="today"],[data-page="students"]').forEach(button=>button.hidden=true);
pageMoreMenu.append(legacyNavigation);
const pageMenuStatus=document.createElement('div');pageMenuStatus.className='page-menu-status';pageMenuStatus.append($('#storageState'));pageMoreMenu.append(pageMenuStatus);
$('.page-head').insertBefore(pagePills,$('.head-actions'));
document.documentElement.classList.add('has-pill-navigation');
$('#mobileMenu')?.remove();
// Legacy media/storage listeners may still call setSidebar; keep their hidden
// rail collapsed so they cannot make the new workspace inert on small screens.
const sidebarBeforePills=setSidebar;setSidebar=function(){sidebarBeforePills(true,false);};setSidebar();
const oldSidebar=document.querySelector('.sidebar');oldSidebar.hidden=true;oldSidebar.inert=true;
pageMoreButton.onclick=()=>setPageMenu(pageMoreMenu.hidden);
document.addEventListener('pointerdown',event=>{if(!pageMoreMenu.hidden&&!pagePills.contains(event.target))setPageMenu(false);});
document.addEventListener('focusin',event=>{if(!pageMoreMenu.hidden&&!pagePills.contains(event.target))setPageMenu(false);});
document.addEventListener('keydown',handlePageMenuKeydown,true);
const switchPageBeforePills=switchPage;switchPage=function(view){switchPageBeforePills(view);setPageMenu(false);refreshPillNavigation();movePageActions(view);(pillNavigationState(view).moreActive?pageMoreButton:pagePills.querySelector('[data-page="'+view+'"]'))?.focus({preventScroll:true});updatePinnedHeader();};
refreshPillNavigation();movePageActions(pageView);updatePinnedHeader();
