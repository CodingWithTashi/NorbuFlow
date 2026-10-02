import { lazy } from '../../core/lazy';
import type { CardRenderer } from './card-renderer';
import type { CardTemplate } from './card-template';
import { drepungLoselingCanada } from './templates/drepung-loseling-canada';

export { prepareCardPhoto } from './card-photo';
export type { CardRenderer } from './card-renderer';

// Loaded on first use and kept: the PDF library, the artwork and the fonts
// are slow to load, and only a function that prints a card needs them.
const renderer = (template: () => CardTemplate) =>
  lazy(async () => (await import('./card-renderer.js')).CardRenderer.load(template()));

const renderers: Record<string, () => Promise<CardRenderer>> = {
  'drepung-loseling-canada': renderer(drepungLoselingCanada),
};

/** The renderer for the card a temple prints (`temples.card_template`). */
export async function cardRenderer(template: string): Promise<CardRenderer> {
  const load = renderers[template];
  if (!load) throw new Error(`No card template named "${template}".`);
  return load();
}
