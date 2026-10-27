# Large-document navigation

The example can open a local UTF-8 fixture without persisting it to preferences.
Build and install the Example scheme, copy the fixture into the app's Documents
directory, and launch with `RUNESTONE_DOCUMENT` set to its filename:

```sh
device='<simulator UDID>'
container=$(xcrun simctl get_app_container "$device" dk.simonbs.Example data)
cp '/path/to/large-file.json' "$container/Documents/large-file.json"
SIMCTL_CHILD_RUNESTONE_DOCUMENT=large-file.json xcrun simctl launch "$device" dk.simonbs.Example
```

Fixture mode initially enables wrapping and line numbers and adds Jump to Top and
Jump to Bottom to the ellipsis menu, with a divider between the actions. Set
`RUNESTONE_WRAP_LINES=0` to start with wrapping disabled. These actions exercise `scrollRangeToVisible` without showing a keyboard. The
console reports synchronous navigation/layout duration; this is not a complete
frame-time measurement. The regular Go to Line menu exercises caret navigation.
The fixture remains local and should not be added to the repository.

On a fresh launch, choose Jump to Bottom in the ellipsis menu, then immediately
scroll toward earlier text with slow drags and fast flings. Check that lines remain contiguous, the text
under the finger does not jump as wrapped lines are measured, and there are no
blank frames. Reverse direction and repeat Top/Bottom navigation. Repeat after
changing orientation or wrapping, and use Go to Line with the keyboard visible.
Capture video when evaluating motion; still screenshots only verify individual
frames. Use a Release build for representative timing and distinguish initial
document parsing from navigation latency.

## Simulator validation (2026-10-27)

Release build on an isolated iPhone 17 Pro simulator running iOS 27.2, with a
local JSON fixture of 26,141,343 bytes, 11,352 logical lines, and a longest line
of 58,901 bytes. The fixture and recordings were kept local.

Cold EOF navigation after loading measured 14.34 ms with wrapping enabled and
96.92 ms with wrapping disabled. These are single-run synchronous navigation
and layout measurements, excluding initial document loading/parsing and not
device frame-rate guarantees. Unwrapped mode displays and measures more logical
lines; its existing 10,000-point maximum line width still splits extreme lines.

Verified with real simulator gestures and local video captures:

- EOF navigation followed by slow upward dragging, fast upward flings, and
  reverse scrolling through wrapped content.
- Cold EOF navigation and upward flinging with wrapping disabled.
- Switching wrapping off near EOF and navigating again.
- Top/Bottom round trips and Go to Line 11342, followed by upward dragging to
  line 11341 with the editor first responder and keyboard accessory visible.
- The first recorded destination frame has syntax colors already applied.

No blank viewports or layout discontinuities were found in the inspected
captures. Sampling and manual inspection do not prove absence of every possible
visual glitch. Physical-device performance, interactive rotation, and scrolling
with the full software keyboard occupying the screen remain unverified in this
pass (the simulator used hardware-keyboard mode after entering the line number).
