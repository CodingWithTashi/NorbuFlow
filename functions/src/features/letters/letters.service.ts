import { type CalendarDate, compareDates, todayIn } from '../../core/calendar-date';
import type { Caller } from '../../core/caller';
import { AppError } from '../../core/errors';
import type { FileStore } from '../../core/file-store';
import type { TempleAccess } from '../temples';
import type { Role, Temple } from '../temples/temple';
import type { FiledLetter, Letter, LetterBody, LetterRepository, NumberTaken } from './letter';
import type { LetterRenderer } from './letter-renderer';

/** A letter carries the temple's signature, so only its admins issue or read them. */
const mayIssueLetters: Role[] = ['admin'];

/** A letter to draw, tidied by `letters.input.ts`. */
export interface LetterRequest {
  /** Who it is for. */
  name: string;
  memberId?: string;
  validUntil: CalendarDate;
  body: LetterBody;
  /** The digits of a number typed by hand. Left out, it gets the next one. */
  number?: string;
  templeId?: string;
}

export interface NewLetterRequest extends LetterRequest {
  /** Chosen by the app, so that asking twice does the work once. */
  id: string;
}

/** A letter as it would print, and the number on it. Nothing is saved. */
export interface LetterPreview {
  number: string;
  pdf: Uint8Array;
  /** Lines of room left under the body: how much lower it could start. */
  spare: number;
}

/** The body runs this many lines past the room the page has for it. */
export interface TooLong {
  tooLong: { lines: number };
}

/** A letter as saved, with its print-ready page. */
export interface IssuedLetter {
  letter: Letter;
  pdf: Uint8Array;
}

/** Support letter rules. Knows nothing about HTTP, Firebase or SQL. */
export class LetterService {
  constructor(
    private readonly access: TempleAccess,
    private readonly letters: LetterRepository,
    private readonly files: FileStore,
    private readonly letterRenderer: (template: string) => Promise<LetterRenderer>,
    private readonly now: () => Date,
  ) {}

  /** The temple's letters, the newest first. */
  async list(caller: Caller, templeId?: string): Promise<Letter[]> {
    const temple = await this.access.templeFor(caller, templeId, mayIssueLetters);
    return this.letters.list(temple.id);
  }

  /** A letter on file: what it says, and its page. */
  async get(
    caller: Caller,
    request: { letterId: string; templeId?: string },
  ): Promise<IssuedLetter & { body: LetterBody }> {
    const temple = await this.access.templeFor(caller, request.templeId, mayIssueLetters);
    const filed = await this.letters.find(temple.id, request.letterId);
    if (!filed) {
      throw AppError.notFound(`${temple.id} has no letter with the id "${request.letterId}".`);
    }
    return { ...(await this.withPage(filed)), body: filed.body };
  }

  /**
   * Draws the letter a request would issue, with the number it would carry:
   * the one typed, or the temple's next.
   */
  async preview(caller: Caller, request: LetterRequest): Promise<LetterPreview | TooLong> {
    const temple = await this.access.templeFor(caller, request.templeId, mayIssueLetters);
    const { renderer, tooLong } = await this.printable(temple, request);
    if (tooLong) return { tooLong };

    const number = await this.letters.numberFor(temple.id, request.number);
    const { validUntil, body } = request;
    return {
      number,
      pdf: await renderer.render({ number, validUntil, body }),
      spare: renderer.spareLines(body),
    };
  }

  /** Issues a letter and files its page. A typed number another letter carries issues nothing. */
  async create(caller: Caller, request: NewLetterRequest): Promise<IssuedLetter | NumberTaken> {
    const temple = await this.access.templeFor(caller, request.templeId, mayIssueLetters);

    // Asked again, it is the letter already made: a day that has since passed
    // must not refuse it.
    const made = await this.letters.find(temple.id, request.id);
    if (made) return this.withPage(made);

    // Everything that could stop the letter printing is checked before a
    // number is taken.
    const { renderer, template, tooLong } = await this.printable(temple, request);
    if (tooLong) throw AppError.invalid({ body: 'letterBodyTooLong' });

    const { validUntil, body } = request;
    const saved = await this.letters.save(
      {
        id: request.id,
        templeId: temple.id,
        name: request.name,
        memberId: request.memberId ?? null,
        validUntil,
        issuedOn: todayIn(temple.timeZone, this.now()),
        body,
        template,
        issuedBy: caller.uid,
      },
      request.number,
      async (number) => {
        const pdfKey = `temples/${temple.id}/letters/${request.id}.pdf`;
        const pdf = await renderer.render({ number, validUntil, body });
        await this.files.put(pdfKey, pdf, 'application/pdf');
        return { pdfKey, pdf };
      },
    );
    if ('taken' in saved) return saved;
    if ('issued' in saved) return this.withPage(saved.issued);
    return saved;
  }

  private async withPage(filed: FiledLetter): Promise<IssuedLetter> {
    return { letter: filed.letter, pdf: await this.files.get(filed.pdfKey) };
  }

  /** The temple's letter, and whether `request` fits it. Refuses what it cannot print. */
  private async printable(
    temple: Temple,
    request: LetterRequest,
  ): Promise<{ renderer: LetterRenderer; template: string; tooLong?: { lines: number } }> {
    const template = temple.letterTemplate;
    if (!template) throw AppError.notFound(`${temple.id} has no letterhead to print on.`);

    const today = todayIn(temple.timeZone, this.now());
    if (compareDates(request.validUntil, today) < 0) {
      throw AppError.invalid({ validUntil: 'letterDatePast' });
    }
    const { memberId } = request;
    if (memberId && !(await this.letters.isMember(temple.id, memberId))) {
      throw AppError.notFound(`${temple.id} has no member with the id "${memberId}".`);
    }

    const renderer = await this.letterRenderer(template);
    const problem = renderer.bodyProblem(request.body);
    if (problem?.kind === 'unsupported') throw AppError.invalid({ body: 'letterBodyUnsupported' });
    return { renderer, template, tooLong: problem && { lines: problem.lines } };
  }
}
