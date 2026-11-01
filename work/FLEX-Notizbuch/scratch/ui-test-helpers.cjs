async function date(page,id,value){
 const control=page.locator('#'+id);await control.locator('..').locator('.calendar-open').click();
 if(!value){await page.locator('#calendarClear').click();return;}
 await page.locator('#calendarYear').selectOption(value.slice(0,4));await page.locator('#calendarMonth').selectOption(String(Number(value.slice(5,7))-1));await page.locator('[data-calendar-day="'+value.slice(0,10)+'"]').click();
 if(await page.locator('#calendarDialog').isVisible()&&await page.locator('#calendarApply').isVisible()){if(value.includes('T'))await page.locator('#calendarTime').fill(value.slice(11,16));else if(await page.locator('#calendarNoTime').isEnabled())await page.locator('#calendarNoTime').click();await page.locator('#calendarApply').click();}
}
async function tasks(page,scope,value){
 const lines=value.split('\n');for(let i=0;i<lines.length;i++){if(i){if(/^\s/.test(lines[i])&&!/^\s/.test(lines[i-1]))await page.locator('[data-task-editor="'+scope+'"] [data-task-child]').last().click();else if(!/^\s/.test(lines[i])&&/^\s/.test(lines[i-1]))await page.locator('[data-task-add="'+scope+'"]').click();else await page.locator('[data-task-editor="'+scope+'"] [data-task-enter]').last().click();}await page.locator('[data-task-editor="'+scope+'"] [data-task-text]').nth(i).fill(lines[i].trim());}
}
async function category(page,name){const id=await page.evaluate(()=>active||'initial-mahyar');if(await page.locator('#studentDialog').isVisible())await page.locator('#closeStudent').click();await page.locator(`[data-quick-student="${id}"][data-quick-category="${name}"]`).click();}
module.exports={date,tasks,category};
