import { lazy } from '../../core/lazy';
import type { LetterRenderer } from './letter-renderer';
import type { LetterTemplate } from './letter-template';
import { drepungLoselingCanada } from './templates/drepung-loseling-canada';

// The PDF library, the letterhead and the fonts are slow to load, and only a
// function that draws a letter needs them.
const load = async (template: LetterTemplate) =>
  (await import('./letter-renderer.js')).LetterRenderer.load(template);

// Loaded on first use and kept.
const designed: Record<string, () => Promise<LetterRenderer>> = {
  'drepung-loseling-canada': lazy(() => load(drepungLoselingCanada())),
};

/** Every value `temples.letter_template` may take. */
export const letterTemplates = Object.keys(designed);

/** The renderer for the letter template called `template`. */
export async function letterRenderer(template: string): Promise<LetterRenderer> {
  const renderer = designed[template];
  if (!renderer) throw new Error(`No letter template named "${template}".`);
  return renderer();
}
