# Notices

Patro Clock is MIT licensed (see `LICENSE`). It is built on two MIT-licensed
upstreams, and this file records exactly what came from where — partly out of
courtesy, mostly because knowing which lines are load-bearing published data
and which are ordinary code matters if you intend to change any of it.

## Omarchy — the built-in clock plugin

Copyright (c) Basecamp. MIT licensed.
<https://github.com/basecamp/omarchy>

This plugin is a derivative of Omarchy's built-in `omarchy.clock` bar widget.
The hero-over-detail composition, the year-progress rail, the memento-mori bar,
the week-number gutter, the label format ring and the keyboard handling are all
upstream's work.

| File | Relationship to upstream |
|---|---|
| `Model.js` | Vendored verbatim, unmodified. |
| `BarWidget.qml` | Upstream, with settings persisted under this plugin's own id and `toggleCalendar` exposed over IPC. |
| `Panel.qml` | Upstream panel, roughly two thirds rewritten to add the Bikram Sambat view, the swipe switch and the layout work that keeps the two views identically sized. |

## Patro — the Bikram Sambat month-length table

Copyright (c) 2026 Yogesh Ojha. MIT licensed. Full text in
`docs/LICENSE.patro`.
<https://github.com/yogeshojha/patro>

`CalendarData.js` and `Bikram.js` are vendored **verbatim and unmodified**,
apart from an added attribution header.

This is deliberate, and worth understanding before touching either file.
Bikram Sambat month lengths are not derivable from a leap rule. A month ends
when the sun crosses into the next zodiac sign, so the lengths are *published*
each year by Nepal's Panchanga Nirnayak Samiti rather than computed. The only
way to get them right is to copy a correct table.

Patro's table is a merge of seven independently maintained implementations,
cross-checked against each other and, for years up to 2080 BS, against a printed
patro. It records its own confidence per year:

- **attested** — confirmed day by day against a published patro (through 2080)
- **published** — past the printed patro but within what the Samiti has issued (through 2083)
- **provisional** — nobody has determined these years yet (2084–2090)

Re-deriving this by hand would be a good way to introduce a silent
off-by-one-day error somewhere in the 2000–2090 range, which is why it is
vendored rather than reimplemented.

`BikramModel.js` — the panel's own model layer, mirroring `Model.js`'s shapes
for the BS side — is original to this plugin.

## What the tests do and do not check

`tests/bikram.test.js` verifies structural integrity (every year totals 365 or
366, every day round-trips to Gregorian and back, weekdays advance by exactly
one across all ~33,000 days, the grid is always six rows of seven) and pins the
table against dates published outside it: Nepali New Year, Maghe Sankranti and
1 Kartik for recent years.

It cannot catch an error that cancels out between two months inside one of those
spans — a day moved from Baisakh to Jestha leaves every anchor and every year
total intact. Fully pinning all 1,092 month lengths would need a second
independent copy of the table, which is what the upstream merge already is.
