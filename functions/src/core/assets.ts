import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/** The `functions` folder, deployed whole: two levels above `src/core` and `lib/core` alike. */
export const functionsFolder = join(__dirname, '..', '..');

/** Reads a file from `functions/assets` (fonts, document artwork). */
export function readAsset(...path: string[]): Uint8Array {
  return readFileSync(join(functionsFolder, 'assets', ...path));
}
