/**
 * `ruth.a@example.com` → `Ruth A`: what to call someone until they set a
 * name. The same rule the app uses for a pending invitation.
 */
export function displayNameFromEmail(email: string): string {
  const local = email.split('@')[0] ?? '';
  const name = local
    .split(/[._]/)
    .filter((word) => word.length > 0)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  return name || email;
}
