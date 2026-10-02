import type { GlobalOptions } from 'firebase-functions/v2/options';

/**
 * Applied to every function. The region must match the app's
 * `AppConfig.functionsRegion`; `maxInstances` caps cost and database connections.
 */
export const globalOptions: GlobalOptions = {
  region: 'us-central1',
  maxInstances: 10,
};
