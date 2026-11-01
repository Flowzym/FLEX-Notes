// Opt-in local test adapter: use an isolated Chrome process for existing suites.
const {chromium}=require('playwright');
const launch=chromium.launch.bind(chromium);
chromium.launch=options=>launch({...options,channel:'chrome'});
