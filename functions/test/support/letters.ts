import type { LetterBody } from '../../src/features/letters/letter';

/** A body of plain paragraphs, with an empty line between them. */
export function paragraphs(...texts: string[]): LetterBody {
  return texts.flatMap((text, index) => [
    ...(index > 0 ? [{ runs: [] }] : []),
    { runs: [{ text }] },
  ]);
}

/**
 * The body of the letter the temple made by hand, "Kunsel_Letter.pdf", as it
 * was typed: its slips and its doubled space included.
 */
export const sampleBody = paragraphs(
  'This letter is to confirm that  Tenzin Kunsel member ID 194915306 has been a dedicated ' +
    'member of Drepung Loseling Canada. Over the past 12 months and continuing to the present, ' +
    'she has been actively serving as a volunteer care provider, contributing his time and ' +
    'efforts with commitment and sincerity.',
  'At Drepung Loseling Canada, our volunteers play a vital role in providing community-based ' +
    'support and care, particularly for the elderly and individuals visiting the monastery for ' +
    'prayer and spiritual activities. Our institute is committed to preserving and studying the ' +
    'Tibetan Buddhist tradition, emphasizing wisdom, compassion, and the cultivation of both ' +
    'heart and intellect. Through our efforts, we strive to foster inner peace, kindness, ' +
    'communal understanding, and global healing.',
  'Kunsel has proven to be an exceptional volunteer, consistently demonstrating strong ' +
    'communication skills, empathy, and a proactive approach to caregiving. She possesses a ' +
    'natural ability to connect with others, especially the elderly, making those in her care ' +
    'feel valued, respected, and comfortable. Her positive “can-do” attitude is evident in his ' +
    'willingness to take initiative, problem-solve effectively, and adapt to various situations ' +
    'with patience and resilience. Whether offering companionship, assisting with daily ' +
    'activities, or supporting emotional well-being, She always approaches his responsibilities ' +
    'with warmth, compassion, and dedication. Her work ethic and ability to uplift those around ' +
    'her have made her an invaluable member of our team.',
  'If you have any questions or require additional information, please feel free to contact me.',
);

/** Where that letter has each line of its body: its words, baseline and width, in points. */
export const sampleLines: [text: string, baseline: number, width: number][] = [
  [
    'This letter is to confirm that Tenzin Kunsel member ID 194915306 has been a dedicated',
    646.22,
    453.892,
  ],
  [
    'member of Drepung Loseling Canada. Over the past 12 months and continuing to the present,',
    629.215,
    479.653,
  ],
  [
    'she has been actively serving as a volunteer care provider, contributing his time and efforts with',
    612.209,
    490.293,
  ],
  ['commitment and sincerity.', 595.203, 137.621],
  [
    'At Drepung Loseling Canada, our volunteers play a vital role in providing community-based',
    561.204,
    462.718,
  ],
  [
    'support and care, particularly for the elderly and individuals visiting the monastery for prayer',
    544.198,
    472.439,
  ],
  [
    'and spiritual activities. Our institute is committed to preserving and studying the Tibetan',
    527.193,
    451.997,
  ],
  [
    'Buddhist tradition, emphasizing wisdom, compassion, and the cultivation of both heart and',
    510.187,
    466.016,
  ],
  [
    'intellect. Through our efforts, we strive to foster inner peace, kindness, communal',
    493.181,
    418.69,
  ],
  ['understanding, and global healing.', 476.176, 176.328],
  [
    'Kunsel has proven to be an exceptional volunteer, consistently demonstrating strong',
    442.176,
    432.161,
  ],
  [
    'communication skills, empathy, and a proactive approach to caregiving. She possesses a',
    425.171,
    457.172,
  ],
  [
    'natural ability to connect with others, especially the elderly, making those in her care feel valued,',
    408.165,
    491.897,
  ],
  [
    'respected, and comfortable. Her positive “can-do” attitude is evident in his willingness to take',
    391.159,
    477.41,
  ],
  [
    'initiative, problem-solve effectively, and adapt to various situations with patience and resilience.',
    374.165,
    490.498,
  ],
  [
    'Whether offering companionship, assisting with daily activities, or supporting emotional',
    357.16,
    449.965,
  ],
  [
    'well-being, She always approaches his responsibilities with warmth, compassion, and',
    340.154,
    437.452,
  ],
  [
    'dedication. Her work ethic and ability to uplift those around her have made her an invaluable',
    323.149,
    471.561,
  ],
  ['member of our team.', 306.143, 108.712],
  [
    'If you have any questions or require additional information, please feel free to contact me.',
    272.143,
    460.773,
  ],
];
