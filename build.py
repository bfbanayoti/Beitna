#!/usr/bin/env python3
"""Build the password-protected site from src/.

  src/shell.html + src/styles.css + src/js/*.js  ->  app.html (plaintext bundle, local only)
  app.html + login.html                          ->  index.html (lock screen + AES-256-GCM ciphertext)
  src/ + assets source                           ->  source.enc (encrypted, admin password only)

The app is encrypted with a fresh random key on every build. That key is wrapped once per enabled
password (PBKDF2-SHA256 -> AES-GCM), so any enabled password unlocks it and disabling one means
rebuilding without its slot. Rebuilding also rotates the key, which signs out remembered devices.
source.enc lets the full source tree live on GitHub without being readable; only admin can unpack it.

Local-only files (gitignored, never pushed): src/, app.html, .passwords.json
  .passwords.json = {"passwords": [{"role": "admin", "password": "...", "enabled": true}, ...]}

Usage:
  .venv/bin/python build.py            build everything
  .venv/bin/python build.py unpack     restore src/ (and app.html) from source.enc / index.html
"""
import base64, getpass, glob, io, json, os, re, sys, tarfile
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

ROOT = os.path.dirname(os.path.abspath(__file__))
ITER = 310_000
b64 = lambda b: base64.b64encode(b).decode()
unb64 = base64.b64decode
path = lambda *p: os.path.join(ROOT, *p)


def kek(password, salt):
    return PBKDF2HMAC(hashes.SHA256(), 32, salt, ITER).derive(password.encode())


def seal(data, passwords):
    """Encrypt data with a fresh key, wrapped once per password."""
    key, iv = AESGCM.generate_key(256), os.urandom(12)
    slots = []
    for p in passwords:
        salt, wiv = os.urandom(16), os.urandom(12)
        slots.append({'role': p['role'], 'salt': b64(salt), 'iv': b64(wiv),
                      'key': b64(AESGCM(kek(p['password'], salt)).encrypt(wiv, key, None))})
    return {'v': 1, 'iter': ITER, 'kid': b64(os.urandom(9)), 'iv': b64(iv),
            'ct': b64(AESGCM(key).encrypt(iv, data, None)), 'slots': slots}


def unseal(payload, pw):
    for s in payload['slots']:
        try:
            key = AESGCM(kek(pw, unb64(s['salt']))).decrypt(unb64(s['iv']), unb64(s['key']), None)
        except Exception:
            continue
        return AESGCM(key).decrypt(unb64(payload['iv']), unb64(payload['ct']), None), s['role']
    return None, None


def bundle():
    shell = open(path('src', 'shell.html'), encoding='utf-8').read()
    css = open(path('src', 'styles.css'), encoding='utf-8').read()
    js = ''.join(open(f, encoding='utf-8').read() for f in sorted(glob.glob(path('src', 'js', '*.js'))))
    html = shell.replace('{{CSS}}', css).replace('{{JS}}', js)
    open(path('app.html'), 'w', encoding='utf-8').write(html)
    return html.encode()


def build():
    app = bundle()
    cfg = json.load(open(path('.passwords.json')))
    enabled = [p for p in cfg['passwords'] if p.get('enabled', True)]
    admins = [p for p in enabled if p['role'] == 'admin']
    if not admins:
        sys.exit('Refusing to build without an enabled admin password.')
    payload = seal(app, enabled)
    shell = open(path('login.html'), encoding='utf-8').read()
    open(path('index.html'), 'w', encoding='utf-8').write(
        shell.replace('/*PAYLOAD*/null', json.dumps(payload, separators=(',', ':'))))
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz') as tar:
        tar.add(path('src'), arcname='src')
    json.dump(seal(buf.getvalue(), admins), open(path('source.enc'), 'w'), separators=(',', ':'))
    print(f"built: app {len(app)//1024} KB, {len(enabled)} password(s) ({', '.join(p['role'] for p in enabled)}), key {payload['kid']}")


def unpack():
    pw = getpass.getpass('Admin password: ')
    data, role = unseal(json.load(open(path('source.enc'))), pw)
    if not data:
        sys.exit('Wrong password (source.enc needs the admin password).')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
        tar.extractall(ROOT, filter='data') if hasattr(tarfile, 'data_filter') else tar.extractall(ROOT)
    bundle()
    print('src/ and app.html restored')


if __name__ == '__main__':
    unpack() if sys.argv[1:] == ['unpack'] else build()
