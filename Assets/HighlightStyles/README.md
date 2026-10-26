# Syntax highlight captures

Native iPhone 17 Pro Simulator captures from a temporary UIKit host using Runestone `TextView`, rendered against framework commit `3d7ff92e158ddb37f0661b99a1301a111e2917c1` on iOS 26.5.

Each screen compares two views in the same build. The upper view uses the individual `Theme` callbacks; the lower view returns a complete `HighlightStyle`. These are API comparisons, not screenshots of two different framework revisions, and are visual evidence rather than automated appearance regression tests.

- `token-backgrounds.png`: Alabaster BG colors with HTML captures. The complete style adds yellow comment, green string, and blue tag backgrounds.
- `nested-style-reset.png`: A synthetic JavaScript query captures `(program) @emphasis` and `(string) @plain`. The outer capture supplies bold, italic, purple text, and shadow. Returning `HighlightStyle()` for strings restores the default foreground and regular font and removes the shadow. The individual callbacks retain the enclosing style.
- `font-weight-compatibility.png`: Tomorrow colors with JavaScript captures. Keywords and functions use a semibold font (weight 600) through both APIs, demonstrating compatibility with existing custom-font callbacks.

The sample code, fonts, and view layout are identical between each pair of panels. The screenshots were captured directly from Simulator without compositing or retouching.
