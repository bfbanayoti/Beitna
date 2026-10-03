# Beitna · بيتنا — Changelog

Each version is a GitHub Release (tag `vX.Y`) with a downloadable copy of the files exactly as they were.
The live app always runs the latest version. Dates are when the version was published (Amman time).

| Version | Date | Highlights |
|---|---|---|
| [v1.8](#v18--3-october-2026) | 3 Oct 2026 | Username + password logins, Sign in / Sign up, Jordanian names, "Beit …" home name |
| [v1.7](#v17--3-october-2026) | 3 Oct 2026 | Subscription-only access, payment screen with Apple Pay / Google Pay, owner walkthrough |
| [v1.6](#v16--3-october-2026) | 3 Oct 2026 | Subscriptions (2 / 4 JOD), payment & refund policy, name your home |
| [v1.5](#v15--3-october-2026) | 3 Oct 2026 | Sync between both partners' phones |
| [v1.4](#v14--2-october-2026) | 2 Oct 2026 | Beitna Analytics tracking, privacy policy |
| [v1.3](#v13--2-october-2026) | 2 Oct 2026 | Proof of payment, credit cards, spend per person, smooth charts |
| [v1.2](#v12--2-october-2026) | 2 Oct 2026 | Luxury Home, Excel/statement import, settlements, Face ID, home-screen app |
| [v1.1](#v11--2-october-2026) | 2 Oct 2026 | Liquid glass iPhone redesign, encrypted password lock, guest restrictions |
| [v1.0](#v10--2-october-2026) | 2 Oct 2026 | First version of the app |

## v1.8 — 3 October 2026
- Login is now **username + password**; each login unlocks its own sealed key, carrying the person's name and partner.
- Login screen: **Sign in / Sign up** tabs (sign-up is by invitation during testing; nothing is saved).
- Logins: Barsoum Banayoti (admin), Ahmad Al-Khatib + Sara (guest), Zaid Al-Rawashdeh + Lina (test user).
- "**Beit Banayoti**" above the greeting (semibold); the top bar always says Beitna.
- Sign-in goes straight into the app (no Face ID step; sample household on new phones).
- Fixes: Arabic spelling برسوم, sign-up email field, link-style buttons.

## v1.7 — 3 October 2026
- Subscription required after sign-up; no free activation. Admin and guest logins count as subscribed.
- Payment screen: order summary, Apple Pay and Google Pay, card form area, Pay button.
- Owner-only "Walk through sign-up" with a scratch household (nothing saved or charged).
- Sign in for re-installs, partner linking with a code (Individual plan), tab bar hidden on full-screen steps, last tab "Me".
- Feedback: darker "+" button, income quick-entry example.

## v1.6 — 3 October 2026
- Subscriptions: Individual 2 JOD / month, Couple 4 JOD / month; plan step in the sign-up form.
- Public payment & refund policy (Arabic / English).
- Name your home: "Beit …" with a Jordanian example (Al-Majali).

## v1.5 — 3 October 2026
- Sync between both phones through Supabase: accounts, shared household, invite codes, live three-way merge.
- Hidden-from-partner accounts stored separately and readable only by their owner.

## v1.4 — 2 October 2026
- Beitna Analytics: opens, wrong passwords, sessions and screen/button activity (no amounts or typed text; IP not stored).
- iOS version fix for iOS 26+; privacy policy page.

## v1.3 — 2 October 2026
- Proof (receipt or reference) required for bills, goal transfers, settlements and monthly reviews.
- Credit cards with limits, utilisation, due dates and Pay card; spend per person in All activity.
- Smooth gliding chart scrubber; Money date card fix.

## v1.2 — 2 October 2026
- Luxury Home with interactive charts; real Excel / CSV bank statement import.
- Settlements with date, method and proof; edit / delete transactions; credit-safe fils maths.
- Onboarding, daily backups, bills to Calendar, Face ID, offline home-screen app with the بيتنا icon.
- SF-style icons, sliding liquid-glass tab bar, refined "less AI" look.

## v1.1 — 2 October 2026
- Liquid glass iPhone redesign and fonts for Arabic and English.
- App encrypted behind a password lock (admin and guest); guests can't copy, export or print.

## v1.0 — 2 October 2026
- First version: couples' household finance app in Arabic and English.
