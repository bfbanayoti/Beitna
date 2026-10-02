#!/usr/bin/env python3
"""Build the password-protected index.html from app.html.

The app is encrypted with a fresh random key (AES-256-GCM) on every build. That key is then
wrapped once per enabled password (PBKDF2-SHA256 -> AES-GCM), so any enabled password unlocks
it and disabling one password just means rebuilding without its slot. Rebuilding also rotates
the key, which signs out every remembered device.

Local-only files (gitignored, never pushed):
  app.html          plaintext app source — edit this one
  .passwords.json   {"passwords": [{"role": "admin", "password": "...", "enabled": true}, ...]}

Usage:
  .venv/bin/python build.py            encrypt app.html -> index.html
  .venv/bin/python build.py unpack     recover app.html from index.html (asks for a password)
"""
import base64, getpass, json, os, re, sys
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

ROOT = os.path.dirname(os.path.abspath(__file__))
ITER = 310_000
b64 = lambda b: base64.b64encode(b).decode()
unb64 = base64.b64decode


def kek(password, salt):
    return PBKDF2HMAC(hashes.SHA256(), 32, salt, ITER).derive(password.encode())


def build():
    app = open(os.path.join(ROOT, 'app.html'), 'rb').read()
    cfg = json.load(open(os.path.join(ROOT, '.passwords.json')))
    enabled = [p for p in cfg['passwords'] if p.get('enabled', True)]
    if not any(p['role'] == 'admin' for p in enabled):
        sys.exit('Refusing to build without an enabled admin password.')
    key, iv = AESGCM.generate_key(256), os.urandom(12)
    slots = []
    for p in enabled:
        salt, wiv = os.urandom(16), os.urandom(12)
        slots.append({'role': p['role'], 'salt': b64(salt), 'iv': b64(wiv),
                      'key': b64(AESGCM(kek(p['password'], salt)).encrypt(wiv, key, None))})
    payload = {'v': 1, 'iter': ITER, 'kid': b64(os.urandom(9)), 'iv': b64(iv),
               'ct': b64(AESGCM(key).encrypt(iv, app, None)), 'slots': slots}
    shell = open(os.path.join(ROOT, 'login.html'), encoding='utf-8').read()
    out = shell.replace('/*PAYLOAD*/null', json.dumps(payload, separators=(',', ':')))
    open(os.path.join(ROOT, 'index.html'), 'w', encoding='utf-8').write(out)
    print(f"index.html built: {len(enabled)} password(s) enabled ({', '.join(p['role'] for p in enabled)}), key {payload['kid']}")


def unpack():
    html = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
    payload = json.loads(re.search(r'const PAYLOAD=(\{.*?\});', html, re.S).group(1))
    pw = getpass.getpass('Password: ')
    for s in payload['slots']:
        try:
            key = AESGCM(kek(pw, unb64(s['salt']))).decrypt(unb64(s['iv']), unb64(s['key']), None)
        except Exception:
            continue
        app = AESGCM(key).decrypt(unb64(payload['iv']), unb64(payload['ct']), None)
        open(os.path.join(ROOT, 'app.html'), 'wb').write(app)
        return print(f"app.html restored (unlocked with the {s['role']} password)")
    sys.exit('Wrong password.')


if __name__ == '__main__':
    unpack() if sys.argv[1:] == ['unpack'] else build()
