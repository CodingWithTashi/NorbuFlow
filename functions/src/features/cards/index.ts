import type { FileStore } from '../../core/file-store';
import { lazy } from '../../core/lazy';
import type { CardRenderer, NameProblem } from './card-renderer';
import type { CardTemplate } from './card-template';
import { drepungLoselingCanada } from './templates/drepung-loseling-canada';

export { prepareCardPhoto } from './card-photo';
export type { CardRenderer, NameProblem } from './card-renderer';

/** The card of a temple with no design of its own: its name and logo on NorbuFlow's layout. */
export const standardTemplate = 'standard';

/** What a temple's card is made from. */
export interface CardTemple {
  id: string;
  name: string;
  cardTemplate: string;
  logoKey: string | null;
}

// The PDF library, the artwork and the fonts are slow to load, and only a
// function that prints a card needs them.
const load = async (template: CardTemplate) =>
  (await import('./card-renderer.js')).CardRenderer.load(template);

// Loaded on first use and kept.
const designed: Record<string, () => Promise<CardRenderer>> = {
  'drepung-loseling-canada': lazy(() => load(drepungLoselingCanada())),
};

/** Every value `temples.card_template` may take. */
export const cardTemplates = [standardTemplate, ...Object.keys(designed)];

// One per temple, made again when its name or logo changes.
const standard = new Map<string, { of: string; renderer: Promise<CardRenderer> }>();

/** The renderer for the card `temple` prints. `files` is where its logo is kept. */
export async function cardRenderer(temple: CardTemple, files: FileStore): Promise<CardRenderer> {
  if (temple.cardTemplate !== standardTemplate) {
    const renderer = designed[temple.cardTemplate];
    if (!renderer) throw new Error(`No card template named "${temple.cardTemplate}".`);
    return renderer();
  }
  const of = `${temple.name}\n${temple.logoKey}`;
  const kept = standard.get(temple.id);
  if (kept?.of === of) return kept.renderer;

  const renderer = loadStandard(temple, files);
  standard.set(temple.id, { of, renderer });
  // A failed load is not kept: the next card tries again.
  renderer.catch(() => {
    if (standard.get(temple.id)?.renderer === renderer) standard.delete(temple.id);
  });
  return renderer;
}

async function loadStandard(temple: CardTemple, files: FileStore): Promise<CardRenderer> {
  const { standardCard } = await import('./templates/standard.js');
  const logo = temple.logoKey ? await files.get(temple.logoKey) : undefined;
  return load(await standardCard({ name: temple.name, logo }));
}

/** Why a temple called `name` cannot print the card `template`, if it cannot. */
export async function templeNameProblem(
  template: string,
  name: string,
): Promise<NameProblem | undefined> {
  // A designed card has the temple's name in its artwork.
  if (template !== standardTemplate) return undefined;
  return (await import('./templates/standard.js')).standardNameProblem(name);
}
