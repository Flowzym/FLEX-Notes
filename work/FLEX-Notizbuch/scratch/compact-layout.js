const menuButton=document.createElement('button');menuButton.type='button';menuButton.id='mobileMenu';menuButton.className='page-menu';menuButton.setAttribute('aria-controls','navigationSidebar');menuButton.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg>';
const pageTitle=$('.page-head h1').parentElement;pageTitle.classList.add('page-title');pageTitle.prepend(menuButton);document.querySelector('.sidebar').id='navigationSidebar';
const sidebarFooter=$('.sidebar-foot');sidebarFooter.replaceChildren($('#storageState'));$('#storageState').setAttribute('role','status');$('#storageState').setAttribute('aria-live','polite');
const previousSetSidebar=setSidebar;setSidebar=function(collapsed,remember=false){previousSetSidebar(collapsed,remember);menuButton.setAttribute('aria-expanded',String(!collapsed));const label=collapsed?'Navigation öffnen':'Navigation schließen';menuButton.setAttribute('aria-label',label);menuButton.title=label;const sidebar=document.querySelector('.sidebar');sidebar.inert=sidebarMedia.matches&&collapsed;if(sidebarMedia.matches&&collapsed){sidebar.setAttribute('aria-hidden','true');if(sidebar.contains(document.activeElement))menuButton.focus();}else sidebar.removeAttribute('aria-hidden');};
menuButton.onclick=()=>{const open=$('#appShell').classList.contains('is-collapsed');setSidebar(!open,true);if(open&&sidebarMedia.matches)$('#sidebarToggle').focus();};
function compactLayout(){setSidebar(sidebarMedia.matches?true:$('#appShell').classList.contains('is-collapsed'));}
sidebarMedia.addEventListener('change',compactLayout);compactLayout();
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&sidebarMedia.matches&&$('#appShell').classList.contains('is-collapsed')&&!document.querySelector('dialog[open]'))menuButton.focus();});
$('#addStudent').setAttribute('aria-label','Schüler hinzufügen');$('#addStudent').title='Schüler hinzufügen';$('#addStudent').classList.remove('primary');$('#addStudent').classList.add('icon-btn');$('#addStudent').innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="9" cy="7" r="3.5"/><path d="M2.5 21v-2a6.5 6.5 0 0 1 13 0v2M19 7v6m-3-3h6"/></svg>';
const searchPanel=$('#studentSearch').closest('.search-wrap');searchPanel.id='studentSearchPanel';searchPanel.hidden=true;
const searchToggle=document.createElement('button');searchToggle.type='button';searchToggle.id='toggleStudentSearch';searchToggle.className='icon-btn';searchToggle.setAttribute('aria-label','Schüler suchen');searchToggle.setAttribute('aria-expanded','false');searchToggle.setAttribute('aria-controls','studentSearchPanel');searchToggle.title='Schüler suchen';searchToggle.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4.5 4.5"/></svg>';$('#addStudent').after(searchToggle);
const closeSearch=document.createElement('button');closeSearch.type='button';closeSearch.className='close-student-search';closeSearch.setAttribute('aria-label','Suche schließen und zurücksetzen');closeSearch.title='Suche schließen';closeSearch.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>';searchPanel.append(closeSearch);
function toggleStudentSearch(open){searchPanel.hidden=!open;searchToggle.setAttribute('aria-expanded',String(open));searchToggle.classList.toggle('is-active',open);if(open){$('#studentSearch').focus();}else{$('#studentSearch').value='';renderStudents();searchToggle.focus();}}
searchToggle.onclick=()=>toggleStudentSearch(searchPanel.hidden);closeSearch.onclick=()=>toggleStudentSearch(false);
searchPanel.addEventListener('keydown',e=>{if(e.key==='Escape'){e.preventDefault();e.stopPropagation();toggleStudentSearch(false);}});
const switchPageWithSearch=switchPage;switchPage=function(view){switchPageWithSearch(view);searchToggle.hidden=view!=='students'&&view!=='archive';};

// Keep the existing controls and listeners together while the cards scroll.
const workspaceHeader=document.createElement('div');workspaceHeader.className='workspace-header';
const workspace=document.querySelector('.workspace');
while(workspace.firstChild&&workspace.firstChild!==$('#students'))workspaceHeader.append(workspace.firstChild);
workspace.prepend(workspaceHeader);
// Search, bulk selection and save warnings can change the header height.
// Reserve its current height when keyboard focus scrolls a card into view.
function updatePinnedHeader(){
 const height=workspaceHeader.getBoundingClientRect().height,available=window.visualViewport?.height||innerHeight;
 const flowing=height>Math.max(120,available*.55);
 workspaceHeader.classList.toggle('is-flowing',flowing);
 document.documentElement.style.setProperty('--workspace-header-height',(flowing?0:height)+'px');if(typeof updateContentClip==='function')updateContentClip();
}
new ResizeObserver(updatePinnedHeader).observe(workspaceHeader);
window.addEventListener('resize',updatePinnedHeader);
window.visualViewport?.addEventListener('resize',updatePinnedHeader);
updatePinnedHeader();
