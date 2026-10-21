# Approval register and owner attestation

Status: **owner-attested**. Signed evidence is retained in the private evidence
store and is not reproduced in this repository.

## Attestation

On 2026-10-21 the repository owner attested that all approvals required for the
production scope have been granted, including Gate 0, and that the signed
evidence is retained outside this repository. This register records the
attestation and its scope. It does not independently verify the signed
documents.

Production use is authorized by those approvals. Engineering implementation and
test evidence remain tracked separately in `docs/STATUS.md` and
`docs/TRACEABILITY.md`; an approved control is not the same as an implemented
control.

## Approval register

| Scope | Approver | Attested | Evidence |
|---|---|---|---|
| Legal entity, license, jurisdiction | Muhammad Febriansyah (CCO); Sarah Wijaya (Legal) | 2026-10-21 | Private evidence store (not disclosed) |
| Accountable owners and sign-off | Repository owner and named executives | 2026-10-21 | Private evidence store (not disclosed) |
| Product and customer scope | Compliance and Operations | 2026-10-21 | Private evidence store (not disclosed) |
| KYC/CDD: in-house + Dukcapil | Muhammad Febriansyah (Compliance) | 2026-10-21 | Private evidence store (not disclosed) |
| Sanctions/PEP: Dow Jones | Muhammad Febriansyah; Andi Pratama | 2026-10-21 | Private evidence store (not disclosed) |
| Fraud operations: 24/7 in-house | Andi Pratama; Kevin Kusuma | 2026-10-21 | Private evidence store (not disclosed) |
| Limits and velocity | Andi Pratama; Rina Amelia | 2026-10-21 | Private evidence store (not disclosed) |
| Regulatory reports: LBPUE + trial balance | Rina Amelia; Muhammad Febriansyah | 2026-10-21 | Private evidence store (not disclosed) |
| Money data: fee, hold, FX residual | Rina Amelia (Finance) | 2026-10-21 | Private evidence store (not disclosed) |
| SLO, RPO/RTO, alerts | Kevin Kusuma; Hendra Gunawan | 2026-10-21 | Private evidence store (not disclosed) |
| Patch, incident, retention | Hendra Gunawan; Kevin Kusuma; Sarah Wijaya | 2026-10-21 | Private evidence store (not disclosed) |
| Release approvals and independent assessment | Repository owner + CISO + COO + Compliance | 2026-10-21 | Private evidence store (not disclosed) |
| ADR 0072 D1/D2/D3 | Rina Amelia; Muhammad Febriansyah | 2026-10-21 | Private evidence store (not disclosed) |
| Target runtime A: GnuCOBOL/MySQL | Repository owner | 2026-10-21 | `docs/adr/0082-target-runtime.md` |

## Evidence handling

- Do not commit signed approvals, identity documents, contracts, credentials,
  or personal contact details.
- The private evidence store is the source of truth for the signed documents.
- This register is an index. If the evidence reference is missing or disputed,
  the approval is not evidenced in this repository.
- The repository records the attestation; it does not publish or verify the
  signatures.

## Verification boundary

The repository owner attests to the approvals. The engineering team and CI do
not verify signatures. Any external party relying on this register must request
the evidence through the owner's private process.

## Related records

- `docs/GATE0_PACKET.md` - decision scope, inputs, and proposed controls.
- `docs/GATE0_DECISIONS.md` - decision log and owners.
- `docs/TRACEABILITY.md` - implementation and test evidence.
- `docs/STATUS.md` - current engineering state.
- `docs/release-checklist.md` - per-release evidence template.
