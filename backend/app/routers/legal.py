"""Draft legal document pages — NOT production-ready (compliance LB-1/LB-2).

Serves counsel-review drafts at stable URLs until final Privacy Policy and ToS are
published. Replace `settings.privacy_policy_url` / `terms_of_service_url` when live.
"""

from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/legal", tags=["legal"], include_in_schema=False)

_DRAFT_BANNER = """
<div style="background:#E07B1A;color:#fff;padding:12px 16px;font-weight:700;text-align:center;">
  DRAFT — FOR REVIEW ONLY. Not a final legal document. Do not submit to app stores.
</div>
"""

_PRIVACY_BODY = """
<h1>Anointed — Privacy Policy (Draft)</h1>
<p><em>Last updated: draft placeholder. Requires legal counsel review before launch.</em></p>
<h2>Who we are</h2>
<p>Anointed is a Bible character quiz app for children and families.</p>
<h2>Information we collect</h2>
<ul>
  <li>Display name and age (to apply age-appropriate rules including COPPA)</li>
  <li>Mobile number (optional phone sign-up path)</li>
  <li>Game progress, scores, and level attempts</li>
  <li>Parent/guardian contact information for users under 13 (verifiable parental consent)</li>
  <li>Purchase records (store transaction IDs only — no payment card data)</li>
</ul>
<h2>Children under 13</h2>
<p>We require verifiable parental consent before an under-13 account is activated.
Under-13 players do not see ads. Leaderboard names are truncated to first name and
last initial.</p>
<h2>Your choices</h2>
<p>Parents may delete a child's account in the app (Profile → Delete account).</p>
<h2>Contact</h2>
<p>support@anointed.app</p>
"""

_TERMS_BODY = """
<h1>Anointed — Terms of Service (Draft)</h1>
<p><em>Last updated: draft placeholder. Requires legal counsel review before launch.</em></p>
<h2>Using Anointed</h2>
<p>Anointed is provided for personal, non-commercial Bible learning. You must provide
accurate age information so we can apply the correct safety rules.</p>
<h2>Purchases</h2>
<p>Level unlocks are sold through the Apple App Store or Google Play. All sales are
subject to the store's terms and refund policies.</p>
<h2>Account termination</h2>
<p>You may delete your account at any time from the Profile screen.</p>
<h2>Disclaimer</h2>
<p>Content is for educational purposes. Verify theological accuracy with your church
community as needed.</p>
"""


@router.get("/privacy", response_class=HTMLResponse)
def privacy_draft() -> str:
    return f"<!doctype html><html><body style='font-family:sans-serif;max-width:720px;margin:0 auto;padding:24px'>{_DRAFT_BANNER}{_PRIVACY_BODY}</body></html>"


@router.get("/terms", response_class=HTMLResponse)
def terms_draft() -> str:
    return f"<!doctype html><html><body style='font-family:sans-serif;max-width:720px;margin:0 auto;padding:24px'>{_DRAFT_BANNER}{_TERMS_BODY}</body></html>"
