/**
 * Minimal deterministic JSON canonicalizer (JCS-like).
 * NOTE: For strict RFC 8785 compliance, replace with a full JCS library.
 */
export function canonicalize(value: any): string {
  return JSON.stringify(sort(value));
}
function sort(x: any): any {
  if (x === null || typeof x !== 'object') return x;
  if (Array.isArray(x)) return x.map(sort);
  const out: any = {};
  for (const k of Object.keys(x).sort()) {
    out[k] = sort(x[k]);
  }
  return out;
}
