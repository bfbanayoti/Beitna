# Beitna · بيتنا

A household finance app for couples, in Arabic and English. It tracks shared and personal spending, how shared costs are split, savings goals, bills, accounts, investments and a jam'iya. Designed for iPhone (add it to the Home Screen from Safari).

## Password protection

The published `index.html` is a lock screen plus the app encrypted with AES-256-GCM. Nothing readable is served until a valid password is entered. Each password unlocks its own copy of the app key (PBKDF2-SHA256, 310k iterations), so passwords can be turned off one at a time:

| Role  | Purpose |
|-------|---------|
| admin | Owner. Always enabled; the build refuses to run without it. |
| guest | Shareable. Can be revoked without affecting admin. |

Every build rotates the key, so it also signs out every device that chose "Remember this device".

## Working on it

`app.html` (the plaintext source) and `.passwords.json` stay on the owner's machine and are never committed.

```bash
python3 -m venv .venv && .venv/bin/pip install cryptography   # once
.venv/bin/python build.py            # app.html + login.html -> index.html
.venv/bin/python build.py unpack     # recover app.html from index.html with any password
```

To revoke the guest password, set `"enabled": false` on it in `.passwords.json`, rebuild and push.

## Screens

- **Home:** net worth, spending vs last month, savings rate, balance to settle, bills due this week, goals, tips, salary allocation, jam'iya, monthly money date
- **Goals:** progress, months left, required monthly amount, each partner's contributions
- **Accounts:** balances with per-partner visibility, bills, investments
- **Insights:** filters by period, partner, category, account, method and tag; category breakdown, top merchants, biggest changes, fixed vs variable, net worth trend
- **Me:** access level and lock, partner switch, language, numerals, split rules, savings target, security, export, reset demo data

Opens with generated demo data. Changes are saved in the browser's `localStorage` under `beitna:v1`.
