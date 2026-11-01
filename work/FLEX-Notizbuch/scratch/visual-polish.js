AppFlows.use('renderModal','visual-polish',polishedRenderModal=>function(){polishedRenderModal();const pupil=db.students.find(s=>s.id===active);if(pupil)$('#studentDialog').style.setProperty('--pupil-accent',pupilColor(pupil));});
const railStorageNote=document.querySelector('.rail-foot-text small');if(railStorageNote)railStorageNote.textContent='Lokal gespeichert';
