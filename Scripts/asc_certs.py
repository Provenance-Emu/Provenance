#!/usr/bin/env python3
"""
asc_certs.py — manage signing certificates through the App Store Connect API.

Certificates are TEAM-level, not per-app, so one run here serves Provenance,
iCube and iFly alike.

    Scripts/asc_certs.py list [--type DEVELOPMENT|DISTRIBUTION]
    Scripts/asc_certs.py revoke ID [ID ...] [--yes]
    Scripts/asc_certs.py revoke --zombies [--yes]
    Scripts/asc_certs.py create --type DEVELOPMENT --out DIR [--name NAME]
    Scripts/asc_certs.py p12 --cer FILE --key FILE --out FILE

Run under 1Password so the credentials never touch disk:

    op run --env-file=.env -- Scripts/asc_certs.py list

Environment: ASC_API_KEY_ID, ASC_API_ISSUER_ID, and one of ASC_API_KEY_PATH /
ASC_API_KEY_CONTENT (else ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8).

Why this exists
---------------
`xcodebuild archive` with automatic signing signs the ARCHIVE with an Apple
Development identity; only -exportArchive re-signs with Distribution. A CI
runner that imports just the Distribution .p12 therefore has no dev identity,
and -allowProvisioningUpdates mints a brand-new Development certificate on
EVERY run. Its private key dies with the ephemeral runner, the account keeps
the corpse, and within a handful of runs Apple's per-account cap is hit:

    error: Choose a certificate to revoke. Your account has reached the
           maximum number of certificates.

`revoke --zombies` clears those (API-created Development certs whose key
nobody holds); `create` mints a Development identity whose key we DO keep,
packaged as a .p12 for the CI keychain so the minting stops.
"""

import argparse
import base64
import hashlib
import json
import os
import secrets
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    import jwt  # PyJWT
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.serialization import pkcs12
    from cryptography.x509.oid import NameOID
except ImportError as e:  # pragma: no cover
    sys.exit(f"error: missing dependency ({e.name}). pip3 install pyjwt cryptography")

API = "https://api.appstoreconnect.apple.com/v1"

# Apple's display name for EVERY certificate created through the API — the CSR
# subject is ignored — so this alone cannot separate the ones xcodebuild minted
# for itself on a CI runner from the ones `create` minted here and whose key we
# hold. The tie-break is the private key: see held_fingerprints().
API_MINTED_NAME = "Created via API"

# Where `create` keeps the certificates whose keys we hold.
KEEP_DIR = Path("~/.appstoreconnect/ci-signing").expanduser()


# ── auth ──────────────────────────────────────────────────────────────────────

def die(msg):
    sys.exit(f"error: {msg}")


def key_pem():
    kid = os.environ.get("ASC_API_KEY_ID") or die("ASC_API_KEY_ID is not set")
    if p := os.environ.get("ASC_API_KEY_PATH"):
        return Path(p).read_text()
    if c := os.environ.get("ASC_API_KEY_CONTENT"):
        # Sniff PEM before base64: macOS-style lenient decoders turn a raw PEM
        # into silent garbage, so check the cheap thing first.
        return c if "BEGIN PRIVATE KEY" in c else base64.b64decode(c).decode()
    for d in ("~/.appstoreconnect/private_keys", "~/private_keys"):
        p = Path(d).expanduser() / f"AuthKey_{kid}.p8"
        if p.exists():
            return p.read_text()
    die(f"no key: set ASC_API_KEY_PATH / ASC_API_KEY_CONTENT, or place AuthKey_{kid}.p8 "
        "in ~/.appstoreconnect/private_keys/")


