---
name: approve-gate
description: Review the five spec documents and formally record approval, unlocking the Code Generator stage. Use when the user is ready to approve specs, run the approval gate, or proceed to code generation. Do not delegate — this is the single human checkpoint and requires a live yes/no.
---

You are running the **Approval Gate** — the single human checkpoint in this pipeline. Nothing downstream (Code Generator, Security, Flow Validation, Implementation) may run until this completes.

## Step 1 — Verify the document set exists

Check for all five:
- `architecture.html`
- `product-overview.pdf`
- `design-spec.md`
- `analytics-spec.md`
- `test-plan.md`

If any are missing, stop and tell the user which upstream agent still needs to run. Do not proceed.

## Step 2 — Summarize what they're approving

Read all five documents and give the user a concise briefing covering:
- The core system architecture and chosen tech stack (and which choices were the agent's own vs. explicitly requested)
- Screen/flow count and the onboarding approach
- Any item carried over from `requirements.json`'s `meta.assumptionsMade` — these are decisions made *for* the user, so surface every one of them here explicitly
- Any gaps, open questions, or "verify with counsel" flags raised in the documents
- Anything flagged as a launch blocker (e.g. Privacy Policy needing drafting)

Be direct about weaknesses. This is the user's last cheap moment to change direction — do not soften real concerns to make the plan look finished.

## Step 2a — Full feature/flow walkthrough

This is the concrete "here is how the finished app will actually work" preview — the thing the user is really approving, not just the documents that describe it. Everything downstream (Code Generator, Implementation) is driven off this same walkthrough, so it needs to be complete now, not discovered screen-by-screen later.

Produce, in order:
1. **Every screen in the build**, grouped by role/surface (e.g. customer mobile, vendor mobile, web-admin), each with a one-line purpose.
2. **Every end-to-end flow**, as a numbered sequence of screens/actions from entry to completion (e.g. "Browse → Vendor Profile → Chat → Agreement → E-Sign → Escrow Payment → Booking Confirmed"). Cover every flow named in design-spec.md's flow diagrams — do not summarize only the "main" one.
3. **Every integration point** (payments, SMS/OTP, push, AI/LLM, object storage, maps, etc.) and, for each, whether a real provider/credential was named in requirements.json or is still an open choice — this is what determines whether Code Generator can wire it for real or must leave a clearly-marked placeholder.
4. **A priority-ordered build list** — the order Implementation will build flows in (see the implementation-agent's slice-selection priority), so the user can reorder it now if their real priority differs (e.g. they want the payment flow built before onboarding polish).

This walkthrough becomes the shared checklist for both Code Generator and Implementation — write it to `feature-plan.md` in the project root (screens, flows, integrations, build order) alongside `approval.json` in Step 4, so downstream agents read it instead of re-deriving it from the specs independently.

## Step 3 — Ask for explicit approval

Ask the user plainly whether they approve proceeding to code generation. Accept a clear yes, a yes-with-changes (in which case tell them which agent to re-run and stop), or a no. This approval covers the full walkthrough from Step 2a, including the build order — if the user wants a different build order, update it now rather than after generation starts.

Do not assume approval. Do not proceed on an ambiguous answer — ask again.

## Step 4 — Record it

Only on a clear approval, write both files to the project root.

`feature-plan.md` — the full Step 2a walkthrough (screens, flows, integration points and their real-vs-placeholder status, build order), verbatim as approved. This is what Code Generator and Implementation read instead of re-deriving the same picture independently — keep it in sync if the user requests changes to the build order later.

`approval.json`:

```json
{
  "approved": true,
  "approvedAt": "<ISO timestamp>",
  "documentsReviewed": [
    "architecture.html",
    "product-overview.pdf",
    "design-spec.md",
    "analytics-spec.md",
    "test-plan.md",
    "feature-plan.md"
  ],
  "assumptionsAccepted": ["...list surfaced in step 2..."],
  "notedConcerns": ["...anything the user flagged but chose to proceed past..."],
  "buildOrder": ["...the approved priority-ordered slice list from feature-plan.md..."]
}
```

Then tell the user the gate is cleared and they can run the Code Generator agent (`code-generator-agent`) — and that Implementation, once it starts, will build straight through `buildOrder` autonomously rather than needing to be invoked per feature (see implementation-agent).

## If the user wants changes

Do not write `approval.json` or `feature-plan.md`. Tell them which agent to re-run to revise the relevant document, then re-run `/approve-gate` afterward.
