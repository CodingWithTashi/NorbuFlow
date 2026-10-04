import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import { globalOptions } from './core/options';

initializeApp();
setGlobalOptions(globalOptions);

// One export per feature. A function deploys as `<feature>-<name>`, which is
// also the name the app calls it by.
export * as auth from './features/auth';
export * as letters from './features/letters';
export * as members from './features/members';
export * as temples from './features/temples';
