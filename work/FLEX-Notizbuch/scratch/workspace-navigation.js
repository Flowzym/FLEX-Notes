// Hide scrolling content geometrically behind the pinned header. Its transparency
// still reveals the original body background, including the correctly aligned image.
function contentClipTop(headerBottom,contentTop,flowing=false){return flowing?0:Math.max(0,headerBottom-contentTop);}
function updateContentClip(){const content=$('#workspaceContent'),header=$('.workspace-header');if(!content||!header)return;content.style.setProperty('--content-clip-top',contentClipTop(header.getBoundingClientRect().bottom,content.getBoundingClientRect().top,header.classList.contains('is-flowing'))+'px');}
const workspaceContent=document.createElement('div');workspaceContent.id='workspaceContent';const pinnedHeader=$('.workspace-header');while(pinnedHeader.nextSibling)workspaceContent.append(pinnedHeader.nextSibling);pinnedHeader.after(workspaceContent);
let contentClipFrame=0;function scheduleContentClip(){if(contentClipFrame)return;contentClipFrame=requestAnimationFrame(()=>{contentClipFrame=0;updateContentClip();});}
window.addEventListener('scroll',scheduleContentClip,{passive:true});window.addEventListener('resize',scheduleContentClip);window.visualViewport?.addEventListener('resize',scheduleContentClip);window.visualViewport?.addEventListener('scroll',scheduleContentClip);
const contentClipObserver=new ResizeObserver(scheduleContentClip);contentClipObserver.observe(pinnedHeader);contentClipObserver.observe(workspaceContent);updateContentClip();
const archiveNav=document.createElement('button');archiveNav.type='button';archiveNav.dataset.page='archive';archiveNav.title='Archiv';archiveNav.setAttribute('aria-label','Archiv');archiveNav.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M4 8h16v12H4zM3 4h18v4H3zM9 12h6"/></svg><span>Archiv</span>';$('#nav [data-page="students"]').after(archiveNav);
$('#showArchive')?.closest('label').remove();
