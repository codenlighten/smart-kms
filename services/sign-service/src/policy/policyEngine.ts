export function makePolicyEngine() {
  function evaluate(context: any): { allow: boolean, reason?: string } {
    const tenant = context?.actor?.tenant;
    const keyRef: string = context?.payload?.keyRef || '';
    const digestHex: string = (context?.payload?.digestHex || '').toLowerCase();

    if (!tenant) return { allow: false, reason: "tenant_missing" };
    if (!keyRef.startsWith(`alias/bsv/tenant/${tenant}/`)) {
      return { allow: false, reason: "keyRef_tenant_mismatch" };
    }
    if (!/^[0-9a-f]{64}$/.test(digestHex)) {
      return { allow: false, reason: "bad_digest" };
    }
    return { allow: true };
  }
  return { evaluate };
}
