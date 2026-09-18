# NoSleep

A minimal macOS menu bar app that keeps your Mac awake. One icon, three states, cycled with a left click:

| Icon   | State     | Effect |
|--------|-----------|--------|
| white  | Off       | normal behaviour, the Mac may sleep |
| yellow | Awake     | no idle sleep while the lid is open |
| red    | Insomniac | no sleep at all, even with the lid closed |

Right click opens a menu to pick a state or quit. The white icon follows the menu bar appearance (black on a light menu bar).

## Install

Requires macOS 13+ and the Xcode command line tools.

```bash
git clone https://github.com/qpleple/no-sleep.git
cd no-sleep
./build.sh --install   # builds NoSleep.app, copies it to /Applications and launches it
```

Add it to System Settings › General › Login Items to start it at login.

## How it works

- **Yellow** holds an IOKit power assertion (`PreventUserIdleSystemSleep`). The display may still dim.
- **Red** runs `pmset -a disablesleep 1`, the only supported way to keep a MacBook awake with the lid closed. It needs root, so macOS asks for your administrator password when entering or leaving red. Sleep is re-enabled when you switch state or quit.

To skip the password prompt, allow exactly those two commands without a password:

```bash
echo "$USER ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0" | sudo tee /etc/sudoers.d/nosleep
sudo chmod 440 /etc/sudoers.d/nosleep
```

If the app is killed while red, it detects `SleepDisabled 1` on next launch and starts in red so you can turn it off. Manual reset: `sudo pmset -a disablesleep 0`.

**Warning:** in red, a closed MacBook keeps running at full power. Don't put it in a bag.

## Project layout

- `Sources/NoSleep/main.swift` — the whole app, a single file, no Xcode project
- `make-icon.swift` — renders the app icon from the same SF Symbol
- `build.sh` — builds the Swift package and assembles `NoSleep.app`

## License

MIT
