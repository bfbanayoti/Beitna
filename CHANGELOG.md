# Beitna · بيتنا — Changelog

Each version is a GitHub Release (tag `vX.Y`) with a downloadable copy of the files exactly as they were, and a link
comparing it with the version before. The same notes appear in the app under **Me → What's New**. Numbering: **v0.1.x** during development, going up gradually (v0.1.10, v0.1.11, …). Bigger steps (v0.2.0) and **v1.0.0, the App Store launch**, only when the owner says so.
The live app always runs the latest version. Dates are when the version was published (Amman time).

| Version | Date | Highlights |
|---|---|---|
| [v0.1.9](#v019--3-october-2026) | 3 Oct 2026 | In-app What's New (App Store–style version history) |
| [v0.1.8](#v018--3-october-2026) | 3 Oct 2026 | Username + password logins, Sign in / Sign up, Jordanian names, "Beit …" home name |
| [v0.1.7](#v017--3-october-2026) | 3 Oct 2026 | Subscription-only access, payment screen with Apple Pay / Google Pay, owner walkthrough |
| [v0.1.6](#v016--3-october-2026) | 3 Oct 2026 | Subscriptions (2 / 4 JOD), payment & refund policy, name your home |
| [v0.1.5](#v015--3-october-2026) | 3 Oct 2026 | Sync between both partners' phones |
| [v0.1.4](#v014--2-october-2026) | 2 Oct 2026 | Beitna Analytics tracking, privacy policy |
| [v0.1.3](#v013--2-october-2026) | 2 Oct 2026 | Proof of payment, credit cards, spend per person, smooth charts |
| [v0.1.2](#v012--2-october-2026) | 2 Oct 2026 | Luxury Home, Excel/statement import, settlements, Face ID, home-screen app |
| [v0.1.1](#v011--2-october-2026) | 2 Oct 2026 | Liquid glass iPhone redesign, encrypted password lock, guest restrictions |
| [v0.1.0](#v010--2-october-2026) | 2 Oct 2026 | First version of the app |

## v0.1.9 — 3 October 2026
[Compare with v0.1.8](https://github.com/bfbanayoti/Beitna/compare/v0.1.8...v0.1.9) · [Download v0.1.9](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.9)

**What's New (as in the App Store):** See every update to Beitna, newest first, in Me → What's New. After each update, a short summary of what changed appears once.
- In-app version history in Arabic and English; pop-up once per new version.
- Every version below links to its exact file changes ("Compare with v…").

## v0.1.8 — 3 October 2026
[Compare with v0.1.7](https://github.com/bfbanayoti/Beitna/compare/v0.1.7...v0.1.8) · [Download v0.1.8](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.8)

- Login is now **username + password**; each login unlocks its own sealed key, carrying the person's name and partner.
- Login screen: **Sign in / Sign up** tabs (sign-up is by invitation during testing; nothing is saved).
- Logins: Barsoum Banayoti (admin), Ahmad Al-Khatib + Sara (guest), Zaid Al-Rawashdeh + Lina (test user).
- "**Beit Banayoti**" above the greeting (semibold); the top bar always says Beitna.
- Sign-in goes straight into the app (no Face ID step; sample household on new phones).
- Fixes: Arabic spelling برسوم, sign-up email field, link-style buttons.

## v0.1.7 — 3 October 2026
[Compare with v0.1.6](https://github.com/bfbanayoti/Beitna/compare/v0.1.6...v0.1.7) · [Download v0.1.7](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.7)

- Subscription required after sign-up; no free activation. Admin and guest logins count as subscribed.
- Payment screen: order summary, Apple Pay and Google Pay, card form area, Pay button.
- Owner-only "Walk through sign-up" with a scratch household (nothing saved or charged).
- Sign in for re-installs, partner linking with a code (Individual plan), tab bar hidden on full-screen steps, last tab "Me".
- Feedback: darker "+" button, income quick-entry example.

## v0.1.6 — 3 October 2026
[Compare with v0.1.5](https://github.com/bfbanayoti/Beitna/compare/v0.1.5...v0.1.6) · [Download v0.1.6](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.6)

- Subscriptions: Individual 2 JOD / month, Couple 4 JOD / month; plan step in the sign-up form.
- Public payment & refund policy (Arabic / English).
- Name your home: "Beit …" with a Jordanian example (Al-Majali).

## v0.1.5 — 3 October 2026
[Compare with v0.1.4](https://github.com/bfbanayoti/Beitna/compare/v0.1.4...v0.1.5) · [Download v0.1.5](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.5)

- Sync between both phones through Supabase: accounts, shared household, invite codes, live three-way merge.
- Hidden-from-partner accounts stored separately and readable only by their owner.

## v0.1.4 — 2 October 2026
[Compare with v0.1.3](https://github.com/bfbanayoti/Beitna/compare/v0.1.3...v0.1.4) · [Download v0.1.4](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.4)

- Beitna Analytics: opens, wrong passwords, sessions and screen/button activity (no amounts or typed text; IP not stored).
- iOS version fix for iOS 26+; privacy policy page.

## v0.1.3 — 2 October 2026
[Compare with v0.1.2](https://github.com/bfbanayoti/Beitna/compare/v0.1.2...v0.1.3) · [Download v0.1.3](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.3)

- Proof (receipt or reference) required for bills, goal transfers, settlements and monthly reviews.
- Credit cards with limits, utilisation, due dates and Pay card; spend per person in All activity.
- Smooth gliding chart scrubber; Money date card fix.

## v0.1.2 — 2 October 2026
[Compare with v0.1.1](https://github.com/bfbanayoti/Beitna/compare/v0.1.1...v0.1.2) · [Download v0.1.2](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.2)

- Luxury Home with interactive charts; real Excel / CSV bank statement import.
- Settlements with date, method and proof; edit / delete transactions; credit-safe fils maths.
- Onboarding, daily backups, bills to Calendar, Face ID, offline home-screen app with the بيتنا icon.
- SF-style icons, sliding liquid-glass tab bar, refined "less AI" look.

## v0.1.1 — 2 October 2026
[Compare with v0.1.0](https://github.com/bfbanayoti/Beitna/compare/v0.1.0...v0.1.1) · [Download v0.1.1](https://github.com/bfbanayoti/Beitna/releases/tag/v0.1.1)

- Liquid glass iPhone redesign and fonts for Arabic and English.
- App encrypted behind a password lock (admin and guest); guests can't copy, export or print.

## v0.1.0 — 2 October 2026
- First version: couples' household finance app in Arabic and English.
