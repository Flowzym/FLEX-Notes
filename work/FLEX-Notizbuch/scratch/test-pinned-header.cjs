const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const path=require('node:path');

(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 try{
  for(const width of [320,390,1360]){
   const context=await browser.newContext({viewport:{width,height:844}});
   try{
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));page.setDefaultTimeout(6000);
    await page.goto(pathToFileURL(path.resolve('FLEX-Notizbuch.html')).href);
    await page.evaluate(()=>{
     db.students.push(...Array.from({length:34},(_,i)=>({id:'scroll-test-'+i,name:'Testkind '+String(i+1).padStart(2,'0')})));
     db.students.push({id:'scroll-archive',name:'Archiviertes Testkind',archived:true});
     renderStudents();
    });
    const header=page.locator('.workspace-header');
    const assertHeader=async()=>{
     await page.waitForFunction(()=>Math.abs(parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--workspace-header-height'))-document.querySelector('.workspace-header').getBoundingClientRect().height)<1);
     const geometry=await page.evaluate(()=>{
      const h=document.querySelector('.workspace-header'),r=h.getBoundingClientRect();
      const selectors=['.page-head h1','#addStudent','#toggleStudentSearch','#backupButton','#studentCount','#showArchive'];
      selectors.push('#mobileMenu');
      return {top:r.top,bottom:r.bottom,overflow:document.documentElement.scrollWidth>innerWidth,
       controls:selectors.map(s=>{
        const e=document.querySelector(s),b=e.getBoundingClientRect(),hit=document.elementFromPoint(b.x+b.width/2,b.y+b.height/2);
        return {selector:s,visible:b.top>=r.top&&b.bottom<=r.bottom&&b.left>=0&&b.right<=innerWidth,clickable:e===hit||e.contains(hit)};
       })};
     });
     assert.ok(Math.abs(geometry.top)<1,JSON.stringify(geometry));
     assert.equal(geometry.overflow,false);
     assert.ok(geometry.bottom<844);
     assert.ok(geometry.controls.every(c=>c.visible&&c.clickable),JSON.stringify(geometry));
    };
    const initialHeight=(await header.boundingBox()).height;
    await page.evaluate(()=>scrollTo(0,800));
    await page.waitForFunction(()=>scrollY>=799);
    await assertHeader();
    assert.ok((await page.locator('.student-card').first().boundingBox()).y<0,'Cards must scroll under the header');
    await page.screenshot({path:`scratch/pinned-header-${width}.png`});

    await page.locator('#toggleStudentSearch').click();
    await page.locator('#studentSearch').fill('Testkind');
    await assertHeader();
    assert.ok((await header.boundingBox()).height>initialHeight,'Expanded search remains part of the header');
    await page.locator('#toggleBulk').click();
    await page.locator('#selectVisiblePupils').click();
    assert.equal(await page.locator('[data-bulk-pupil]:checked').count(),34);
    await assertHeader();
    await page.locator('#startBulkEntry').click();
    assert.ok(await page.locator('#bulkDialog').isVisible(),'Modal opens above the pinned area');
    await page.keyboard.press('Escape');
    await page.locator('#toggleBulk').click();
    await page.locator('.close-student-search').click();

    await page.locator('#showArchive').check();
    assert.equal(await page.locator('.student-card').count(),1);
    await page.locator('#showArchive').uncheck();
    await page.evaluate(()=>scrollTo(0,800));
    await assertHeader();
    // Focus scrolling must leave the destination below the pinned controls.
    await page.locator('[data-student="scroll-test-20"]').focus();
    const focusBox=await page.locator('[data-student="scroll-test-20"]').boundingBox();
    assert.ok(focusBox.y>=(await header.boundingBox()).height-1);

    // Existing theme tokens also color the opaque header background.
    await page.evaluate(()=>savePreferences({...appPreferences,background:'#f2ede2'}));
    assert.equal(await page.evaluate(()=>document.documentElement.dataset.theme),'light');
    await assertHeader();
    await page.screenshot({path:`scratch/pinned-header-light-${width}.png`});
    await page.evaluate(()=>setSaveStatus(false,'Nicht gespeichert – bitte erneut sichern'));
    await assertHeader();
    if(await page.locator('#mobileMenu').getAttribute('aria-expanded')==='false')await page.locator('#mobileMenu').click();assert.ok(await page.locator('#retrySave').isVisible());await page.locator('#sidebarToggle').click();
    await page.evaluate(()=>setSaveStatus(true));

    // Moving the save indicator across the mobile breakpoint must retain its anchor.
    for(const nextWidth of [390,1360,width]){
     await page.setViewportSize({width:nextWidth,height:844});
     await page.waitForFunction(()=>document.querySelector('#storageState').parentElement.classList.contains('sidebar-foot'));
     await page.evaluate(()=>scrollTo(0,800));
     assert.equal(await page.locator('#storageState').count(),1);
     await assertHeader();
    }
    if(width<=700){
     await page.locator('#mobileMenu').click();
     await page.locator('[data-page="settings"]').click();
     assert.ok(await page.locator('#settingsPage').isVisible());
     await page.locator('#mobileMenu').click();
     await page.locator('[data-page="students"]').click();
    }
    assert.equal(await page.locator('.student-card').count(),36);
    const goalShortcut=page.locator('[data-quick-student="scroll-test-0"][data-quick-category="Ziele"]');
    await goalShortcut.click();
    await page.locator('#newGoal').click();
    await page.locator('#entryText').fill('Testziel am angepinnten Kopfbereich');
    await page.locator('#saveEntry').click();
    await page.locator('#closeStudent').click();
    assert.equal(await goalShortcut.locator('.shortcut-count').textContent(),'1');
    await goalShortcut.click();
    await page.locator('[data-toggle-goal]').first().click();
    await page.locator('#closeStudent').click();
    assert.equal(await goalShortcut.locator('.shortcut-count').count(),0);
    await page.reload();
    assert.equal(await page.locator('.student-card').count(),36);
    assert.equal(await goalShortcut.locator('.shortcut-count').count(),0);
    assert.equal(await page.evaluate(()=>db.entries.find(e=>e.category==='Ziele').goalStatus),'reached');
    assert.deepEqual(errors,[]);
    console.log(`PASS: pinned header ${width}px, scroll, search, bulk, archive, keyboard focus, themes, warnings, responsive status, save/complete badge and reload`);
   }finally{await context.close();}
  }
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
