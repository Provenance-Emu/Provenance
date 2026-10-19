---
name: asc-cloudkit
description: Use when working with App Store Connect API or CloudKit for the Provenance project. Handles JWT auth, ASC API queries, CloudKit schema export/import/promote, and cktool operations. Trigger phrases: "check builds", "app store connect", "cloudkit schema", "promote schema", "query records", "asc api", "cktool", "testflight", "dsyms".
version: 1.0.0
disable-model-invocation: true
allowed-tools: Bash
---

# App Store Connect & CloudKit Tools (Provenance)

Source the helper script before running any commands:

```bash
source ~/.config/provenance-dev/asc.sh
```

## Credentials

| Key | Value |
|-----|-------|
| Key ID | `3HG74R58TM` |
| Issuer ID | `d9e9b4bc-811d-4bbe-8ebc-7e108cfe5754` |
| Key file | `~/.appstoreconnect/private_keys/AuthKey_3HG74R58TM.p8` |
| Team ID | `S32Z3HMYVQ` |
| App ID | `1596862805` |
| Prod container | `iCloud.org.provenance-emu.provenance` |
| Dev container | `iCloud.org.provenance-emu.provenance.dev` |

## JWT Token

```bash
source ~/.config/provenance-dev/asc.sh
asc_token          # print a fresh JWT (valid 20 min)
```

**Note:** `cktool save-token` is **incompatible** with this JWT — cktool uses its own management token format. Use the ASC API directly via `asc()` or `curl` instead.

## ASC API Queries

```bash
source ~/.config/provenance-dev/asc.sh

# Convenience shortcuts:
asc_app_info       # App metadata
asc_builds         # Recent 10 builds sorted by upload date
asc_testflight     # TestFlight review details
asc_dsyms          # dSYM download URLs for recent builds

# Raw API calls:
asc "/v1/apps/1596862805"
asc "/v1/builds?filter[app]=1596862805&limit=25&sort=-uploadedDate"
asc "/v1/betaGroups?filter[app]=1596862805"
asc "/v1/appStoreVersions?filter[app]=1596862805&filter[platform]=IOS"
```

## CloudKit Schema Operations

```bash
source ~/.config/provenance-dev/asc.sh

# Export schema (development or production):
ck_schema_export development   # export dev schema
ck_schema_export production    # export prod schema

# Promote dev → production (non-destructive, adds new types/fields only):
ck_schema_promote              # interactive confirmation required

# Query records:
ck_query PVGame                # query PVGame records in production private DB
ck_query PVGame iCloud.org.provenance-emu.provenance development
ck_query PVSaveState iCloud.org.provenance-emu.provenance.dev development
```

## Direct cktool Commands

```bash
# cktool does NOT accept ASC JWTs — manage its token separately
xcrun cktool export-schema \
  --team-id S32Z3HMYVQ \
  --container-identifier iCloud.org.provenance-emu.provenance \
  --environment development \
  --output-file /tmp/ck_schema.json

xcrun cktool import-schema \
  --team-id S32Z3HMYVQ \
  --container-identifier iCloud.org.provenance-emu.provenance \
  --environment production \
  --file /tmp/ck_schema.json

xcrun cktool query-records \
  --team-id S32Z3HMYVQ \
  --container-identifier iCloud.org.provenance-emu.provenance \
  --environment production \
  --database-type private \
  --record-type PVGame
```

## Common Tasks

### Check if a build is processing
```bash
source ~/.config/provenance-dev/asc.sh
asc_builds | python3 -c "
import json, sys
data = json.load(sys.stdin)
for b in data.get('data', []):
    a = b['attributes']
    print(a.get('version','?'), a.get('processingState','?'), a.get('uploadedDate','?'))
"
```

### Get dSYM URL for latest build
```bash
source ~/.config/provenance-dev/asc.sh
asc_dsyms | python3 -c "
import json, sys
data = json.load(sys.stdin)
for b in data.get('data', []):
    url = b['attributes'].get('dsymUrl')
    if url: print(url)
"
```

### Export and diff CloudKit schemas
```bash
source ~/.config/provenance-dev/asc.sh
ck_schema_export development iCloud.org.provenance-emu.provenance > /tmp/dev_schema.json
ck_schema_export production  iCloud.org.provenance-emu.provenance > /tmp/prod_schema.json
diff /tmp/dev_schema.json /tmp/prod_schema.json
```
