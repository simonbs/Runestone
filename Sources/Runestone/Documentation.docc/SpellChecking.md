# Checking Spelling

Underline misspelled words and offer corrections using Apple's dictionaries.

## Overview

Runestone uses `UITextChecker` for spelling and displays corrections in the system edit menu. Enable checking independently of keyboard autocorrection:

```swift
textView.autocorrectionType = .no
textView.spellCheckingType = .yes
```

Select a misspelled word to see possible replacements. Choosing one preserves selection notifications and delegate approval, and creates a separate undo step. No private UIKit replacement object is used.

`.no` disables checking and removes spelling decorations. `.default` enables checking unless `autocorrectionType` is `.no`. To choose a dictionary explicitly, set `spellCheckingLanguage` to a value from `UITextChecker.availableLanguages`, for example `en_US`. When the language is `nil`, Runestone follows the active keyboard, then the preferred system languages. An unsupported explicit language disables checking instead of silently using another dictionary.

### Excluding code and other non-prose text

Runestone does not assume that every programming language uses the same syntax-node names. Use ``TextViewDelegate/textView(_:shouldCheckSpellingIn:)`` to exclude identifiers, URLs, code blocks, or other ranges. The callback receives a document range in UTF-16 coordinates and runs on the main thread. It can inspect ``TextView/syntaxNode(at:)`` or consult the application's own prose ranges.

The default checks all eligible visible words. Keep the callback inexpensive and call ``TextView/invalidateSpellChecking()`` when an external policy changes.

### Large documents and text input

Checks are debounced and limited to visible text plus a small word-boundary margin. Horizontally scrolled lines are checked at their visible columns. Work is split into bounded batches on the main queue; opening a file does not start a full-document spell check. Extremely large visible regions are budgeted, and words longer than 256 UTF-16 units are skipped.

The word being typed and marked text from an input method are excluded until committed or left by the caret. Edits, document replacement, language changes, and policy changes invalidate pending results. Corrections from an outdated menu cannot modify a newer document.

### Working with Writing Tools

Spell checking pauses during an active Writing Tools session so its red underlines and menus do not compete with native proofreading. It resumes on the final text when the session ends. Both features use the same guarded text-replacement path; a spelling correction remains an independent undo operation after a Writing Tools session.

Spelling does not require Apple Intelligence. It is available on all supported iOS versions, with `UIEditMenuInteraction` on iOS 16 and later and selected-word menu actions on earlier versions.
