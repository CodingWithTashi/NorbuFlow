const emulated = process.env.FUNCTIONS_EMULATOR === 'true';
const demoProject = (process.env.GCLOUD_PROJECT ?? '').startsWith('demo-');

/**
 * Whether in-memory stand-ins replace Neon and R2. Only ever in the emulator:
 * for a `demo-` project (the tests), or when `.env.local` sets `STAND_INS=true`.
 */
export const standIns = emulated && (demoProject || process.env.STAND_INS === 'true');

/** A setting from `functions/.env`, which the functions cannot run without. */
export function setting(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is not set. It belongs in functions/.env.`);
  return value;
}
