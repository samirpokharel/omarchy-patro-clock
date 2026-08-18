// Bikram Sambat arithmetic and the panel's month grid.
//
// The month-length table is published data rather than something derivable from
// a leap rule, so the tests that matter are the ones that would catch a table
// that has been mis-transcribed: every year has to total 365 or 366, every day
// in the table has to survive a round trip to Gregorian and back, and the
// weekday has to advance by exactly one across all 33,000-odd of them. A single
// wrong number anywhere in the table fails at least one of those.

const { load, raw, test, assert, equal, report } = require("./harness")
const M = load()

// The two tests below are the ones that actually pin the *contents* of the
// month-length table. Everything else in this file is self-consistent with
// whatever table happens to be loaded — a round trip and a weekday walk both
// pass just as happily against a table with a wrong number in it, because the
// arithmetic and the data agree with each other by construction. These two do
// not: one checks the table against dates published outside it, the other
// checks each row against the total the generator recorded beside it.

test("Nepali New Year lands on its published Gregorian date", () => {
  // 1 Baisakh, as reported each year in Nepal. A single wrong month length
  // anywhere before one of these shifts it by a day and fails here.
  const newYears = [
    [2075, 2018, 4, 14],
    [2076, 2019, 4, 14],
    [2077, 2020, 4, 13],
    [2078, 2021, 4, 14],
    [2079, 2022, 4, 14],
    [2080, 2023, 4, 14],
    [2081, 2024, 4, 13],
    [2082, 2025, 4, 14],
    [2083, 2026, 4, 14]
  ]
  for (const [bs, year, month, day] of newYears) {
    equal(M.toGregorian(bs, 1, 1), { year, month, day }, `1 Baisakh ${bs}`)
  }
})

test("mid-year festivals land on their published Gregorian dates", () => {
  // A New Year anchor only pins the *total* of the year before it, so an error
  // that cancels out inside a year slips past. These sit part-way through, and
  // each pins the cumulative day count up to its own month.
  //
  // 1 Magh is Maghe Sankranti and 1 Kartik opens the month Tihar falls in; both
  // are reported every year, so they are known independently of this table.
  const magh = [
    [2075, 2019, 1, 15],
    [2076, 2020, 1, 15],
    [2077, 2021, 1, 14],
    [2078, 2022, 1, 15],
    [2079, 2023, 1, 15],
    [2080, 2024, 1, 15],
    [2081, 2025, 1, 14],
    [2082, 2026, 1, 15]
  ]
  for (const [bs, year, month, day] of magh) {
    equal(M.toGregorian(bs, 10, 1), { year, month, day }, `1 Magh ${bs}`)
  }

  const kartik = [
    [2079, 2022, 10, 18],
    [2080, 2023, 10, 18],
    [2081, 2024, 10, 17],
    [2082, 2025, 10, 18]
  ]
  for (const [bs, year, month, day] of kartik) {
    equal(M.toGregorian(bs, 7, 1), { year, month, day }, `1 Kartik ${bs}`)
  }

  // Honest limit: between them these anchors pin the cumulative day count at
  // months 1, 7 and 10 of each recent year, plus 1 Bhadau 2083 above. An error
  // that cancels out *between two months inside one of those spans* — say a day
  // moved from Baisakh to Jestha — leaves every anchor and every year total
  // intact and cannot be caught here. Pinning all 1,092 month lengths would
  // take a second independent copy of the table; CalendarData.js is already a
  // merge of seven of them, and NOTICE.md records which.
})

test("each row totals the number recorded in its own comment", () => {
  // CalendarData.js is generated, and every row carries "// <year> <days>
  // <confidence>". The comment is written independently of the array, so
  // comparing the two catches a digit that has been transcribed wrongly even
  // when the result is still a plausible 365- or 366-day year.
  const rows = raw("CalendarData.js").match(/^\s*\[[^\]]*\],\s*\/\/\s*\d{4}\s+\d{3}\s+\w+$/gm) || []
  assert(rows.length === M.lastYear() - M.firstYear() + 1,
    `found ${rows.length} annotated rows, expected ${M.lastYear() - M.firstYear() + 1}`)

  for (const row of rows) {
    const lengths = row.slice(row.indexOf("[") + 1, row.indexOf("]")).split(",").map(Number)
    const [, year, recorded] = row.match(/\/\/\s*(\d{4})\s+(\d{3})/).map(Number)
    const summed = lengths.reduce((a, b) => a + b, 0)
    if (summed !== recorded) {
      throw new Error(`${year} BS: the row sums to ${summed} but its comment says ${recorded}`)
    }
    equal(lengths.length, 12, `${year} BS should have 12 months`)
  }
})

