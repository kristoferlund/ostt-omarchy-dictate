import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Dictation status for OSTT. The widget is only a client: the recording runs
// in the background under `ostt-dictate`, so closing or reloading the bar never
// abandons a recording. Status comes from `ostt-dictate status --follow`,
// which prints a JSON line whenever the state changes.
//
// Until the plugin's setup has installed ostt-dictate and OSTT, the widget
// offers to run it.
//
// Right-click while idle opens a card listing the apps on the visible
// workspaces (and any already set up) with their current settings. Clicking a
// row expands it in place, as the network panel does, to choose the
// processing action for dictation in that app and whether to attach a
// screenshot of its window. Arrows or j/k move a cursor through it, Enter or
// Space acts, Esc collapses and then closes.
Panel {
  id: root
  moduleName: "io.github.kristoferlund.ostt-dictate"

  // idle | recording | transcribing | error, or "" while OSTT is unavailable.
  property string phase: ""
  // ostt-dictate or ostt is not on PATH: the setup has not run, or stopped
  // before installing OSTT.
  property bool needsSetup: false
  property string errorText: ""
  // An error is shown prominently for a while, then the widget calms down;
  // the next dictation clears it.
  property bool errorFresh: false
  readonly property bool hideWhenIdle: setting("hideWhenIdle", false)

  readonly property bool busy: phase === "recording" || phase === "transcribing"

  // From `ostt-dictate apps`: [{ class, action, screenshot }] and
  // [{ id, name, description, images, error }].
  property var apps: []
  property var actionOptions: []
  // The first list has arrived; until then the card says it is loading.
  property bool appsLoaded: false
  property string appsError: ""
  // A change that could not be saved; kept until the next one succeeds, as
  // reloading the list afterwards would otherwise hide it.
  property string mapError: ""
  // Clicks wait while a change or the reload after it runs, so they never act
  // on the list as it was before.
  readonly property bool changing: mapProc.running || appsProc.running
  // The class of the one expanded row; kept across reloads after a change.
  property string expandedClass: ""
  // The item under the keyboard (or mouse) cursor, as navKey() names it, so it
  // stays put when the list reloads.
  property bool cursorActive: false
  property string cursorKey: ""
  // Set when the keyboard moved the cursor, which scrolls it into view; the
  // mouse never scrolls the card under itself.
  property bool cursorFromKeyboard: false

  // The card's and tooltip's text, in the language picked under
  // Setup > Language. Messages from OSTT and ostt-dictate stay English.
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  visible: needsSetup || (phase !== "" && !(hideWhenIdle && !busy && !errorFresh))
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function apply(line) {
    var status
    try {
      status = JSON.parse(String(line))
    } catch (e) {
      return
    }
    var previous = root.phase
    root.phase = String(status.state || "idle")
    root.errorText = String(status.error || "")
    if (root.phase === "error" && previous !== "error" && previous !== "") {
      root.errorFresh = true
      errorTimer.restart()
    } else if (root.phase !== "error") {
      root.errorFresh = false
    }
  }

  function run(action) {
    if (root.bar) root.bar.run("ostt-dictate " + action)
  }

  // Runs the plugin's install, then the setup, in Omarchy's floating
  // terminal, as Setup > Defaults > Dictation runs a backend's setup. The
  // launcher runs its argument through bash, hence the quoting.
  function setUp() {
    // One terminal per click is enough; a second setup would wait on the first.
    if (setupLaunched.running) return
    setupLaunched.restart()
    var install = decodeURIComponent(String(Qt.resolvedUrl("install")).replace(/^file:\/\//, ""))
    Util.execArgv(["omarchy-launch-floating-terminal-with-presentation", Util.shellQuote(install)])
  }

  function loadApps(text) {
    var data
    try {
      data = JSON.parse(String(text))
    } catch (e) {
      root.appsError = strings.t("apps.listFailed")
      return
    }
    // Plain transcription is named where it is shown, so it follows the language.
    var options = [{ value: "", label: "", description: "", images: false, error: "" }]
    var actions = data.actions || []
    for (var i = 0; i < actions.length; i++)
      options.push({
        value: String(actions[i].id),
        label: String(actions[i].name || actions[i].id),
        description: String(actions[i].description || ""),
        // An OSTT too old to say cannot attach images at all.
        images: actions[i].images === true,
        // Why the action cannot run, e.g. an unknown agent.
        error: String(actions[i].error || "")
      })
    root.actionOptions = options
    var apps = data.apps || []
    // An expanded app that has just been set to plain transcription leaves
    // the list unless it is open; keep it until the card closes.
    var kept = false
    for (var j = 0; j < apps.length; j++)
      if (String(apps[j]["class"]) === root.expandedClass) kept = true
    if (root.expandedClass !== "" && !kept)
      apps.push({ "class": root.expandedClass, action: "", screenshot: false })
    root.apps = apps
    root.appsError = String(data.error || "")
    root.appsLoaded = true
  }

  function setApp(appClass, action, screenshot) {
    var command = ["ostt-dictate", "map", appClass]
    if (action !== "") command.push(action)
    if (action !== "" && screenshot) command.push("--screenshot")
    mapProc.command = command
    mapProc.running = true
  }

  function actionTakesImages(action) {
    for (var i = 0; i < root.actionOptions.length; i++)
      if (root.actionOptions[i].value === action) return root.actionOptions[i].images
    return false
  }

  function actionError(action) {
    for (var i = 0; i < root.actionOptions.length; i++)
      if (root.actionOptions[i].value === action) return root.actionOptions[i].error
    return ""
  }

  function actionLabel(action) {
    if (action === "") return strings.t("action.plain")
    for (var i = 0; i < root.actionOptions.length; i++)
      if (root.actionOptions[i].value === action) return root.actionOptions[i].label
    return action
  }

  function appByClass(appClass) {
    for (var i = 0; i < root.apps.length; i++)
      if (String(root.apps[i]["class"]) === appClass) return root.apps[i]
    return null
  }

  function toggleRow(appClass) {
    root.expandedClass = root.expandedClass === appClass ? "" : appClass
  }

  // An action that cannot run is not offered; the screenshot stays on only
  // if the new action can use it.
  function chooseAction(appClass, action) {
    var app = root.appByClass(appClass)
    if (root.changing || !app || app.action === action || root.actionError(action) !== "") return
    root.setApp(appClass, action, app.screenshot === true && root.actionTakesImages(action))
  }

  // Only an action that takes images can get a screenshot; one already on can
  // still be turned off.
  function toggleScreenshot(appClass) {
    var app = root.appByClass(appClass)
    if (root.changing || !app) return
    if (!root.actionTakesImages(app.action) && app.screenshot !== true) return
    root.setApp(appClass, app.action, app.screenshot !== true)
  }

  // Keyboard navigation: every row, then the options and the switch of the
  // expanded one.
  function navKey(kind, appClass, value) {
    return [kind, appClass, value || ""].join("\u001f")
  }

  function navKeys() {
    var keys = []
    for (var i = 0; i < root.apps.length; i++) {
      var appClass = String(root.apps[i]["class"])
      keys.push(root.navKey("row", appClass))
      if (appClass !== root.expandedClass) continue
      for (var j = 0; j < root.actionOptions.length; j++)
        keys.push(root.navKey("option", appClass, root.actionOptions[j].value))
      keys.push(root.navKey("screenshot", appClass))
    }
    return keys
  }

  function pointAt(key, fromKeyboard) {
    root.cursorActive = true
    root.cursorFromKeyboard = fromKeyboard === true
    root.cursorKey = key
  }

  function moveCursor(dy) {
    var keys = root.navKeys()
    if (keys.length === 0) return
    var i = keys.indexOf(root.cursorKey)
    if (!root.cursorActive || i < 0) root.pointAt(keys[Math.max(i, 0)], true)
    else root.pointAt(keys[Math.max(0, Math.min(keys.length - 1, i + dy))], true)
  }

  function activateCursor() {
    // A reload may have removed the item under the cursor.
    if (root.navKeys().indexOf(root.cursorKey) < 0) return
    var parts = root.cursorKey.split("\u001f")
    if (parts[0] === "row") root.toggleRow(parts[1])
    else if (parts[0] === "option") root.chooseAction(parts[1], parts[2])
    else if (parts[0] === "screenshot") root.toggleScreenshot(parts[1])
  }

  // Scrolls the card so the item under the cursor is in view.
  function reveal(item) {
    var y = item.mapToItem(column, 0, 0).y
    if (y < scroller.contentY) scroller.contentY = y
    else if (y + item.height > scroller.contentY + scroller.height)
      scroller.contentY = y + item.height - scroller.height
  }

  // A Chrome web app without a desktop entry is named by its host.
  function webAppHost(appClass) {
    var match = /^chrome-([^_]+)__/.exec(appClass)
    return match ? match[1] : ""
  }

  function iconSource(icon) {
    if (icon === "") return ""
    if (icon.charAt(0) === "/") return "file://" + icon
    return Quickshell.iconPath(icon, true)
  }

  onOpenedChanged: {
    if (opened) {
      root.mapError = ""
      appsProc.running = true
    } else {
      root.expandedClass = ""
      root.cursorActive = false
    }
  }

  Process {
    id: follower
    command: ["ostt-dictate", "status", "--json", "--follow"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.apply(line) }
    }
    // Stopped, or never started because ostt-dictate is missing (a failed
    // start emits no exited): hide and try again shortly.
    onRunningChanged: if (!running) {
      root.phase = ""
      setupCheck.running = true
      restartTimer.restart()
    }
  }

  Process {
    id: setupCheck
    command: ["sh", "-c", "command -v ostt-dictate && command -v ostt"]
    running: true
    onExited: function(exitCode) { root.needsSetup = exitCode !== 0 }
  }

  // While setup is needed, notices when it has been done.
  Timer {
    interval: 5000
    repeat: true
    running: root.needsSetup
    onTriggered: setupCheck.running = true
  }

  Timer {
    id: setupLaunched
    interval: 10000
  }

  Process {
    id: appsProc
    command: ["ostt-dictate", "apps"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.loadApps(text) }
  }

  Process {
    id: mapProc
    stderr: StdioCollector { id: mapErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.mapError = exitCode === 0 ? "" : String(mapErr.text || strings.t("apps.saveFailed")).trim()
      appsProc.running = true
    }
  }

  Timer {
    id: restartTimer
    interval: 5000
    onTriggered: follower.running = true
  }

  Timer {
    id: errorTimer
    interval: 15000
    onTriggered: root.errorFresh = false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: {
      if (root.needsSetup) return "󰍬"
      if (root.phase === "transcribing") return "󰔟"
      if (root.phase === "error" && root.errorFresh) return "󰍭"
      return "󰍬"
    }
    active: root.phase === "recording" || (root.phase === "error" && root.errorFresh)
    dimmed: root.phase === "idle" || (root.phase === "error" && !root.errorFresh)
    tooltipText: {
      if (root.needsSetup) return strings.t("tooltip.setup")
      if (root.phase === "recording") return strings.t("tooltip.recording")
      if (root.phase === "transcribing") return strings.t("tooltip.transcribing")
      if (root.phase === "error") return strings.t("tooltip.failed").arg(root.errorText)
      return strings.t("tooltip.idle")
    }
    onPressed: function(b) {
      if (root.needsSetup) {
        root.setUp()
      } else if (b === Qt.RightButton) {
        if (root.busy) root.run("cancel")
        else root.toggle()
      } else if (b === Qt.LeftButton) {
        // Toggle refuses new work while transcribing; nothing to do then.
        if (root.phase !== "transcribing") root.run("toggle")
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: {
        if (root.expandedClass !== "") {
          root.pointAt(root.navKey("row", root.expandedClass), true)
          root.expandedClass = ""
        } else {
          root.close()
        }
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // The card is at most as tall as the screen; a longer list scrolls.
      Flickable {
        id: scroller
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroller.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: strings.t("card.title")
            meta: root.phase === "recording" ? strings.t("card.recording")
              : root.phase === "transcribing" ? strings.t("card.transcribing")
              : root.phase === "error" ? strings.t("card.failed").arg(root.errorText)
              : strings.t("card.ready")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            // The OSTT wordmark, as in the terminal app; text, so it takes the
            // theme's colour.
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "┏┓┏╋╋\n┗┛┛┗┗"
                color: root.bar.foreground
                font.family: "monospace"
                font.pixelSize: Style.font.title
              }
            }
          }

          PanelSeparator {
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: strings.t("apps.header")
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Text {
              width: parent.width
              bottomPadding: Style.space(4)
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              readonly property string error: root.mapError !== "" ? root.mapError : root.appsError
              text: error !== "" ? error
                : !root.appsLoaded ? strings.t("apps.loading")
                : root.apps.length === 0 ? strings.t("apps.none")
                : strings.t("apps.hint")
              color: error !== "" ? root.bar.urgent : root.bar.foreground
              opacity: error !== "" ? 1 : 0.6
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: root.apps
              delegate: AppRow {}
            }
          }
        }
      }
    }
  }

  // One app: icon, name and class, and its current setting. Expands in place
  // to the action pills and the screenshot switch.
  component AppRow: CursorSurface {
    id: row
    required property var modelData
    readonly property string appClass: String(modelData["class"])
    readonly property string action: String(modelData.action || "")
    readonly property bool screenshot: modelData.screenshot === true
    readonly property bool expanded: root.expandedClass === appClass
    readonly property string rowKey: root.navKey("row", appClass)
    // The app's desktop entry, as the launcher finds it; looked up again when
    // the shell's list of applications changes.
    readonly property var entry: {
      DesktopEntries.applications.values
      return DesktopEntries.heuristicLookup(appClass)
    }
    readonly property string appName: entry ? entry.name : (root.webAppHost(appClass) || appClass)

    width: column.width
    implicitHeight: header.height + (expanded ? settingsBody.implicitHeight : 0)
    hasCursor: root.cursorActive && root.cursorKey === rowKey
    onHasCursorChanged: if (hasCursor && root.cursorFromKeyboard) root.reveal(header)
    current: expanded
    foreground: root.bar.foreground
    currentFill: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
    clip: true

    MouseArea {
      id: headerMouse
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: header.height
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.pointAt(row.rowKey)
      onClicked: root.toggleRow(row.appClass)
    }

    Item {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      height: Math.max(appIcon.height, names.implicitHeight) + Style.spacing.rowPaddingX

      Image {
        id: appIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        height: width
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        source: row.entry ? root.iconSource(String(row.entry.icon || "")) : ""
        visible: status === Image.Ready
      }
      Text {
        anchors.centerIn: appIcon
        visible: !appIcon.visible
        textFormat: Text.PlainText
        text: "󰣆"
        color: root.bar.foreground
        opacity: 0.6
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
      }

      Column {
        id: names
        anchors.left: appIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: summary.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: row.appName
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width
          visible: row.appName !== row.appClass
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: row.appClass
          color: root.bar.foreground
          opacity: 0.5
          font.family: "monospace"
          font.pixelSize: Style.font.caption
        }
      }

      // Current setting at a glance: the action, with a camera when a
      // screenshot goes along.
      Row {
        id: summary
        anchors.right: chevron.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: row.action !== "" && row.screenshot
          textFormat: Text.PlainText
          text: "󰄀"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, header.width * 0.5)
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: root.actionLabel(row.action)
          color: root.bar.foreground
          opacity: row.action !== "" ? 0.9 : 0.5
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: row.expanded ? "󰅀" : "󰅂"
        color: root.bar.foreground
        opacity: 0.6
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Column {
      id: settingsBody
      visible: row.expanded
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: header.bottom
      // Lined up with the app name, past the icon.
      anchors.leftMargin: Style.space(10) + appIcon.width + Style.space(4)
      anchors.rightMargin: Style.space(10)
      topPadding: Style.space(2)
      bottomPadding: Style.space(12)
      spacing: Style.space(10)

      Column {
        width: parent.width
        spacing: Style.space(4)

        PanelSectionHeader {
          leftPadding: Style.space(6)
          text: strings.t("action.header")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Repeater {
          model: root.actionOptions

          // One choice; the current one carries a check mark.
          CursorSurface {
            id: option
            required property var modelData
            readonly property string value: String(modelData.value)
            readonly property bool chosen: value === row.action
            // An action that cannot run is shown with the reason, not offered.
            readonly property string problem: String(modelData.error || "")
            readonly property string key: root.navKey("option", row.appClass, value)
            width: parent.width
            implicitHeight: optionText.implicitHeight + Style.space(12)
            hasCursor: root.cursorActive && root.cursorKey === key
            onHasCursorChanged: if (hasCursor && root.cursorFromKeyboard) root.reveal(option)
            foreground: root.bar.foreground

            Column {
              id: optionText
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.right: check.left
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.actionLabel(option.value)
                color: root.bar.foreground
                opacity: option.chosen ? 1 : option.problem !== "" ? 0.4 : 0.75
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                width: parent.width
                visible: text !== ""
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: option.problem !== "" ? option.problem
                  : option.value === "" ? strings.t("action.plainDescription")
                  : String(option.modelData.description || "")
                color: option.problem !== "" ? root.bar.urgent : root.bar.foreground
                opacity: option.problem !== "" ? 0.8 : 0.5
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            Text {
              id: check
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              visible: option.chosen
              textFormat: Text.PlainText
              text: "󰄬"
              color: Commons.Color.accent
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              id: optionMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: option.problem !== "" ? Qt.ArrowCursor : Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.pointAt(option.key)
              onClicked: root.chooseAction(row.appClass, option.value)
            }
          }
        }
      }

      // A separate setting from the action, so it gets its own section and
      // a boxed switch row rather than another line in the list.
      Column {
        width: parent.width
        spacing: Style.space(6)

        PanelSectionHeader {
          leftPadding: Style.space(6)
          text: strings.t("screenshot.header")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Toggle {
          id: shot
          readonly property bool takesImages: root.actionTakesImages(row.action)
          readonly property string key: root.navKey("screenshot", row.appClass)
          width: parent.width
          enabled: takesImages || row.screenshot
          hasCursor: root.cursorActive && root.cursorKey === key
          onHasCursorChanged: if (hasCursor && root.cursorFromKeyboard) root.reveal(shot)
          onHovered: function(isHovered) { if (isHovered) root.pointAt(key) }
          opacity: enabled ? 1 : 0.4
          label: strings.t("screenshot.label")
          description: row.action === "" ? strings.t("screenshot.chooseAction")
            : !takesImages ? strings.t("screenshot.noImages")
            : strings.t("screenshot.description")
          checked: row.screenshot
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          titleSize: Style.font.bodySmall
          onClicked: root.toggleScreenshot(row.appClass)
        }
      }
    }
  }
}
