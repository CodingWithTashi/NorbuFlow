/**
 * Builds a value on first use and keeps it, so nothing connects to anything
 * while the functions are only being loaded for deployment.
 */
export function lazy<T extends object>(create: () => T): () => T {
  let value: T | undefined;
  return () => (value ??= create());
}
