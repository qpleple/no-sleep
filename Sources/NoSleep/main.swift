import Cocoa
import IOKit.pwr_mgt

/// The three states, cycled by a left click on the menu bar icon.
enum Mode: Int, CaseIterable {
    case off        // white  – normal behaviour, Mac may sleep
    case awake      // yellow – no idle sleep while the lid is open
    case lidClosed  // red    – no sleep at all, even with the lid closed

    var next: Mode { Mode(rawValue: (rawValue + 1) % Mode.allCases.count)! }

    var title: String {
        switch self {
        case .off:       return "Off – sleep allowed"
        case .awake:     return "Awake – no sleep while lid open"
        case .lidClosed: return "Insomniac – no sleep even with lid closed"
        }
    }

    var color: NSColor? {
        switch self {
        case .off:       return nil               // template image: adapts to the menu bar
        case .awake:     return .systemYellow
        case .lidClosed: return .systemRed
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let symbolName = "cup.and.saucer.fill"
    private var statusItem: NSStatusItem!
    private var mode: Mode = .off
    private var assertionID: IOPMAssertionID = 0
    private var sleepDisabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            // Act on mouse-down and skip the press highlight, so a click just recolors the icon
            // without the menu bar entering its tracking/highlight mode.
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            (button.cell as? NSButtonCell)?.highlightsBy = []
        }
        // If a previous run left system sleep disabled, reflect that instead of hiding it.
        if isSleepDisabledSystemWide() {
            sleepDisabled = true
            mode = .lidClosed
            acquireAssertion()
        }
        render()
    }

    func applicationWillTerminate(_ notification: Notification) {
        apply(.off)
    }

    // MARK: - Interaction

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseDown {
            showMenu()
        } else {
            apply(mode.next)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        for m in Mode.allCases {
            let item = NSMenuItem(title: m.title, action: #selector(menuPicked(_:)), keyEquivalent: "")
            item.target = self
            item.tag = m.rawValue
            item.state = (m == mode) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit NoSleep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // so the next left click cycles instead of opening the menu
    }

    @objc private func menuPicked(_ sender: NSMenuItem) {
        if let m = Mode(rawValue: sender.tag) { apply(m) }
    }

    // MARK: - State machine

    private func apply(_ requested: Mode) {
        var new = requested

        // Red: disable system sleep entirely (survives lid close). Needs root via pmset.
        if new == .lidClosed && !sleepDisabled {
            if setSystemSleepDisabled(true) {
                sleepDisabled = true
            } else {
                new = .awake   // user cancelled the password prompt: fall back to yellow
            }
        } else if new != .lidClosed && sleepDisabled {
            if setSystemSleepDisabled(false) {
                sleepDisabled = false
            } else {
                new = .lidClosed  // couldn't re-enable sleep, stay honest about it
            }
        }

        // Yellow and red: hold a power assertion against idle sleep.
        if new == .off { releaseAssertion() } else { acquireAssertion() }

        mode = new
        render()
    }

    private func acquireAssertion() {
        guard assertionID == 0 else { return }
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NoSleep menu bar app" as CFString,
            &assertionID)
    }

    private func releaseAssertion() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    // MARK: - pmset (needs root)

    /// Tries passwordless sudo first (see README for the sudoers rule), then falls back
    /// to the standard macOS administrator password prompt.
    private func setSystemSleepDisabled(_ disabled: Bool) -> Bool {
        let value = disabled ? "1" : "0"
        if run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]).status == 0 {
            return true
        }
        let source = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }

    private func isSleepDisabledSystemWide() -> Bool {
        let out = run("/usr/bin/pmset", ["-g"]).output
        return out.contains("SleepDisabled") && out.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
    }

    private func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    // MARK: - Icon

    private func render() {
        guard let button = statusItem.button else { return }
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: mode.title) else {
            // Symbol unavailable: never leave the item blank.
            button.image = nil
            button.title = "☕"
            button.contentTintColor = mode.color
            button.toolTip = mode.title
            return
        }
        var config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        if let color = mode.color {
            config = config.applying(.init(paletteColors: [color]))
            button.image = base.withSymbolConfiguration(config)
            button.image?.isTemplate = false
        } else {
            button.image = base.withSymbolConfiguration(config)
            button.image?.isTemplate = true
        }
        button.toolTip = mode.title
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