def token():
    kid = os.environ["ASC_API_KEY_ID"]
    iss = os.environ.get("ASC_API_ISSUER_ID") or die("ASC_API_ISSUER_ID is not set")
    now = int(time.time())
    return jwt.encode(
        {"iss": iss, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key_pem(), algorithm="ES256", headers={"kid": kid, "typ": "JWT"},
    )


def call(method, path, body=None):
    req = urllib.request.Request(
        API + path, method=method, data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r) if r.status != 204 else None
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            detail = "; ".join(f"{x.get('title')}: {x.get('detail')}"
                               for x in json.loads(detail).get("errors", []))
        except (ValueError, AttributeError):
            pass
        die(f"{method} {path} → HTTP {e.code}: {detail}")


# ── certificates ──────────────────────────────────────────────────────────────

def fetch_certs(cert_type=None):
    q = "?limit=200&sort=certificateType"
    if cert_type:
        q += f"&filter[certificateType]={cert_type}"
    return call("GET", "/certificates" + q)["data"]


_held = None


def held_fingerprints():
    """SHA-1 fingerprints of certificates we can actually sign with: every .cer
    `create` saved under KEEP_DIR, plus every identity in the login keychain
    (`security find-identity` prints the fingerprint of each cert that has a
    private key beside it)."""
    global _held
    if _held is not None:
        return _held
    _held = set()
    for cer in KEEP_DIR.glob("**/*.cer"):
        _held.add(hashlib.sha1(cer.read_bytes()).hexdigest().upper())
    try:
        out = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"],
                             capture_output=True, text=True, timeout=15).stdout
        _held.update(w for w in out.split() if len(w) == 40 and all(ch in "0123456789ABCDEF" for ch in w))
    except (OSError, subprocess.TimeoutExpired):
        pass
    return _held


def fingerprint(c):
    return hashlib.sha1(base64.b64decode(c["attributes"]["certificateContent"])).hexdigest().upper()


def is_zombie(c):
    """An API-minted Development certificate whose private key nobody holds.
    It was generated on whichever CI runner asked for it and died with the
    runner; nothing can ever sign with it, it only occupies a slot."""
    a = c["attributes"]
    return (a["certificateType"] == "DEVELOPMENT"
            and a["displayName"] == API_MINTED_NAME
            and fingerprint(c) not in held_fingerprints())


def fmt(c):
    a = c["attributes"]
    exp = a["expirationDate"][:10]
    if is_zombie(c):
        flag = "  ZOMBIE"
    elif fingerprint(c) in held_fingerprints():
        flag = "  (key held)"
    else:
        flag = ""
    return (f"{c['id']:<12} {a['certificateType']:<24} {a.get('platform') or 'ALL':<6} "
            f"exp {exp}  {a['displayName']}{flag}")


def cmd_list(args):
    certs = fetch_certs(args.type)
    for c in certs:
        print(fmt(c))
    z = sum(map(is_zombie, certs))
    print(f"\n{len(certs)} certificate(s), {z} zombie(s)")


def cmd_revoke(args):
    if args.zombies:
        targets = [c for c in fetch_certs("DEVELOPMENT") if is_zombie(c)]
        if not targets:
            print("no zombies found")
            return
    else:
        by_id = {c["id"]: c for c in fetch_certs()}
        missing = [i for i in args.ids if i not in by_id]
        if missing:
            die(f"unknown certificate id(s): {', '.join(missing)}")
        targets = [by_id[i] for i in args.ids]

    print("Will REVOKE (irreversible):")
    for c in targets:
        print("  " + fmt(c))
    if not args.yes:
        if not sys.stdin.isatty():
            die("refusing to revoke without --yes in a non-interactive shell")
        if input("Type 'revoke' to continue: ").strip() != "revoke":
            sys.exit("aborted")
    for c in targets:
        call("DELETE", f"/certificates/{c['id']}")
        print(f"revoked {c['id']}")


def write_private(path, data):
    path.write_bytes(data)
    path.chmod(stat.S_IRUSR | stat.S_IWUSR)


def build_p12(cert_der, key, password, name):
    """PKCS#12 that `security import` on macOS accepts.

    OpenSSL 3's default PBES2/AES-256 + SHA-256 MAC is rejected by macOS's
    importer on some versions ("MAC verification failed" or an unhelpful
    -25264), so stick to the PBES1 3DES/SHA-1 profile Apple's own Keychain
    Access export produces. The .p12 lives in a masked secret, not on a wire,
    so the weaker wrapping is not the trust boundary here.
    """
    enc = (serialization.PrivateFormat.PKCS12.encryption_builder()
           .kdf_rounds(50000)
           .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC)
           .hmac_hash(hashes.SHA1())
           .build(password.encode()))
    return pkcs12.serialize_key_and_certificates(
        name.encode(), key, x509.load_der_x509_certificate(cert_der), None, enc)


