#!/usr/bin/env python3
"""Distribute an uploaded TestFlight build to external beta groups.

`xcodebuild -exportArchive` with `destination=upload` (and `altool
--upload-app`) only puts a build into App Store Connect. Internal groups with
"automatic distribution" pick it up; external groups -- the public TestFlight
links -- never do. Every nightly therefore reached only the Internal group,
and the public links kept serving whichever build someone last assigned by
hand, until it expired 90 days later (iCube: builds from 2026-06-10 expired
2026-09-08; Provenance's Public group was on an 2026-08-18 build).

This script closes that gap after the upload:

  1. wait for the build (by CFBundleVersion + platform) to finish processing;
  2. mark it exempt from export-compliance if the binary did not declare it
     (`ITSAppUsesNonExemptEncryption` missing leaves the build stuck on
     "Missing Compliance", which blocks external distribution);
  3. set the "What to Test" text;
  4. add it to the requested external beta groups (default: every external
     group with a public link enabled);
  5. submit it for Beta App Review unless a submission already exists.

Environment:
  ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_CONTENT (raw .p8 or base64)
  BUNDLE_ID          e.g. com.joemattiello.iCube
  BUILD_NUMBER       the CFBundleVersion the archive was uploaded with
  PLATFORM           IOS | TV_OS | MAC_OS | VISION_OS   (default IOS)
  GROUPS             comma-separated beta group names; empty = all external
                     groups that have a public link enabled
  WHATS_NEW          optional "What to Test" text
  TIMEOUT_MINUTES    how long to wait for processing (default 60)
  SUBMIT_FOR_REVIEW  true|false (default true)
  DRY_RUN            true|false (default false) -- read-only, prints the plan

Exit status is non-zero when the build never appears, fails processing, or a
requested group does not exist. Adding a build that is already in a group is
treated as success, so re-running is safe.
"""

from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, "")
    if value == "" and default is None:
        sys.exit(f"::error::{name} is not set")
    return value if value != "" else default  # type: ignore[return-value]


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def key_pem() -> str:
    content = env("ASC_API_KEY_CONTENT")
    if "BEGIN PRIVATE KEY" in content:
        return content
    try:
        decoded = base64.b64decode(content).decode()
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"::error::ASC_API_KEY_CONTENT is neither a .p8 nor base64: {exc}")
    if "BEGIN PRIVATE KEY" not in decoded:
        sys.exit("::error::decoded ASC_API_KEY_CONTENT is not a PEM private key")
    return decoded


def make_token() -> str:
    import jwt  # PyJWT + cryptography, installed by action.yml

    now = int(time.time())
    return jwt.encode(
        {"iss": env("ASC_API_ISSUER_ID"), "iat": now, "exp": now + 19 * 60,
         "aud": "appstoreconnect-v1"},
        key_pem(), algorithm="ES256",
        headers={"kid": env("ASC_API_KEY_ID"), "typ": "JWT"},
    )


class Client:
    def __init__(self) -> None:
        self._token = make_token()
        self._minted = time.time()

    def _headers(self) -> dict[str, str]:
        if time.time() - self._minted > 15 * 60:
            self._token = make_token()
            self._minted = time.time()
        return {"Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json"}

    def call(self, method: str, path: str, body: dict | None = None,
             **query: str) -> dict:
        url = API + path + (("?" + urllib.parse.urlencode(query)) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method,
                                     headers=self._headers())
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")
            raise ApiError(exc.code, detail) from None

    def get(self, path: str, **query: str) -> dict:
        return self.call("GET", path, **query)


class ApiError(Exception):
    def __init__(self, status: int, detail: str) -> None:
        super().__init__(f"HTTP {status}: {detail[:600]}")
        self.status = status
        self.detail = detail


def find_app(client: Client, bundle_id: str) -> str:
    apps = client.get("/v1/apps", **{"filter[bundleId]": bundle_id,
                                     "fields[apps]": "bundleId"})["data"]
    if not apps:
        sys.exit(f"::error::no app with bundle id {bundle_id} visible to this key")
    return apps[0]["id"]


def find_build(client: Client, app_id: str, build_number: str,
               platform: str) -> dict | None:
    result = client.get(
        "/v1/builds",
        **{"filter[app]": app_id, "filter[version]": build_number,
           "filter[preReleaseVersion.platform]": platform,
           "fields[builds]": "version,processingState,usesNonExemptEncryption,"
                             "expired,betaGroups,betaAppReviewSubmission",
           "include": "betaGroups,betaAppReviewSubmission",
           "fields[betaGroups]": "name",
           "fields[betaAppReviewSubmissions]": "betaReviewState",
           "limit": "5"})
    if not result["data"]:
        return None
    build = result["data"][0]
    included = {(i["type"], i["id"]): i for i in result.get("included", [])}
    build["_groups"] = {included[("betaGroups", g["id"])]["attributes"]["name"]
                        for g in build["relationships"]["betaGroups"]["data"]
                        if ("betaGroups", g["id"]) in included}
    submission = build["relationships"].get("betaAppReviewSubmission", {}).get("data")
    build["_review"] = (included[("betaAppReviewSubmissions", submission["id"])]
                        ["attributes"]["betaReviewState"] if submission else None)
    return build


