# AdMob COPPA checklist (C-11)

Code implements under-13 ad blocking and `tagForChildDirectedTreatment`. **Live account configuration must be verified by a human** before enabling ads in production.

## Before enabling production ads

- [ ] AdMob account: mark app as **child-directed** / Families compliant
- [ ] Each interstitial ad unit: child-directed treatment enabled
- [ ] Google Play: **Families policy** declaration completed
- [ ] Apple App Store: age rating and ad declaration match COPPA posture
- [ ] Set `ADMOB_*` unit IDs in production `.env` only after checklist complete
- [ ] Confirm no ad SDK initializes for under-13 sessions (test with `<13` account)

## Code references

- Server: `backend/app/routers/ads.py`, `backend/app/services/ads.py`
- Client: `mobile/lib/services/ads_service.dart`

## Production guard

Set `ADMOB_PRODUCTION_ACK=true` in production only after this checklist is signed off.
If unset in production, `/v1/ads/config` returns `ads_enabled: false`.
