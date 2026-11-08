// Provider base (PR-080): shared shapes for every external integration.
// - health() is uniform: { ok, provider, detail? }, never throws.
// - Heavy imports (nodemailer, SDKs) happen lazily inside send paths, never
//   at require time, so boot and unit tests stay dependency-free.
// - Mock providers record calls in-memory for tests and return success.
export async function safeHealth(fn, provider) {
  try {
    const detail = await fn();
    return { ok: true, provider, detail: detail ?? null };
  } catch (err) {
    return { ok: false, provider, detail: String((err && err.message) || err) };
  }
}

export function mockCalls() {
  const calls = [];
  return {
    calls,
    record(entry) {
      calls.push({ ts: new Date().toISOString(), ...entry });
      return true;
    },
  };
}
