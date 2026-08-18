import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Bikram.js" as Bikram
import "BikramModel.js" as Bik

// Derived from Omarchy's built-in clock panel (omarchy.clock), MIT licence —
// see NOTICE.md. The composition, the year rail and the memento-mori bar are
// upstream's; the Bikram Sambat view, the swipe switch and the metric anchors
// that keep the two views the same size are the additions here.
//
// The calendar popup: a month grid with week numbers down a gutter, built to
// sit beside the weather panel — same hero-over-detail composition, same
// spacing scale, same small-caps labels.
//
// It draws the same month in either of two calendars, Gregorian or Bikram
// Sambat, and a two-finger horizontal swipe crosses between them. Both are laid
// out to exactly the same height and width, so the switch never resizes the
// popup: every line whose text can change script takes its height from a hidden
// Latin sample of its size class rather than from its own content. See the
// `metrics` block below — that is the whole trick.
//
// The grid is a read-out rather than a picker: today is the only marked day,
// and the only thing that moves is which month is on screen — chevrons, the
// scroll wheel, and the arrow keys all step it.
//
// BarWidget.qml owns the bar label and hands this panel the button to anchor
// against.
Panel {
  id: root
  moduleName: "samirpokharel.patro-clock"
  ipcTarget: "samirpokharel.patro-clock"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the
  //      highlight rolls over without the panel being reopened.
  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  // The month on screen. Stepping moves this and nothing else: the grid is
  // a read-out, not a picker, so there is no per-day cursor to keep in sync.
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property date viewDate: new Date(viewYear, viewMonth, 1)

  // ---- Which calendar is on screen. Persisted, so the panel opens on the one
  //      you last used rather than resetting to Gregorian every time.
  //
  //      Bikram Sambat month lengths are published rather than derived, so the
  //      BS side only exists inside the table CalendarData.js carries. Outside
  //      it the swipe still switches, but there is no month to draw — hence the
  //      supported/unsupported guards below rather than an assumption that a BS
  //      date always exists.
  //
  //      The value is held locally as well as in shell.json, and the local copy
  //      wins while it is set. Two reasons, both about the switch feeling
  //      instant:
  //
  //        Writing shell.json makes the bar re-inject settings, which
  //        momentarily hands the panel an empty set — enough for `bikram` to
  //        snap back to the default and the whole panel to redraw twice per
  //        switch. Reading the local value first rides straight over that.
  //
  //        It also decouples the gesture from disk. The write is debounced
  //        below, so a flurry of swipes repaints once each but writes once at
  //        the end, instead of thrashing the config file mid-animation.
  property string calendarLocal: ""
  readonly property string calendarSystem: calendarLocal !== ""
    ? calendarLocal
    : String(setting("calendarSystem", "gregorian"))
  readonly property bool bikram: calendarSystem === "bikram"

  // Today in BS, or null past either end of the table.
  readonly property var bikramToday: Bik.todayParts(today)
  readonly property bool bikramSupported: bikramToday !== null
  readonly property string bikramTodayKey: bikramSupported
    ? Bik.dateKey(bikramToday.year, bikramToday.month, bikramToday.day)
    : ""

  // The BS month on screen, tracked apart from the Gregorian pair so switching
  // views puts you back where you were instead of snapping to today. Bindings
  // rather than constants, so they follow today until something steps them —
  // the same trick viewYear/viewMonth use above.
  property int bikramViewYear: bikramSupported ? bikramToday.year : Bikram.firstYear()
  property int bikramViewMonth: bikramSupported ? bikramToday.month : 1

  readonly property bool viewingCurrentMonth: bikram
    ? (bikramSupported && bikramViewYear === bikramToday.year && bikramViewMonth === bikramToday.month)
    : (viewYear === today.getFullYear() && viewMonth === today.getMonth())

  // ---- Type. JetBrains Mono has no Devanagari, so the Nepali view asks for
  //      Noto Sans Devanagari by name. A single family rather than a fallback
  //      list: every string this switches is known to be one script or the
  //      other, and Qt still falls back per glyph inside a family. If the font
  //      is missing, Qt substitutes rather than failing.
  readonly property string devanagariFontFamily: "Noto Sans Devanagari"
  readonly property string calendarFontFamily: root.bikram
    ? root.devanagariFontFamily
    : root.contentFontFamily

  // Devanagari runs taller than Latin at the same pixel size, so the hero
  // steps down in Nepali rather than being allowed to grow the box. Tuned so
  // "भदौ २" reads at the same visual weight as "August 18" while still fitting
  // inside the Latin line height.
  readonly property int heroFontSize: 52
  readonly property int heroFontSizeNepali: 44
  readonly property int activeHeroFontSize: root.bikram ? root.heroFontSizeNepali : root.heroFontSize

  // Pinned to today, not to the month being browsed — stepping through the
  // calendar does not change how much of the year is gone.
  readonly property real yearDone: bikram
    ? (bikramSupported ? Bik.yearProgress(bikramToday.year, bikramToday.month, bikramToday.day) : 0)
    : Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: bikram
    ? (bikramSupported ? Bik.yearProgressPercent(bikramToday.year, bikramToday.month, bikramToday.day) : 0)
    : Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  // Memento mori, for anyone who goes looking: double-tapping the year bar
  // asks for a birth year and a life expectancy, and a second bar tracks one
  // against the other. A birth year rather than an age, so it keeps counting
  // on its own. Without one the bar stays hidden.
  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
  property bool editingLife: false

  // Unset falls through to the locale's own first day, so a fresh install
  // starts out matching the rest of the desktop rather than a hardcoded
  // convention. Clicking the grid's "W" heading writes the choice back to
  // shell.json.
  //
  // A Nepali patro always starts the week on Sunday and treats Saturday as the
  // holiday, so the Nepali view pins Sunday and puts its own toggle beyond
  // reach rather than offering a choice the calendar does not have.
  readonly property int gregorianWeekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
  readonly property int weekStart: bikram ? 0 : gregorianWeekStart
  readonly property string nextWeekStartLabel: Qt.locale().dayName(Model.toggledWeekStart(gregorianWeekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: bikram
    ? Bik.monthGrid(bikramViewYear, bikramViewMonth, weekStart, bikramTodayKey)
    : Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)


  // Guarded so the widget renders before the bar is injected (the bar-widget
  // contract instantiates it bare).
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  function open() {
    refresh()
    root.controller.show()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    root.flushCalendar()
    setCenterHoverRevealSuppressed(false)
    // Dismissing the panel mid-edit would otherwise leave the inputs up,
    // waiting behind a closed popup for the next time it opens.
    if (root.editingLife) root.cancelEditingLife()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still
  // holding must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  // Both calendars are sent home, not just the one on screen: the other view
  // should not be sitting on last March the next time it is opened.
  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
    if (root.bikramSupported) {
      root.bikramViewYear = root.bikramToday.year
      root.bikramViewMonth = root.bikramToday.month
    }
  }

  function moveMonth(delta) {
    if (root.bikram) {
      // Clamps at the ends of the published table rather than running off it,
      // so the chevrons simply stop instead of emptying the grid.
      var target = Bik.stepMonth(root.bikramViewYear, root.bikramViewMonth, delta)
      root.bikramViewYear = target.year
      root.bikramViewMonth = target.month
      return
    }
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value. With no
  // writable entry (the widget is not in the layout) it stays a session-only
  // preference rather than doing nothing. The host widget builds its own
  // entry when the label format is cycled, so it has to be kept in step or
  // it would write this key straight back out from a stale copy.
  // The id this plugin is listed under in shell.json. For a plugin installed
  // under its own name that is just moduleName, so this is normally a no-op.
  //
  // It is a separate property because it stops being a no-op the moment someone
  // runs `omarchy plugin clone` on this plugin: the clone keeps moduleName as a
  // stable IPC target while its layout entry carries the clone's own id, and
  // Bar.entrySettings strips `id` before handing settings over, so the panel
  // cannot read the real one back out. shell.qml's updateEntryInline then scans
  // the layout for a matching id, finds none, and returns **without writing and
  // without error** — every preference would apply for the session and be
  // forgotten on restart. A clone only has to set this one line to stay sane.
  readonly property string settingsEntryId: root.moduleName

  function persistSettings(values) {
    var entry = { id: root.settingsEntryId }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.settingsEntryId, entry)
  }

  function setWeekStart(day) {
    // Reads against the Gregorian preference, not the effective start, or the
    // Nepali view's pinned Sunday would look like a change worth writing.
    var next = Model.normalizedWeekStart(day, root.gregorianWeekStart)
    if (next === root.gregorianWeekStart) return
    persistSettings({ weekStartDay: Model.weekStartSettingName(next) })
  }

  // ---- Switching between the two calendars.

  // direction is -1 or 1 and only sets which side the new calendar slides in
  // from, so a swipe left and a swipe right feel like opposite motions.
  function setCalendar(system, direction) {
    var next = String(system) === "bikram" ? "bikram" : "gregorian"
    if (next === root.calendarSystem) return

    root.switchDirection = direction === undefined ? 1 : (direction < 0 ? -1 : 1)
    // Applied locally and painted this frame; shell.json catches up when the
    // gesture has settled.
    root.calendarLocal = next
    calendarPersist.restart()
    // Switching calendar lands on the current month rather than wherever the
    // other view was left — it is a change of calendar, not of place.
    root.goToToday()
    switchTransition.restart()
  }

  Timer {
    id: calendarPersist
    // Long enough to outlast a burst of swipes, short enough that closing the
    // panel straight after a switch still saves it.
    interval: 900
    onTriggered: root.persistSettings({ calendarSystem: root.calendarLocal })
  }

  function toggleCalendar(direction) {
    root.setCalendar(root.bikram ? "gregorian" : "bikram", direction)
  }

  // Closing must not drop a switch that is still sitting in the debounce.
  function flushCalendar() {
    if (!calendarPersist.running) return
    calendarPersist.stop()
    root.persistSettings({ calendarSystem: root.calendarLocal })
  }

  // Which side the incoming calendar slides in from.
  property int switchDirection: 1

  // Only the arriving view is animated. The one it replaced is already gone by
  // the time the state has changed, and keeping a copy alive purely to cross
  // fade against would mean rendering the whole grid twice for a fifth of a
  // second — the slide and fade-up read as a transition on their own.
  ParallelAnimation {
    id: switchTransition

    NumberAnimation {
      target: contentShift
      property: "x"
      from: root.switchDirection * Style.space(30)
      to: 0
      duration: 260
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: calendarColumn
      property: "opacity"
      from: 0.2
      to: 1
      duration: 210
      easing.type: Easing.OutCubic
    }
  }

  // ---- Switching calendars with a two-finger horizontal swipe.
  //
  // A touchpad reports one swipe as a long stream of small deltas, so a naive
  // handler would flip the calendar back and forth a dozen times per gesture.
  // This accumulates sideways motion until a full step's worth has gone by,
  // fires once, then refuses to fire again until the gesture has clearly
  // ended. The idle timer clears a part-finished swipe so a slow nudge does
  // not add itself to the next one minutes later.
  //
  // Direction is deliberately ignored: there are exactly two calendars, so
  // mapping left and right separately would make one of them a dead end.
  // How much sideways travel counts as a swipe. The default is about one wheel
  // notch: low enough that a short swipe lands first try, and drift during a
  // vertical scroll is already excluded by only ever treating the dominant axis
  // as a swipe. Configurable because touchpads differ wildly in how much delta
  // they report per gesture — raise it if the calendar flips too eagerly, lower
  // it if a full swipe does nothing. Floored so it can never reach 0 and fire
  // on every stray event.
  property real swipeTravel: 0
  readonly property real swipeStep: Math.max(20, Number(setting("swipeThreshold", 120)) || 120)

  function handleCalendarSwipe(dx) {
    // Mid-cooldown the rest of the swipe is swallowed rather than queued.
    if (swipeCooldown.running) return

    root.swipeTravel += dx
    if (Math.abs(root.swipeTravel) < root.swipeStep) {
      swipeIdle.restart()
      return
    }

    var direction = root.swipeTravel < 0 ? -1 : 1
    root.swipeTravel = 0
    swipeIdle.stop()
    swipeCooldown.restart()
    root.toggleCalendar(direction)
  }

  Timer {
    id: swipeIdle
    interval: 250
    onTriggered: root.swipeTravel = 0
  }

  Timer {
    id: swipeCooldown
    // Just past the transition, so a second swipe is accepted the moment the
    // first has finished animating rather than after a dead pause.
    interval: 300
    onTriggered: root.swipeTravel = 0
  }

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll()
      bornField.forceActiveFocus()
    })
  }

  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  // Shared by both fields: Tab hops to the other one, Enter commits the pair,
  // Escape drops the lot.
  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  // Double-tapping the life bar puts it away again. The expectancy stays in
  // the config so setting a birth year again brings your own number back
  // rather than the default.
  function clearLife() {
    if (root.birthYear <= 0) return
    persistSettings({ birthYear: 0 })
  }

  function commitLife() {
    var born = Model.parseBirthYear(bornField.text, today.getFullYear())
    var span = Model.parseLifeExpectancy(expectancyField.text)
    if (born !== root.birthYear || span !== root.lifeExpectancy)
      persistSettings({ birthYear: born, lifeExpectancy: span })
    cancelEditingLife()
  }

  // Inert in the Nepali view, where the week start is not a preference. Reading
  // root.weekStart here would otherwise see the pinned Sunday and quietly
  // rewrite the Gregorian setting to Monday from a view that never showed it.
  function toggleWeekStart() {
    if (root.bikram) return
    setWeekStart(Model.toggledWeekStart(root.gregorianWeekStart))
  }

  // Locale short day names, trimmed of the trailing period some locales
  // carry ("man." -> "MAN") so the header row stays a clean band of caps.
  function weekdayLabel(weekday) {
    // Devanagari has no case, so the Nepali header band is left as written
    // rather than run through toUpperCase.
    if (root.bikram) return Bik.weekdayShort(weekday)
    return String(Qt.locale().dayName(weekday, Locale.ShortFormat)).replace(/\.$/, "").toUpperCase()
  }

  // ---- Read-outs, each one the same sentence in whichever calendar is up.

  // The hero: month then day, no year, because the year sits on the rail below.
  readonly property string heroText: bikram
    ? (bikramSupported ? Bik.heroLabel(bikramToday.year, bikramToday.month, bikramToday.day) : "—")
    : Qt.formatDate(root.today, "MMMM d")

  // Both views carry a caption, and both carry a sub-rail under the month, so
  // the panel is the same shape either way and a swipe changes what it says
  // rather than how big it is. The content is not filler: each view sets its
  // own date large and names the other calendar small, which is exactly the
  // pairing you want when you are reading one and thinking in the other.
  readonly property string heroCaption: bikram
    ? (bikramSupported ? Bik.heroCaption(bikramToday.year, bikramToday.month, bikramToday.day) : "")
    : Qt.formatDate(root.today, "dddd") + "  ·  "
      + Bik.latinDate(today.getFullYear(), today.getMonth() + 1, today.getDate())

  readonly property string yearText: bikram
    ? (bikramSupported ? Bik.devanagari(bikramToday.year) : "—")
    : String(root.today.getFullYear())

  readonly property string yearPercentText: bikram
    ? Bik.devanagari(root.yearDonePercent) + "%"
    : root.yearDonePercent + "%"

  readonly property string monthNavText: bikram
    ? Bik.monthLabel(bikramViewYear, bikramViewMonth)
    : Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()

  // The months of the other calendar that the shown month straddles. A month
  // in either system always spans two in the other, so this rail says which.
  readonly property string monthNavSubText: bikram
    ? Bik.gregorianSpan(bikramViewYear, bikramViewMonth).toUpperCase()
    : Bik.latinSpan(viewYear, viewMonth + 1).toUpperCase()

  function dayCellText(cell) {
    if (!cell) return ""
    if (root.bikram) return cell.outOfRange ? "" : Bik.devanagari(cell.day)
    return String(cell.day)
  }

  function weekCellText(week) {
    if (root.bikram) return week > 0 ? Bik.devanagari(week) : ""
    return String(week)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(calendarColumn.implicitHeight)

    // ---- Metric anchors. Every line whose text can change script takes its
    //      height from a hidden Latin sample of the same size class rather
    //      than from its own content, so a Devanagari line occupies exactly
    //      the height its Latin counterpart would. That is what keeps the
    //      popup from resizing when you swipe between calendars — the layout
    //      is identical by construction, not by having been measured once.
    //
    //      Invisible items are still laid out, so implicitHeight is live here.
    Item {
      id: metrics
      visible: false

      Text {
        id: heroMetric
        text: "August 18"
        font.family: root.contentFontFamily
        font.pixelSize: root.heroFontSize
        font.bold: true
      }

      Text {
        id: smallMetric
        text: "Wednesday  ·  28 Mangsir 2083"
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        id: bodyMetric
        text: "SEPTEMBER 2026"
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        id: captionMetric
        text: "MANGSIR / POUSH 2083"
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLife
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
        else if (t === "n" || t === "N") root.toggleCalendar()
      }

      // ---- Wheel for the whole panel: sideways switches calendar, vertical
      //      steps the month.
      //
      // A MouseArea rather than a WheelHandler. WheelHandler gates *delivery*
      // on its `orientation` — Qt drops the event before onWheel runs unless
      // that axis is non-zero — so covering both axes took two handlers, and a
      // touchpad swipe that is not cleanly axis-aligned could fall between
      // them. MouseArea.onWheel sees the raw event with both axes intact.
      //
      // acceptedButtons: Qt.NoButton means this reads the wheel and nothing
      // else, so clicks and taps still reach the hero, the year rail, the W
      // heading and the chevrons underneath. It sits above the content (z: 1)
      // so the wheel reaches it first; the grid keeps its own WheelHandler as a
      // fallback, which this shadows for vertical scrolls by accepting them.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: 1

        onWheel: function(wheel) {
          var dx = wheel.angleDelta.x
          var dy = wheel.angleDelta.y
          // A touchpad reporting smooth scrolling can leave angleDelta empty
          // and fill pixelDelta instead. One wheel notch is 120 angle units to
          // roughly 15 pixels, so 8 converts one to the other.
          if (dx === 0 && dy === 0) {
            dx = wheel.pixelDelta.x * 8
            dy = wheel.pixelDelta.y * 8
          }
          if (Math.abs(dx) > Math.abs(dy)) root.handleCalendarSwipe(dx)
          else if (dy !== 0) root.moveMonth(dy > 0 ? -1 : 1)
        }
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        contentWidth: calendarColumn.width
        contentHeight: calendarColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: calendarColumn
          // Never narrower than the grid. The popup width is capped to what
          // the screen allows, and a fixed seven-column grid would otherwise
          // lose its last days off the edge instead of scrolling.
          width: Math.max(calendarScroll.width, gridColumn.width)
          spacing: Style.space(8)

          // A transform, not an x binding: this has to move the content without
          // touching the Flickable's idea of how wide its content is.
          transform: Translate { id: contentShift }


          // ---- Hero: today, centered. Once the view has stepped back
          //      it is also the way home — clicking the date you are
          //      looking for beats hunting for a reset button.
          Item {
            width: parent.width
            height: heroBlock.height

            Column {
              id: heroBlock
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(2)

              Row {
                id: heroRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(22)

                Text {
                  // Baseline-aligned, not center-aligned: "July 26" carries a
                  // descender, so centering the two boxes leaves the icon
                  // sitting visibly low against the digits.
                  anchors.baseline: heroDate.baseline
                  text: "󰃭"
                  color: heroMouse.containsMouse
                    ? Style.hoverStateColor(root.contentForeground, Color.accent)
                    : root.contentForeground
                  // Deliberately not the calendar font list: this is a Nerd
                  // Font glyph, and Noto Devanagari has nothing to draw for it.
                  font.family: root.contentFontFamily
                  // Decorative, and deliberately outside the Style.font.*
                  // scale. Sized so the glyph reads at the cap height of the
                  // date beside it rather than towering over it.
                  font.pixelSize: 48
                }

                Text {
                  id: heroDate
                  anchors.verticalCenter: parent.verticalCenter
                  // Pinned to the Latin metric, so the taller Devanagari
                  // glyphs cannot push the hero row open.
                  height: heroMetric.implicitHeight
                  verticalAlignment: Text.AlignVCenter
                  text: root.heroText
                  color: heroMouse.containsMouse
                    ? Style.hoverStateColor(root.contentForeground, Color.accent)
                    : root.contentForeground
                  font.family: root.calendarFontFamily
                  font.pixelSize: root.activeHeroFontSize
                  font.bold: true
                }
              }

              Text {
                id: heroCaptionLabel
                anchors.horizontalCenter: parent.horizontalCenter
                height: smallMetric.implicitHeight
                verticalAlignment: Text.AlignVCenter
                text: root.heroCaption
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.calendarFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 0.5
              }
            }

            MouseArea {
              id: heroMouse
              x: heroBlock.x + heroRow.x
              y: heroBlock.y + heroRow.y
              width: heroRow.width
              height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: "Back to today"
                fontFamily: root.contentFontFamily
              }
            }
          }

          // ---- Year progress, doubling as the rule under the hero:
          //      a plain hairline said nothing, and whole days done
          //      over days in the year says the same thing louder.
          Item {
            width: parent.width
            height: yearBlock.y + yearBlock.height

            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              // Measured off the Latin sample rather than yearLabel itself, so
              // "२०८३" cannot make the rail a pixel taller than "2026".
              height: Math.max(smallMetric.implicitHeight, Style.space(10))

              TapHandler {
                enabled: !root.editingLife
                onDoubleTapped: root.startEditingLife()
              }

              Row {
                visible: root.editingLife
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "BORN"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: bornField
                  width: Style.space(70)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "year"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly

                  Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.verticalCenterOffset: 0
                  leftPadding: Style.space(6)
                  text: "LIVE TO"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: expectancyField
                  width: Style.space(60)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "90"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly

                  Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
                }
              }

              Text {
                id: yearLabel
                visible: !root.editingLife
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.yearText
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.calendarFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: yearPercent
                visible: !root.editingLife
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.yearPercentText
                color: root.contentForeground
                font.family: root.calendarFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                id: yearTrack
                visible: !root.editingLife
                anchors.left: yearLabel.right
                anchors.right: yearPercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.yearDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Color.accent)

                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // ---- Memento mori. Only here once someone has gone looking and
          //      given an age; the same rail as the year above it, measured
          //      against a nominal lifetime.
          Item {
            visible: root.birthYear > 0
            width: parent.width
            height: visible ? lifeBlock.height : 0

            Item {
              id: lifeBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(lifeLabel.implicitHeight, Style.space(10))

              Text {
                id: lifeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "LIFE"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: lifePercent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.lifeDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                anchors.left: lifeLabel.right
                anchors.right: lifePercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.lifeDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Color.accent)

                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }

              TapHandler {
                onDoubleTapped: root.clearLife()
              }

              MouseArea {
                id: lifeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                PanelToolTip {
                  visible: lifeMouse.containsMouse
                  text: "Memento Mori"
                  fontFamily: root.contentFontFamily
                }
              }
            }
          }

          // ---- Month grid: week numbers down a gutter on the left, then
          //      the seven day columns. Always six rows, so the popup is
          //      exactly as tall in February as it is in August.
          Item {
            width: parent.width
            height: gridColumn.y + gridColumn.height

            WheelHandler {
              onWheel: function(event) {
                // Horizontal wheels and touchpad side-scrolls report y === 0;
                // without this they would every one read as "next month".
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              // The meter above is a solid rule; the grid needs room to
              // read as its own block rather than hanging off it.
              y: Style.space(18)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3)

              Row {
                id: headerRow
                spacing: root.cellSpacing

                // The week-number heading doubles as the week-start toggle.
                // It is the one control in the panel whose meaning is not
                // self-evident, so it carries a tooltip naming the day the
                // click will switch to.
                Rectangle {
                  width: root.weekColumnWidth
                  height: Style.space(16)
                  radius: Style.cornerRadius
                  color: weekStartMouse.containsMouse
                    ? Style.hoverFillFor(root.contentForeground, Color.accent)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "W"
                    color: weekStartMouse.containsMouse
                      ? Style.hoverStateColor(root.contentForeground, Color.accent)
                      : Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    id: weekStartMouse
                    anchors.fill: parent
                    // A patro has no week-start choice to offer, so on the
                    // Nepali view the heading is just a heading.
                    enabled: !root.bikram
                    hoverEnabled: enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWeekStart()
                  }

                  PanelToolTip {
                    visible: weekStartMouse.containsMouse
                    text: "Start weeks on " + root.nextWeekStartLabel
                    fontFamily: root.contentFontFamily
                  }
                }

                Item {
                  width: root.gutterWidth
                  height: Style.space(16)
                }

                Repeater {
                  model: root.weekdays

                  Text {
                    required property var modelData
                    width: root.cellWidth
                    height: Style.space(16)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weekdayLabel(modelData)
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.calendarFontFamily
                    font.pixelSize: Style.font.caption
                    // "मङ्गल" needs the whole column; letterspacing it would
                    // both overflow the cell and split the conjunct visually.
                    font.letterSpacing: root.bikram ? 0 : 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Text {
                    width: root.weekColumnWidth
                    height: root.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weekCellText(modelData.week)
                    color: Qt.darker(root.contentForeground, 1.9)
                    font.family: root.calendarFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item {
                    width: root.gutterWidth
                    height: root.cellHeight
                  }

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      required property var modelData

                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      // Today is outlined, not filled: a lit-up block shouts
                      // over a grid this quiet.
                      color: "transparent"
                      border.width: modelData.today ? Style.spacing.hairline : 0
                      border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                      Text {
                        anchors.centerIn: parent
                        text: root.dayCellText(modelData)
                        color: modelData.inMonth
                          ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                          : Qt.darker(root.contentForeground, 2.2)
                        font.family: root.calendarFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.today
                      }
                    }
                  }
                }
              }
            }

            // Hairline down the week-number gutter, drawn only beside the
            // day rows so it does not cut through the header band.
            Rectangle {
              x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
              y: gridColumn.y + headerRow.height + gridColumn.spacing
              width: Style.spacing.hairline
              height: gridColumn.height - headerRow.height - gridColumn.spacing
              color: root.contentForeground
              opacity: 0.1
            }
          }

          // ---- Month stepping, spanning the grid it drives. The chevrons
          //      sit on the grid's outer bounds, the same edges the year
          //      rail above uses, so the row reads as the panel's other
          //      full-width rail instead of a cluster floating in space.
          //      The label is centered and fixed-width, so it holds still
          //      from "MAY" to "SEPTEMBER".
          Item {
            width: parent.width
            height: monthNav.height

            Item {
              id: monthNav
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: monthLabelBlock.implicitHeight + Style.space(10)

              Column {
                id: monthLabelBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  id: monthLabel
                  // Fixed width so the chevrons hold still between a
                  // "MAY 2026" and a "SEPTEMBER 2026".
                  width: Style.space(130)
                  height: bodyMetric.implicitHeight
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: root.monthNavText
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.calendarFontFamily
                  font.pixelSize: Style.font.body
                  font.letterSpacing: root.bikram ? 0 : 1
                }

                // The other calendar's months for the same stretch of days.
                // Romanised in both directions, so this line keeps the bar
                // font and never changes height.
                Text {
                  width: monthLabel.width
                  height: captionMetric.implicitHeight
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: root.monthNavSubText
                  color: Qt.darker(root.contentForeground, 2.1)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }
              }

              PanelActionButton {
                // Pulled out by the button's own padding so the glyph, not
                // its hit box, lines up with the "2026" on the year rail.
                anchors.left: parent.left
                anchors.leftMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                tooltipText: "Previous month"
                // Dims and goes inert at the start of the published Bikram
                // Sambat table, rather than clicking to no effect.
                enabled: !root.bikram || Bik.canStepMonth(root.bikramViewYear, root.bikramViewMonth, -1)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                tooltipText: "Next month"
                enabled: !root.bikram || Bik.canStepMonth(root.bikramViewYear, root.bikramViewMonth, 1)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }
        }
      }
    }
  }
}