test("today converts against a known anchor", () => {
  // 1 Bhadau 2083 fell on Monday 17 August 2026.
  equal(M.fromGregorian(2026, 8, 17), { year: 2083, month: 5, day: 1 }, "2026-08-17")
  equal(M.fromGregorian(2026, 8, 18), { year: 2083, month: 5, day: 2 }, "2026-08-18")
  equal(M.weekdayOf(2083, 5, 1), 1, "1 Bhadau 2083 is a Monday")
  equal(M.toGregorian(2083, 5, 1), { year: 2026, month: 8, day: 17 }, "back again")
})

test("the epoch itself is 14 April 1943", () => {
  equal(M.toGregorian(2000, 1, 1), { year: 1943, month: 4, day: 14 }, "1 Baisakh 2000")
})

test("every year in the table totals 365 or 366 days", () => {
  for (let year = M.firstYear(); year <= M.lastYear(); year++) {
    const total = M.daysInYear(year)
    assert(total === 365 || total === 366, `${year} BS totals ${total}`)
  }
})

test("month lengths stay within 29..32 days", () => {
  for (let year = M.firstYear(); year <= M.lastYear(); year++) {
    for (let month = 1; month <= 12; month++) {
      const length = M.monthLength(year, month)
      assert(length >= 29 && length <= 32, `${year}-${month} is ${length} days`)
    }
  }
})

test("every day in the table round-trips through Gregorian", () => {
  let days = 0
  for (let year = M.firstYear(); year <= M.lastYear(); year++) {
    for (let month = 1; month <= 12; month++) {
      for (let day = 1; day <= M.monthLength(year, month); day++) {
        const g = M.toGregorian(year, month, day)
        const back = M.fromGregorian(g.year, g.month, g.day)
        if (back.year !== year || back.month !== month || back.day !== day) {
          throw new Error(`${year}-${month}-${day} came back as ${JSON.stringify(back)}`)
        }
        days++
      }
    }
  }
  assert(days > 33000, `only walked ${days} days`)
})

test("weekdays advance by exactly one across the whole table", () => {
  const last = M.dayIndex(M.lastYear(), 12, M.monthLength(M.lastYear(), 12))
  for (let i = 1; i <= last; i++) {
    const a = M.fromDayIndex(i - 1)
    const b = M.fromDayIndex(i)
    const expected = (M.weekdayOf(a.year, a.month, a.day) + 1) % 7
    const actual = M.weekdayOf(b.year, b.month, b.day)
    if (expected !== actual) {
      throw new Error(`weekday jumps at ${b.year}-${b.month}-${b.day}`)
    }
  }
})

test("out-of-table dates are refused rather than guessed", () => {
  equal(M.monthGrid(M.firstYear() - 1, 1, 0, ""), [], "before the table")
  assert(!M.supportsYear(M.firstYear() - 1), "year below the table")
  assert(!M.supportsYear(M.lastYear() + 1), "year above the table")
  assert(M.todayParts(new Date(1900, 0, 1)) === null, "a date before the epoch has no BS form")
})

test("the grid is always six rows of seven", () => {
  for (let year = M.firstYear(); year <= M.lastYear(); year++) {
    for (let month = 1; month <= 12; month++) {
      const weeks = M.monthGrid(year, month, 0, "")
      if (weeks.length !== 6) throw new Error(`${year}-${month} produced ${weeks.length} rows`)
      for (const week of weeks) {
        if (week.days.length !== 7) throw new Error(`${year}-${month} has a short row`)
      }
    }
  }
})

test("the grid never emits a null cell", () => {
  // The QML delegate reads fields off every cell unguarded, so a null here
  // would be a runtime error in the panel rather than a blank square.
  for (const [year, month] of [[M.firstYear(), 1], [M.lastYear(), 12], [2083, 5]]) {
    for (const week of M.monthGrid(year, month, 0, "")) {
      for (const day of week.days) {
        assert(day !== null && typeof day === "object", `${year}-${month} emitted a null cell`)
        assert(typeof day.outOfRange === "boolean", "cell is missing outOfRange")
      }
    }
  }
})

