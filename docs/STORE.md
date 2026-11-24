# CentMemo on App Store Connect

- **App**: CentMemo, app id `6837824241`, bundle
  `com.learningischange.centmemo`, SKU `centmemo-ios`, primary category
  Finance, team Learning is Change, Inc. (`L2G756LY8N`).
- **TestFlight**: the internal group "CentMemo testers" has access to all
  builds, so every processed upload reaches its members' devices on its own.
  Ben is in it (invited 2026-11-21).

## Ship a TestFlight build

1. Bump both numbers in `AppVersion.xcconfig` on every build, as in Ben's other
   apps: PATCH +1 and build +1 (1.0.17 (18), then 1.0.18 (19)). *Check:
   `tools/test_version_contract.py`.*
2. Run `tools/test_all.sh` and the iPhone 12 tap tier (`docs/TESTING.md`).
3. Run `tools/submit-appstore.sh ios`. It archives, signs manually through
   the API key, exports, and uploads.
4. Processing takes a few minutes. The build then appears for the group.

## Lessons from the first upload (2026-11-21)

- **App records cannot be created through the API.** Use App Store Connect,
  New App.
- **The app target needs its own scheme** (`scheme: {}` in project.yml), or
  the archive fails with "does not contain a scheme named CentMemo".
- **Internal testers belong to one group.** Moving a tester record from
  another app's group fails with "Tester(s) cannot be assigned". Instead,
  `POST /v1/betaTesters` with the team user's email and the group in
  `betaGroups`.
- **The dev Mac's Xcode works for TestFlight.** App Store review builds go
  through the cloud pipeline (`cloud-appstore-submission`): a beta toolchain
  is rejected after upload.
- **FinanceKit is granted per bundle id**: the app on 2026-11-22 (case
  23676235), the extension `com.learningischange.centmemo.walletdelivery` on
  2026-11-24 (case 23709013). A grant is not a capability: it must then be
  turned on for that App ID in the developer portal (Account Holder sign-in;
  neither the ASC API nor automatic signing can do it), or device builds fail
  with "requires approval from Apple".

## Checking a build's processing state

```sh
tools/with_asc.sh tools/.asc-venv/bin/python -c "import sys; sys.path.insert(0,'tools'); import asc_release as a; b=a.find_build(a.app_id(),'5','IOS'); print(b['attributes']['processingState'])"
```

Homebrew's python3 lacks PyJWT (submit-appstore.sh provisions
`tools/.asc-venv`), and the helpers read `ASC_KEY_ID` and friends from the
environment, so both lines are needed. A watcher without them fails
silently into stderr (tick 13 lost 30 minutes to that).
