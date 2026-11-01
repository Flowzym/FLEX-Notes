function pageSwipeDestination(page,pages,dx,dy,elapsed){
 if(elapsed>2500||Math.abs(dx)<48||Math.abs(dx)<Math.abs(dy)*1.35)return null;
 const index=pages.indexOf(page);if(index<0)return null;
 return pages[index+(dx<0?1:-1)]||null;
}
function createPageSwipeController({getPage,getPages,isBlocked,onNavigate,now=()=>Date.now()}){
 let gesture=null,suppressClickUntil=0;
 const cancel=()=>{gesture=null;};
 return {
  start(event){cancel();suppressClickUntil=0;if(event.touches.length!==1||isBlocked(event.target))return;const touch=event.touches[0];gesture={id:touch.identifier,x:touch.clientX,y:touch.clientY,at:now(),page:getPage(),target:event.target,locked:false};},
  move(event){if(!gesture)return;if(event.touches.length!==1){cancel();return;}const touch=event.touches[0];if(touch.identifier!==gesture.id){cancel();return;}const dx=touch.clientX-gesture.x,dy=touch.clientY-gesture.y;
   if(!gesture.locked&&Math.abs(dy)>8&&Math.abs(dy)>=Math.abs(dx)*1.1){cancel();return;}
   // Claim the first clearly horizontal movement, before native scrolling owns it.
   if(!gesture.locked&&Math.abs(dx)>=4&&Math.abs(dx)>Math.abs(dy)*1.35)gesture.locked=true;
   if(gesture.locked){if(!event.cancelable){cancel();return;}event.preventDefault();}
  },
  end(event){const start=gesture;cancel();if(!start||event.touches.length||event.changedTouches.length!==1)return;const touch=event.changedTouches[0];if(touch.identifier!==start.id)return;
   const dx=touch.clientX-start.x,dy=touch.clientY-start.y;
   if(start.locked)suppressClickUntil=now()+500;
   if(getPage()!==start.page||isBlocked(start.target))return;
   const destination=pageSwipeDestination(start.page,getPages(),dx,dy,now()-start.at);if(!destination)return;
   if(event.cancelable)event.preventDefault();suppressClickUntil=now()+500;onNavigate(destination);
  },
  cancel,
  clearClickSuppression(){suppressClickUntil=0;},
  active(){return !!gesture;},
  dragging(){return !!gesture?.locked;},
  consumeClick(event){return event.detail!==0&&now()<suppressClickUntil;}
 };
}
function pageSwipePages(){return ['today','students'];}
function pageSwipeBlocked(target){
 const selection=window.getSelection?.();if(document.querySelector('dialog[open]')||!pageMoreMenu.hidden||(selection&&!selection.isCollapsed))return true;
 if(!target?.closest||target.closest('input,textarea,select,label,a,[contenteditable]:not([contenteditable="false"]),[role="slider"],[role="switch"],#pageMoreMenu,[data-no-page-swipe]'))return true;
 for(let node=target;node&&node!==pageSwipeWorkspace;node=node.parentElement){if(node.scrollWidth>node.clientWidth+2&&/auto|scroll/.test(getComputedStyle(node).overflowX))return true;}
 return false;
}
const pageSwipeWorkspace=document.querySelector('.workspace');
const pageSwipe=createPageSwipeController({getPage:()=>pageView,getPages:pageSwipePages,isBlocked:pageSwipeBlocked,onNavigate:view=>switchPage(view)});
// Capture starts before the menu's outside-click handling can change its state.
pageSwipeWorkspace.addEventListener('touchstart',pageSwipe.start,{passive:true,capture:true});
pageSwipeWorkspace.addEventListener('touchmove',pageSwipe.move,{passive:false});
pageSwipeWorkspace.addEventListener('touchend',pageSwipe.end,{passive:false});
pageSwipeWorkspace.addEventListener('touchcancel',pageSwipe.cancel,{passive:true});
// Capture before the existing document-level card/button handlers.
window.addEventListener('pointerdown',()=>pageSwipe.clearClickSuppression(),true);
window.addEventListener('click',event=>{if(pageSwipeWorkspace.contains(event.target)&&pageSwipe.consumeClick(event)){event.preventDefault();event.stopImmediatePropagation();}},true);

function createPageSwipePointerAdapter(controller,{canStart,onTracking=()=>{},capture=()=>{},release=()=>{}}){
 let pointer=null;
 function normalized(event,end=false){const touch={identifier:event.pointerId,clientX:event.clientX,clientY:event.clientY};return {target:pointer?.target||event.target,touches:end?[]:[touch],changedTouches:[touch],cancelable:event.cancelable,preventDefault:()=>event.preventDefault()};}
 function clear(){const old=pointer;pointer=null;onTracking(false);if(old)release(old.id);}
 return {
  down(event){if(event.pointerType==='touch')return;if(pointer){controller.cancel();clear();return;}if(event.button!==0||event.isPrimary===false||!canStart(event.target))return;controller.start(normalized(event));if(controller.active()){pointer={id:event.pointerId,target:event.target,captured:false};onTracking(true);}},
  move(event){if(!pointer||event.pointerId!==pointer.id)return;if(event.buttons===0){controller.cancel();clear();return;}controller.move(normalized(event));if(!controller.active()){clear();return;}if(controller.dragging()&&!pointer.captured){pointer.captured=true;capture(pointer.id);}},
  up(event){if(!pointer||event.pointerId!==pointer.id)return;controller.end(normalized(event,true));clear();},
  cancel(event){if(!pointer||event.pointerId!==pointer.id)return;controller.cancel();clear();}
 };
}
const pageSwipePointer=createPageSwipePointerAdapter(pageSwipe,{
 canStart:target=>!!target.closest?.('.page-pill-track,.student-card')&&!pageSwipeBlocked(target),
 onTracking:tracking=>pageSwipeWorkspace.classList.toggle('is-swipe-tracking',tracking),
 capture:id=>{try{pageSwipeWorkspace.setPointerCapture(id);}catch{}},
 release:id=>{if(pageSwipeWorkspace.hasPointerCapture?.(id))pageSwipeWorkspace.releasePointerCapture(id);}
});
pageSwipeWorkspace.addEventListener('pointerdown',pageSwipePointer.down);
window.addEventListener('pointermove',pageSwipePointer.move,{passive:false});
window.addEventListener('pointerup',pageSwipePointer.up);
window.addEventListener('pointercancel',pageSwipePointer.cancel);
pageSwipeWorkspace.addEventListener('lostpointercapture',pageSwipePointer.cancel);
