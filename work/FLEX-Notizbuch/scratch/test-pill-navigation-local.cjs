// Navigation state and keyboard behavior against isolated DOM-shaped controls.
// No browser, layout engine or personal storage is used.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('scratch/pill-navigation.js','utf8');
const document={activeElement:null};
function button(page){const classes=new Set();return {dataset:{page},attrs:{},classList:{toggle(k,on){on?classes.add(k):classes.delete(k);},contains:k=>classes.has(k)},setAttribute(k,v){this.attrs[k]=String(v);},removeAttribute(k){delete this.attrs[k];},focus(){document.activeElement=this;}};}
const today=button('today'),students=button('students'),more=button(),archive=button('archive'),settings=button('settings');
const menu={hidden:true,querySelector:()=>archive,querySelectorAll:()=>[archive,settings],contains:node=>[archive,settings].includes(node)};
const pills={classList:{toggle(){}},querySelectorAll:()=>[today,students],querySelector:s=>s.includes('today')?today:students};
let routeCalls=0,headerUpdates=0;
const actions={},studentTools={append(node){node.parentElement=this;}},pageHead={append(node){node.parentElement=this;}};
const c=vm.createContext({document,$:selector=>({'.head-actions':actions,'.student-tools':studentTools,'.page-head':pageHead}[selector]),pageView:'students',pagePills:pills,pageMoreButton:more,pageMoreMenu:menu,updatePinnedHeader:()=>headerUpdates++,switchPage(view){routeCalls++;c.pageView=view;}});
vm.runInContext(source.slice(0,source.indexOf('const pagePills=')),c);
c.refreshPillNavigation();assert.equal(students.attrs['aria-current'],'page');assert.equal(today.attrs['aria-current'],undefined);assert.equal(more.textContent,'…');
function key(key,target){const event={key,target,preventDefault(){this.prevented=true;},stopImmediatePropagation(){this.stopped=true;}};c.handlePageMenuKeydown(event);return event;}
key('ArrowDown',more);assert.equal(menu.hidden,false);assert.equal(more.attrs['aria-expanded'],'true');assert.equal(document.activeElement,archive);
key('ArrowDown',archive);assert.equal(document.activeElement,settings);key('ArrowDown',settings);assert.equal(document.activeElement,archive);
key('End',archive);assert.equal(document.activeElement,settings);key('Home',settings);assert.equal(document.activeElement,archive);
const escape=key('Escape',archive);assert.equal(escape.stopped,true);assert.equal(menu.hidden,true);assert.equal(document.activeElement,more);
key('ArrowUp',more);assert.equal(document.activeElement,settings);
vm.runInContext(source.slice(source.indexOf('const switchPageBeforePills=')),c);
for(const view of ['today','archive','settings','students']){c.setPageMenu(true);c.switchPage(view);assert.equal(menu.hidden,true);assert.equal(more.attrs['aria-expanded'],'false');const active=view==='today'?today:view==='students'?students:more;assert.equal(document.activeElement,active);assert.equal(active.attrs['aria-current'],'page');assert.equal(more.classList.contains('active'),!['today','students'].includes(view));if(view==='archive')assert.equal(more.textContent,'Archiv');if(view==='settings')assert.equal(more.textContent,'Einstellungen');}
assert.equal(routeCalls,4);assert.ok(headerUpdates>=4);
assert.equal(actions.parentElement,studentTools);c.movePageActions('archive');assert.equal(actions.parentElement,studentTools);c.movePageActions('today');assert.equal(actions.parentElement,pageHead);c.movePageActions('settings');assert.equal(actions.parentElement,pageHead);
const html=fs.readFileSync('FLEX-Notizbuch.html','utf8');assert.ok(!html.includes('Beschreibe kurz den Anlass und das konkret beobachtete Verhalten.'));assert.ok(html.includes('page-pill-track'));
console.log('PASS: active primary/more titles, disclosure state, keyboard navigation/Escape, page switching/focus, header refresh and removed narrative hint. Visual layout not tested.');