def cmd_create(args):
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    out.chmod(0o700)
    slug = args.type.lower()

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([
               x509.NameAttribute(NameOID.COMMON_NAME, args.name),
               x509.NameAttribute(NameOID.COUNTRY_NAME, "US")]))
           .sign(key, hashes.SHA256()))
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()

    print(f"requesting {args.type} certificate…")
    resp = call("POST", "/certificates", {"data": {
        "type": "certificates",
        "attributes": {"certificateType": args.type, "csrContent": csr_pem},
    }})
    cert = resp["data"]
    cert_der = base64.b64decode(cert["attributes"]["certificateContent"])
    password = secrets.token_urlsafe(24)

    key_path = out / f"{slug}.key.pem"
    cer_path = out / f"{slug}.cer"
    p12_path = out / f"{slug}.p12"
    pw_path = out / f"{slug}.p12.password"
    write_private(key_path, key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption()))
    cer_path.write_bytes(cert_der)
    write_private(p12_path, build_p12(cert_der, key, password, args.name))
    write_private(pw_path, password.encode())

    print(f"created {fmt(cert)}")
    print(f"  key:      {key_path}")
    print(f"  cert:     {cer_path}")
    print(f"  p12:      {p12_path}")
    print(f"  password: {pw_path}")
    print("\nInstall in CI (repeat per repo — certificates are team-wide):")
    print(f"  base64 < '{p12_path}' | gh secret set DEV_CERT_P12 -R OWNER/REPO")
    print(f"  gh secret set DEV_P12_PASS -R OWNER/REPO < '{pw_path}'")
    print("\nOr into your login keychain:")
    print(f"  security import '{p12_path}' -P \"$(cat '{pw_path}')\" -T /usr/bin/codesign")


def cmd_p12(args):
    key = serialization.load_pem_private_key(Path(args.key).read_bytes(), None)
    cert_bytes = Path(args.cer).read_bytes()
    cert_der = (x509.load_pem_x509_certificate(cert_bytes) if b"BEGIN CERTIFICATE" in cert_bytes
                else x509.load_der_x509_certificate(cert_bytes)).public_bytes(
                    serialization.Encoding.DER)
    password = args.password or secrets.token_urlsafe(24)
    out = Path(args.out)
    write_private(out, build_p12(cert_der, key, password, args.name))
    write_private(out.with_suffix(".p12.password"), password.encode())
    print(f"wrote {out} (password in {out}.password)")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("list", help="list team certificates")
    s.add_argument("--type", choices=["DEVELOPMENT", "DISTRIBUTION", "IOS_DEVELOPMENT",
                                      "IOS_DISTRIBUTION", "MAC_APP_DISTRIBUTION",
                                      "DEVELOPER_ID_APPLICATION"])
    s.set_defaults(fn=cmd_list)

    s = sub.add_parser("revoke", help="revoke certificates (irreversible)")
    s.add_argument("ids", nargs="*", help="certificate ids from `list`")
    s.add_argument("--zombies", action="store_true",
                   help="revoke every API-minted Development cert (see module doc)")
    s.add_argument("--yes", action="store_true", help="skip the confirmation prompt")
    s.set_defaults(fn=cmd_revoke)

    s = sub.add_parser("create", help="create a certificate, keep the key, emit a .p12")
    s.add_argument("--type", default="DEVELOPMENT", choices=["DEVELOPMENT", "DISTRIBUTION"])
    s.add_argument("--out", required=True, help="0700 directory for key/cer/p12/password")
    s.add_argument("--name", default=f"CI {datetime.now(timezone.utc):%Y-%m-%d}",
                   help="CSR common name; shows as the certificate's display name")
    s.set_defaults(fn=cmd_create)

    s = sub.add_parser("p12", help="bundle an existing key + cert into a .p12")
    s.add_argument("--cer", required=True)
    s.add_argument("--key", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--name", default="signing")
    s.add_argument("--password", help="default: random, written next to the .p12")
    s.set_defaults(fn=cmd_p12)

    args = p.parse_args()
    if args.cmd == "revoke" and not args.ids and not args.zombies:
        p.error("give certificate ids or --zombies")
    args.fn(args)


if __name__ == "__main__":
    main()
