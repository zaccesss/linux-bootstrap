# Accessibility

This bootstrap sets up a whole Ubuntu machine, so it decides how much of the system a person has to
find and fix by hand afterwards. It keeps runs predictable and readable. The `configs` extra can
also bring a high-contrast terminal palette that follows light and dark mode.

> [!NOTE]
> Some of these settings are preferences rather than requirements. Change them freely in your own
> copy. If a change would help other people too, open an issue or a pull request so I can consider
> it for everyone.

## Reading a run

- Every line starts with a word label, `[INFO]`, `[ OK ]`, `[WARN]` or `[ERROR]`, so the state of a
  run reads correctly without colour and with a screen reader.
- `--list` shows every optional extra with a one-line description before anything is installed.
  Nothing beyond the default stages runs unless it is asked for.
- Each stage checks what is already in place, so running it again changes nothing that is already
  right.

## On a desktop

- The `configs` extra applies GNOME settings from
  [system-defaults](https://github.com/zaccesss/system-defaults) and links the High Contrast palette
  from [terminal-config](https://github.com/zaccesss/terminal-config) for Ptyxis, the terminal in
  Ubuntu 25.10 and later: vivid colours on black in dark mode, every colour at 7:1 or more on white
  in light mode.
- The `mac-keys` extra gives a VM on a Mac the same shortcuts as macOS (`Cmd+C`, `Cmd+V` and so on)
  and natural scrolling, so one set of muscle memory covers both.

## Known gaps

- GNOME Terminal on Ubuntu 24.04 has no light and dark palette pair, so its dark palette is loaded
  by hand from terminal-config's `linux/gnome-terminal/` file.
- The Orca screen reader is left at Ubuntu's defaults.

## Feedback wanted

If something here gets in the way, open an [issue](https://github.com/zaccesss/linux-bootstrap/issues/new/choose)
describing what happened and what would work better.

## The shared statement

> [!NOTE]
> I keep one shared accessibility statement for all my projects:
> [zaccesss/accessibility](https://github.com/zaccesss/accessibility) or on
> [my site](https://isaacadjei.me/accessibility). This file takes precedence where the two differ.