test("Bhadau 2083 lays out as the printed patro does", () => {
  const weeks = M.monthGrid(2083, 5, 0, "2083-05-02")
  const first = weeks[0].days

  equal(first[0].day, 31, "the row opens on 31 Saun")
  assert(!first[0].inMonth, "31 Saun is outside the month")
  equal(first[1].day, 1, "1 Bhadau sits under Monday")
  assert(first[1].inMonth, "1 Bhadau is inside the month")
  assert(first[2].today, "2 Bhadau is marked as today")
  assert(first[6].weekend, "Saturday is the weekend")
  assert(!first[0].weekend, "Sunday is not")
  equal(M.monthLength(2083, 5), 31, "Bhadau 2083 is 31 days")
})

test("stepping clamps at the ends of the table instead of running off", () => {
  equal(M.stepMonth(M.firstYear(), 1, -1), { year: M.firstYear(), month: 1 }, "clamps low")
  equal(M.stepMonth(M.lastYear(), 12, 1), { year: M.lastYear(), month: 12 }, "clamps high")
  assert(!M.canStepMonth(M.firstYear(), 1, -1), "no step available at the start")
  assert(!M.canStepMonth(M.lastYear(), 12, 1), "no step available at the end")
  assert(M.canStepMonth(2083, 5, 1), "a step is available mid-table")
})

test("year progress runs 0..100 and tracks the ordinal day", () => {
  equal(M.dayOfYear(2083, 1, 1), 1, "1 Baisakh is day 1")
  equal(M.yearProgressPercent(2083, 1, 1), 0, "the year opens at 0%")
  const last = M.monthLength(2083, 12)
  assert(M.yearProgressPercent(2083, 12, last) >= 99, "the year closes near 100%")
  equal(M.dayOfYear(2083, 12, last), M.daysInYear(2083), "the last day is the whole year")
})

test("Devanagari numerals convert digit by digit", () => {
  equal(M.devanagari(2083), "२०८३", "year")
  equal(M.devanagari(0), "०", "zero")
  equal(M.devanagari("31%"), "३१%", "non-digits pass through")
})

test("labels read the way a wall patro prints them", () => {
  equal(M.monthName(5), "भदौ", "Bhadau in Devanagari")
  equal(M.monthNameLatin(5), "Bhadau", "and romanised")
  equal(M.monthNameLatin(4), "Saun", "colloquial, not Shrawan")
  equal(M.weekdayShort(2), "मङ्गल", "Tuesday, short")
  equal(M.heroLabel(2083, 5, 2), "भदौ २", "hero mirrors 'August 18'")
  equal(M.heroCaption(2083, 5, 2), "मङ्गलबार  ·  18 Aug 2026", "caption names the Gregorian day")
  equal(M.monthLabel(2083, 5), "भदौ २०८३", "month rail")
})

test("each calendar names the other's span for the same stretch of days", () => {
  equal(M.gregorianSpan(2083, 5), "Aug / Sep 2026", "a BS month straddles two Gregorian ones")
  equal(M.latinSpan(2026, 8), "Saun / Bhadau 2083", "and the other way round")
  equal(M.latinDate(2026, 8, 18), "2 Bhadau 2083", "a single day, romanised")
})

test("spans that cross a new year name both years", () => {
  equal(M.latinSpan(2027, 4), "Chait 2083 / Baisakh 2084", "Gregorian April crosses the BS new year")
  assert(M.gregorianSpan(2083, 9).indexOf("/") !== -1, "Poush spans two Gregorian months")
})

test("February is measured correctly in leap and common years", () => {
  equal(M.latinSpan(2024, 2), "Magh / Falgun 2080", "29-day February")
  equal(M.latinSpan(2026, 2), "Magh / Falgun 2082", "28-day February")
})

test("week numbering counts the year in sevens", () => {
  equal(M.weekOfYear(2083, 1, 1), 1, "the first day is week 1")
  equal(M.weekOfYear(2083, 1, 7), 1, "so is the seventh")
  equal(M.weekOfYear(2083, 1, 8), 2, "the eighth starts week 2")
})

report()
