const {spawnSync}=require('node:child_process');
const files=[
  "test-concept-local.cjs",
  "test-social-narrative-local.cjs",
  "test-social-context-local.cjs",
  "test-org-navigation-local.cjs",
  "test-control-appearance-local.cjs",
  "test-pill-navigation-local.cjs",
  "test-page-swipe-local.cjs",
  "test-review-local.cjs",
  "test-backup-drafts-local.cjs",
  "test-settings-layout-local.cjs",
  "test-orga-unified-local.cjs",
  "test-pupil-overview-local.cjs"
];
for(const file of files){const result=spawnSync(process.execPath,['scratch/'+file],{stdio:'inherit'});if(result.status!==0)process.exit(result.status||1);}
console.log('All twelve local suites passed; no browser tests.');
