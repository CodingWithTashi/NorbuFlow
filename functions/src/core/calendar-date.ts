/** A day on the calendar, with no time or time zone: a card's expiry date. */
export interface CalendarDate {
  year: number;
  /** 1–12. */
  month: number;
  day: number;
}

/** Today's date for people in `timeZone` (an IANA name such as `America/Toronto`). */
export function todayIn(timeZone: string, now: Date): CalendarDate {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  }).formatToParts(now);
  const part = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  return { year: part('year'), month: part('month'), day: part('day') };
}

/** That day of the month, or the month's last if it is shorter: 31 June is 30 June. */
export function dateInMonth(year: number, month: number, day: number): CalendarDate {
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return { year, month, day: Math.min(day, lastDay) };
}

/** `2027-07-31`, the form dates take in the database and on the wire. */
export function toIsoDate({ year, month, day }: CalendarDate): string {
  const pad = (value: number, length: number) => String(value).padStart(length, '0');
  return `${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}`;
}

/** Reads a date written by `toIsoDate`. */
export function parseIsoDate(value: string): CalendarDate {
  const [year, month, day] = value.split('-').map(Number);
  if (!year || !month || !day) throw new Error(`Not a date: ${value}`);
  return { year, month, day };
}

/** Negative when `a` is the earlier date. */
export function compareDates(a: CalendarDate, b: CalendarDate): number {
  return a.year - b.year || a.month - b.month || a.day - b.day;
}
