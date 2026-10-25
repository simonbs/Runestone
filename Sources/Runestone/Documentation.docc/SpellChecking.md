# Checking Spelling

Underline misspelled words and offer corrections using Apple's dictionaries.

## Overview

Runestone uses `UITextChecker` for spelling and displays corrections in the system edit menu. Enable checking independently of keyboard autocorrection:

```swift
textView.autocorrectionType = .no
textView.spellCheckingType = .yes
```

Tap a misspelled word to see a compact correction menu on iOS 16 and later. Tapping another word or blank space dismisses it. Selecting a word also offers corrections in the regular edit menu. Earlier iOS versions use the regular edit menu for tapped or selected words.

Dictionary actions are hidden by default. Applications can independently opt into **Ignore Spelling**, **Learn Spelling**, and **Unlearn Spelling**:

```swift
textView.showIgnoreSpellingAction = true
textView.showLearnSpellingAction = true
textView.showUnlearnSpellingAction = true
```

These settings affect both spelling and regular edit menus. They do not disable the public dictionary APIs. Changing a setting invalidates existing spelling actions. Enabled dictionary actions remain available even when the dictionary has no replacement guesses. Choosing a replacement preserves selection notifications and delegate approval, and creates a separate undo step. No private UIKit replacement object is used.

`.no` disables checking and removes spelling decorations. `.default` enables checking unless `autocorrectionType` is `.no`. To choose a dictionary explicitly, set `spellCheckingLanguage` to a value from `UITextChecker.availableLanguages`, for example `en_US`. When the language is `nil`, Runestone follows the active keyboard, then the preferred system languages. An unsupported explicit language disables checking instead of silently using another dictionary.

### Ignoring and learning words

When enabled, **Ignore Spelling** suppresses a word for the current document session using the view's own `UITextChecker`. It applies to all occurrences in that view. Other views keep checking the word. Inspect ``TextView/ignoredSpellingWords``, call ``TextView/ignoreSpellingWord(_:)`` to restore application-managed ignores, or call ``TextView/resetIgnoredSpellingWords()`` to check them again.

Assigning ``TextView/text`` (even the same text) or calling ``TextView/setState(_:addUndoAction:)`` starts a new session and clears ignored words. Ordinary typing, replacements, undo/redo, language changes, and toggling spell checking preserve the session. Ignored words are not stored in `TextViewState` or persisted automatically. Applications that reuse a view for another document through incremental edits should explicitly reset the session.

When enabled, **Learn Spelling** adds the word to Apple's shared learned dictionary, across views and languages. Selecting a learned word offers **Unlearn Spelling** when `showUnlearnSpellingAction` is enabled, even though the word is no longer marked as misspelled. Learning and unlearning change dictionary state only: text, selection, and text undo history stay unchanged. These actions require an editable editor, enabled checking, no active composition or Writing Tools session, and approval from the spelling-range delegate. Outdated menu actions cannot change the dictionary.

Applications can expose their own explicit user commands with ``TextView/learnSpellingWord(_:)``, ``TextView/unlearnSpellingWord(_:)``, and ``TextView/hasLearnedSpellingWord(_:)``. Do not learn words automatically from document content. These methods refresh existing Runestone views. Changes made directly through `UITextChecker` require ``TextView/invalidateSpellChecking()``; views also refresh when becoming first responder and when the app becomes active. The public dictionary methods operate on the main thread, like the text view and `UITextChecker`.

Apple also offers `UITextChecker.completions(forPartialWordRange:in:language:)` for partially typed words. Runestone has no word-completion presentation or acceptance interface to extend, so this remains a separate capability. Keyboard prediction and autocorrection retain their existing controls. Grammar checking belongs to Writing Tools integration and is not part of these spelling actions.

### Excluding code and other non-prose text

Runestone does not assume that every programming language uses the same syntax-node names. Use ``TextViewDelegate/textView(_:shouldCheckSpellingIn:)`` to exclude identifiers, URLs, code blocks, or other ranges. The callback receives a document range in UTF-16 coordinates and runs on the main thread. It can inspect ``TextView/syntaxNode(at:)`` or consult the application's own prose ranges.

The default checks all eligible visible words. Keep the callback inexpensive and call ``TextView/invalidateSpellChecking()`` when an external policy changes.

### Large documents and text input

Checks are debounced and limited to visible text plus a small word-boundary margin. Horizontally scrolled lines are checked at their visible columns. Work is split into bounded batches on the main queue; opening a file does not start a full-document spell check. Extremely large visible regions are budgeted, and words longer than 256 UTF-16 units are skipped.

The word being typed and marked text from an input method are excluded until committed or left by the caret. Edits, document replacement, language changes, and policy changes invalidate pending results. Corrections from an outdated menu cannot modify a newer document.

### Working with Writing Tools

Spell checking pauses during an active Writing Tools session so its red underlines and menus do not compete with native proofreading. It resumes on the final text when the session ends. Both features use the same guarded text-replacement path; a spelling correction remains an independent undo operation after a Writing Tools session.

Spelling does not require Apple Intelligence. It is available on all supported iOS versions, with `UIEditMenuInteraction` on iOS 16 and later and selected-word menu actions on earlier versions.