def wait_for_build(client: Client, app_id: str, build_number: str,
                   platform: str, timeout_minutes: int) -> dict:
    deadline = time.time() + timeout_minutes * 60
    delay = 30
    while True:
        build = find_build(client, app_id, build_number, platform)
        state = build["attributes"]["processingState"] if build else "NOT_YET_VISIBLE"
        if state == "VALID":
            return build
        if state in {"FAILED", "INVALID"}:
            sys.exit(f"::error::build {build_number} ({platform}) finished processing as {state}")
        if time.time() > deadline:
            sys.exit(f"::error::build {build_number} ({platform}) still {state} after "
                     f"{timeout_minutes} min -- giving up (it will stay Internal-only)")
        print(f"build {build_number} ({platform}): {state}; retrying in {delay}s", flush=True)
        time.sleep(delay)
        delay = min(delay + 15, 120)


def list_groups(client: Client, app_id: str) -> list[dict]:
    return client.get(f"/v1/apps/{app_id}/betaGroups",
                      **{"fields[betaGroups]": "name,isInternalGroup,publicLinkEnabled",
                         "limit": "200"})["data"]


def choose_groups(groups: list[dict], wanted: str) -> list[dict]:
    if wanted.strip():
        names = [n.strip() for n in wanted.split(",") if n.strip()]
        by_name = {g["attributes"]["name"]: g for g in groups}
        missing = [n for n in names if n not in by_name]
        if missing:
            sys.exit(f"::error::beta group(s) not found: {missing}; "
                     f"available: {sorted(by_name)}")
        return [by_name[n] for n in names]
    return [g for g in groups
            if not g["attributes"]["isInternalGroup"]
            and g["attributes"]["publicLinkEnabled"]]


def main() -> None:
    bundle_id = env("BUNDLE_ID")
    build_number = env("BUILD_NUMBER")
    platform = env("PLATFORM", "IOS").upper()
    wanted = env("GROUPS", "")
    whats_new = env("WHATS_NEW", "")
    timeout_minutes = int(env("TIMEOUT_MINUTES", "60"))
    submit = truthy(env("SUBMIT_FOR_REVIEW", "true"))
    dry_run = truthy(env("DRY_RUN", "false"))

    client = Client()
    app_id = find_app(client, bundle_id)
    build = wait_for_build(client, app_id, build_number, platform, timeout_minutes)
    build_id = build["id"]
    attrs = build["attributes"]
    print(f"build {build_number} ({platform}) is {attrs['processingState']}: id={build_id} "
          f"groups={sorted(build['_groups'])} review={build['_review']} "
          f"nonExemptEncryption={attrs.get('usesNonExemptEncryption')}")

    targets = choose_groups(list_groups(client, app_id), wanted)
    plan = [g for g in targets if g["attributes"]["name"] not in build["_groups"]]
    print("target groups:", [g["attributes"]["name"] for g in targets])
    print("to add:", [g["attributes"]["name"] for g in plan] or "nothing (already assigned)")
    if dry_run:
        print("DRY_RUN=true -- no changes made")
        return

    if attrs.get("usesNonExemptEncryption") is None:
        client.call("PATCH", f"/v1/builds/{build_id}",
                    {"data": {"type": "builds", "id": build_id,
                              "attributes": {"usesNonExemptEncryption": False}}})
        print("set usesNonExemptEncryption=false (binary did not declare it)")

    if whats_new:
        locs = client.get(f"/v1/builds/{build_id}/betaBuildLocalizations",
                          **{"fields[betaBuildLocalizations]": "locale,whatsNew"})["data"]
        if locs:
            client.call("PATCH", f"/v1/betaBuildLocalizations/{locs[0]['id']}",
                        {"data": {"type": "betaBuildLocalizations", "id": locs[0]["id"],
                                  "attributes": {"whatsNew": whats_new[:4000]}}})
        else:
            client.call("POST", "/v1/betaBuildLocalizations",
                        {"data": {"type": "betaBuildLocalizations",
                                  "attributes": {"locale": "en-US", "whatsNew": whats_new[:4000]},
                                  "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
        print("set What to Test")

    for group in plan:
        name = group["attributes"]["name"]
        try:
            client.call("POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
                        {"data": [{"type": "builds", "id": build_id}]})
            print(f"added to {name!r}")
        except ApiError as exc:
            if exc.status == 409 or "already" in exc.detail.lower():
                print(f"already in {name!r}")
            else:
                raise

    if submit and build["_review"] is None:
        try:
            client.call("POST", "/v1/betaAppReviewSubmissions",
                        {"data": {"type": "betaAppReviewSubmissions",
                                  "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
            print("submitted for Beta App Review")
        except ApiError as exc:
            # ASC may have auto-submitted when the first external group was
            # attached; a duplicate submission is a 409, not a failure.
            if exc.status == 409 or "already" in exc.detail.lower():
                print("Beta App Review submission already exists")
            else:
                raise
    elif submit:
        print(f"Beta App Review state already {build['_review']}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(f"### TestFlight distribution\n\n`{bundle_id}` build `{build_number}` "
                     f"({platform}) → {', '.join(g['attributes']['name'] for g in targets) or 'no groups'}\n")


if __name__ == "__main__":
    main()
