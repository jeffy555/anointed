# Legal documents — launch blockers LB-1 / LB-2

Privacy Policy and Terms of Service **must be drafted by qualified legal counsel** before App Store / Play Store submission.

## Current state

| Document | Status | Draft URL (backend) |
|----------|--------|---------------------|
| Privacy Policy | **Draft only — not production-ready** | `/legal/privacy` on the API host |
| Terms of Service | **Draft only — not production-ready** | `/legal/terms` on the API host |

Update these environment variables once final documents are hosted:

```
PRIVACY_POLICY_URL=https://your-domain.com/privacy
TERMS_OF_SERVICE_URL=https://your-domain.com/terms
```

The mobile M-08 screen and VPC email templates read URLs from the server profile/config.

## VPC consent copy (C-10)

Parent email and M-06F web form text in `backend/app/services/consent.py` and
`backend/app/web/templates/consent_verify.html` are **draft COPPA-oriented language**
— still requires counsel sign-off before US launch.

## IAP duplicate-receipt policy

If one store transaction is submitted by two accounts, the API returns HTTP 409
(`receipt_already_used`). Default policy: **refuse and route to support**. Document
your transfer/refund policy before launch.
