const{chromium}=require('/opt/codex/cua_node/lib/node_modules/playwright');
const fs=require('fs'),assert=require('assert');
(async()=>{
const b=await chromium.connectOverCDP('http://127.0.0.1:9223'),ctx=b.contexts()[0],p=await ctx.newPage();
for(const old of ctx.pages())if(old!==p&&old.url().includes('8083'))await old.close();
const errors=[];p.on('pageerror',e=>errors.push(e.message));
const client=await ctx.newCDPSession(p);
await client.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
await client.send('Emulation.setTimezoneOverride',{timezoneId:'Europe/Vienna'});
await p.setViewportSize({width:390,height:844});
const pause=()=>p.waitForTimeout(300);
const click=async name=>{await p.getByRole('button',{name,exact:typeof name==='string'}).click();await pause()};
const snap=async name=>{await p.mouse.move(1,1);await pause();await p.screenshot({path:`/workspace/build76/${name}.png`})};
const canvasInput=()=>p.addStyleTag({content:'flt-semantics-host, flt-semantics, flt-semantics-container { pointer-events: none !important; }'});
const touch=async(x,y)=>{const style=await canvasInput();await client.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});await p.waitForTimeout(70);await client.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await pause();await style.evaluate(e=>e.remove())};
const swipe=async(x,y,dx)=>{const style=await canvasInput();await client.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});for(let i=1;i<=8;i++){await client.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+dx*i/8,y}]});await p.waitForTimeout(20)}await client.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await pause();await style.evaluate(e=>e.remove())};
await p.goto('http://127.0.0.1:8083');await p.waitForTimeout(4000);await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
await click('Kalender');await click('Tag');await click('Heute');
// Today may scroll to the time marker: return to morning before picking a time.
await p.mouse.move(220,380);await p.mouse.wheel(0,-1600);await pause();
const title='QA Build 76 · Termin per Touch';
if (!(await p.locator('body').innerText()).includes(title)) {
const grid=await p.getByRole('button',{name:/Termin am 2026-11-14 hinzufügen/}).boundingBox();assert(grid&&grid.y<740);
// Empty day axis starts at 08:00 and uses 0.88 px per minute.
await touch(230,grid.y+120*.88+2);
assert((await p.locator('body').innerText()).includes('14.11.2026 · 10:00'));
const input=p.getByRole('textbox').first();await input.click();await p.keyboard.press('Control+A');await p.keyboard.type(title);await pause();
await snap('touch-appointment');await click('Speichern');
}
await p.waitForFunction(text=>document.body.innerText.includes(text),title);
await snap('calendar-day-390');
// Header gestures change view; the time grid changes the period.
const toolbarY=(await p.getByRole('button',{name:'Heute',exact:true}).boundingBox()).y+18;
await swipe(350,toolbarY,-280);
assert.equal(await p.getByRole('button',{name:/^Montag, .*Tagesansicht öffnen/}).count(),1);
const before=await p.getByRole('button').nth(4).innerText();
await swipe(320,430,-230);
const after=await p.getByRole('button').nth(4).innerText();assert.notEqual(after,before);
assert.equal(await p.getByRole('button',{name:/^Montag, .*Tagesansicht öffnen/}).count(),1);
await snap('calendar-week-390');await p.setViewportSize({width:320,height:844});await snap('calendar-week-320');
const rects=await Promise.all(['Vorheriger Zeitraum','Nächster Zeitraum','Heute','Unterricht anzeigen','Filter','Unterlagen','Verwalten'].map(name=>p.getByRole('button',{name,exact:true}).boundingBox()));
assert(rects.every(r=>r&&r.x>=0&&r.x+r.width<=320.1&&Math.abs(r.y-rects[0].y)<1));
await click('Verwalten');await snap('manage-320');
const weekend=p.getByRole('switch',{name:/Samstag und Sonntag/});if(await weekend.getAttribute('aria-checked')!=='false'){await weekend.click();await pause()}
await click('Schließen');assert.equal(await p.getByRole('button',{name:/^Sonntag, .*Tagesansicht öffnen/}).count(),0);
await click('Verwalten');await weekend.click();await pause();await click(/^Stundenplan Wochenplan/);
const navRects=await Promise.all(['Wochenplan','Zeiten','Änderungen'].map(name=>p.getByRole('button',{name,exact:true}).boundingBox()));assert(navRects.every(r=>Math.abs(r.y-navRects[0].y)<1));
await snap('timetable-320');
await p.getByRole('button',{name:'Block kopieren',exact:true}).first().click();await pause();
const copyName='QA Build 76 · Blockkopie';
const label=p.getByRole('textbox',{name:'Fach / Bezeichnung',exact:true});await label.click();await p.keyboard.press('Control+A');await p.keyboard.type(copyName);await pause();await click('Speichern');
await p.waitForFunction(text=>document.body.innerText.includes(text),copyName);assert((await p.locator('body').innerText()).includes('Zeitliche Überschneidung'));await snap('timetable-copy');
await click('Zeiten');await snap('timetable-hours');
await click('Zeiten & Gültigkeit bearbeiten');assert((await p.locator('body').innerText()).includes('Stunde hinzufügen'));await snap('timetable-hours-editor');await click('Abbrechen');
await click('Änderungen');await snap('timetable-changes');
await click('Schließen');await click('Schließen');
await click('Monat');await snap('calendar-month-320');
await p.reload();await p.waitForTimeout(3500);await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());await click('Kalender');await click('Tag');await click('Heute');
await p.mouse.move(220,380);await p.mouse.wheel(0,-2000);await pause();await p.waitForFunction(text=>document.body.innerText.includes(text),title);assert.deepEqual(errors,[]);
const result={version:'0.26.0+76',syntheticData:true,widths:[320,390],timezone:'Europe/Vienna',checks:['single toolbar row','real touch time field, save and reload','outside swipe changes view','inside swipe changes period','weekends in management','timetable pills one row','independent block copy in selected week','overlap warning','hours editor','changes panel'],pageErrors:errors,physicalAndroidTested:false};
fs.writeFileSync('/workspace/build76/browser-check.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
