// Loads the plugin's QML JavaScript modules under plain node.
//
// QML's `.pragma library` and `.import` lines are not valid JavaScript, so they
// are stripped and the dependency graph is wired up by hand instead. Everything
// under test is deliberately free of Qt types for exactly this reason — the
// calendar arithmetic is the part worth testing, and it should not need a
// running shell to exercise.

const fs = require("fs")
const vm = require("vm")
const path = require("path")

const ROOT = path.join(__dirname, "..")

function source(file) {
  return fs
    .readFileSync(path.join(ROOT, file), "utf8")
    .replace(/^\.pragma library.*$/gm, "")
    .replace(/^\.import.*$/gm, "")
}

function load() {
  const context = { console, Date, Math, JSON, String, Number, isFinite, parseInt }
  vm.createContext(context)

  // CalendarData exposes bare vars; Bikram.js expects them behind `Data`.
  vm.runInContext(
    source("CalendarData.js") +
      "\n;var Data = { FIRST_YEAR, LAST_YEAR, ATTESTED_THROUGH, PUBLISHED_THROUGH, ANCHOR_AD, MONTH_LENGTHS };",
    context)

  // Likewise BikramModel.js expects Bikram.js behind `Bikram`.
  vm.runInContext(
    source("Bikram.js") +
      "\n;var Bikram = { today, supportsYear, confidence, monthLength, isValid, dayIndex," +
      " fromDayIndex, toGregorian, fromGregorian, weekdayOf, addMonths, firstYear, lastYear };",
    context)

  vm.runInContext(source("BikramModel.js"), context)
  return context
}

// ---- A very small test runner, so the suite has no dependencies at all.

const failures = []
let checks = 0
let currentTest = "(none)"

function test(name, fn) {
  currentTest = name
  try {
    fn()
    process.stdout.write(`  ok   ${name}\n`)
  } catch (error) {
    process.stdout.write(`  FAIL ${name}\n         ${error.message}\n`)
    failures.push(name)
  }
}

function assert(condition, message) {
  checks++
  if (!condition) throw new Error(message || "assertion failed")
}

function equal(actual, expected, message) {
  checks++
  const a = JSON.stringify(actual)
  const b = JSON.stringify(expected)
  if (a !== b) throw new Error(`${message || "not equal"}\n         expected ${b}\n         actual   ${a}`)
}

function report() {
  process.stdout.write(`\n${checks} checks, ${failures.length} failed\n`)
  if (failures.length) process.exit(1)
}

function raw(file) {
  return fs.readFileSync(path.join(ROOT, file), "utf8")
}

module.exports = { load, raw, test, assert, equal, report }
