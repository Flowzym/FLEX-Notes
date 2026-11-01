const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('scratch/page-swipe.js','utf8'),c=vm.createContext({});vm.runInContext(source.slice(0,source.indexOf('const pageSwipeWorkspace=')),c);
const pages=['today','students','archive','settings'];let time=0,page='students',blocked=false;const routes=[];
const controller=c.createPageSwipeController({getPage:()=>page,getPages:()=>pages,isBlocked:()=>blocked,now:()=>time,onNavigate:next=>{page=next;routes.push(next);}});
function event(x,y,end=false){const point={identifier:1,clientX:x,clientY:y};return {target:{},touches:end?[]:[point],changedTouches:[point],cancelable:true,preventDefault(){this.prevented=true;}};}
function swipe(dx,dy=0,duration=150){controller.start(event(150,150));const move=event(150+dx,150+dy);controller.move(move);time+=duration;controller.end(event(150+dx,150+dy,true));return move;}
assert.equal(swipe(-90).prevented,true);assert.equal(page,'archive');swipe(-90);assert.equal(page,'settings');swipe(-90);assert.equal(page,'settings');swipe(90);assert.equal(page,'archive');swipe(90);assert.equal(page,'students');swipe(90);assert.equal(page,'today');swipe(90);assert.equal(page,'today');
assert.equal(controller.consumeClick({detail:1}),true);assert.equal(controller.consumeClick({detail:0}),false);time+=501;assert.equal(controller.consumeClick({detail:1}),false);
const before=routes.length;swipe(-30);swipe(-90,95);swipe(-90,0,3000);assert.equal(routes.length,before);
controller.start(event(150,150));controller.move(event(145,180));controller.end(event(40,180,true));assert.equal(routes.length,before);
blocked=true;swipe(-90);assert.equal(routes.length,before);blocked=false;
controller.start(event(150,150));controller.move({...event(50,150),cancelable:false});controller.end(event(50,150,true));assert.equal(routes.length,before);
controller.start(event(150,150));controller.move({...event(50,150),touches:[{},{}]});controller.end(event(50,150,true));assert.equal(routes.length,before);
controller.start(event(150,150));controller.cancel();controller.end(event(50,150,true));assert.equal(routes.length,before);
controller.start(event(150,150));page='archive';controller.end(event(50,150,true));assert.equal(routes.length,before);
assert.equal(c.pageSwipeDestination('missing',pages,-90,0,100),null);
// Exercise real target guards independently of touch recognition.
const workspace={},target={parentElement:workspace,scrollWidth:20,clientWidth:20,closest:()=>null};c.pageSwipeWorkspace=workspace;c.pageMoreMenu={hidden:true};let dialog=false,selection=false;c.document={querySelector:()=>dialog};c.window={getSelection:()=>({isCollapsed:!selection})};c.getComputedStyle=()=>({overflowX:'auto'});
assert.equal(c.pageSwipeBlocked(target),false);dialog=true;assert.equal(c.pageSwipeBlocked(target),true);dialog=false;c.pageMoreMenu.hidden=false;assert.equal(c.pageSwipeBlocked(target),true);c.pageMoreMenu.hidden=true;selection=true;assert.equal(c.pageSwipeBlocked(target),true);selection=false;
assert.equal(c.pageSwipeBlocked({...target,closest:()=>({})}),true);assert.equal(c.pageSwipeBlocked({...target,scrollWidth:80}),true);
// Regression: the very first small horizontal move must stop native scrolling.
page='today';controller.start(event(150,150));const early=event(145,151);controller.move(early);assert.equal(early.prevented,true);time+=1200;controller.end(event(90,158,true));assert.equal(page,'students');
assert.equal(controller.consumeClick({detail:1}),true);controller.start(event(150,150));controller.end(event(150,150,true));assert.equal(controller.consumeClick({detail:1}),false);
swipe(80);assert.equal(controller.consumeClick({detail:1}),true);controller.clearClickSuppression();assert.equal(controller.consumeClick({detail:1}),false);
// Exercise actual mouse/pen adapter, including pointer capture and cancellation.
vm.runInContext(source.slice(source.indexOf('function createPageSwipePointerAdapter('),source.indexOf('const pageSwipePointer=')),c);
let tracking=false,captured=null,released=null;const adapter=c.createPageSwipePointerAdapter(controller,{canStart:target=>target.allowed,onTracking:value=>tracking=value,capture:id=>captured=id,release:id=>released=id});
const pointer=(x,type='mouse',extra={})=>({pointerId:7,pointerType:type,button:0,buttons:1,isPrimary:true,clientX:x,clientY:150,target:{allowed:true},cancelable:true,preventDefault(){this.prevented=true;},...extra});
page='today';adapter.down(pointer(150,'touch'));assert.equal(tracking,false);adapter.down(pointer(150,'mouse',{target:{allowed:false}}));assert.equal(tracking,false);
adapter.down(pointer(150));assert.equal(tracking,true);assert.equal(captured,null);adapter.move(pointer(144));assert.equal(captured,7);adapter.up(pointer(80));assert.equal(page,'students');assert.equal(tracking,false);assert.equal(released,7);
adapter.down(pointer(150,'pen'));adapter.move(pointer(80,'pen'));adapter.cancel(pointer(80,'pen'));assert.equal(page,'students');assert.equal(tracking,false);
adapter.down(pointer(150));adapter.move(pointer(80,'mouse',{buttons:0}));adapter.up(pointer(80));assert.equal(page,'students');assert.equal(tracking,false);
console.log('PASS: early horizontal claiming, slow deliberate swipe, directions/boundaries, vertical scroll, multitouch/cancel, fresh taps, keyboard clicks, mouse/pen adapter, capture cleanup, dialogs/menus/fields/selection and horizontal scrolling. No browser tests.');
