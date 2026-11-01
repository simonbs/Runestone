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

`.no` disables checking and removes spelling decorations. `.default` enables checking unless `autocorrectionType` is `.no`. To choose a dictionary explicitly, set `spellCheckingLanguage` to a value from `UITextChecker.availableLanguages`, for example `en_US`. Matching ignores case and accepts hyphens or underscores, but dictionary calls always receive the original advertised identifier. A bare language code such as `en` resolves to the first advertised dictionary for that language in Apple's user-preference order. An exact advertised bare code, such as `hi`, remains unchanged. This explicit choice always wins and bypasses automatic detection. An unavailable explicit region or script disables checking instead of silently substituting a different dialect or script. Resolution does not rewrite the value of `spellCheckingLanguage` or document metadata.

### Automatic spelling language

With `spellCheckingLanguage == nil`, Runestone uses `NLLanguageRecognizer` to choose a dictionary independently for each visible paragraph. Detection considers Apple's supported dictionaries even when the paragraph language is absent from the keyboard and preferred system languages. A confident English paragraph can therefore use an English dictionary while a Danish keyboard is selected. For a detected base language, regional dictionaries already preferred by the keyboard/system configuration take precedence.

Markdown URL targets and balanced inline code are removed from the inference sample only; this does not change document text, dictionary ranges, or the host's spelling exclusions. Recognition is deliberately conservative: the bounded sample must contain at least 40 letters and eight whitespace-separated words, at least 55 percent letters, and at most 15 percent non-prose symbols. The best hypothesis must have confidence of at least 0.9 and exceed the runner-up by at least 0.2. The first, middle, and last substantial sentences (at most three) are checked independently; confidently disagreeing sentence languages cause fallback. Scores are not treated as proportions of a bilingual paragraph, and detection cannot reliably identify every mixture or short passage. Short headings, uncertain or unsupported results, code-shaped text, and clearly mixed paragraphs retain the fallback dictionaries. Applications should still use the spelling-range delegate to exclude code and URLs.

Fallback combines supported languages from the current keyboard, installed active input modes, and preferred system languages. A fallback word is misspelled only when none of those dictionaries accepts it; correction guesses are combined without duplicates. UIKit exposes only a combined keyboard's primary language, so a secondary fallback language must also be exposed by another input mode or the preferred system languages. A document's explicit override is the reliable way to choose a different dictionary for short or ambiguous content.

Samples are prepared after viewport changes or edits and recognition is debounced by approximately 300 milliseconds. Each sample contains at most 2,048 UTF-16 units; a request has at most 16 samples and 16,384 units in total. Boundary searches have a separate 32,768-step budget and inspect at most 64 visible windows, including when the document consists of blank lines or one enormous unwrapped paragraph. Clipped samples use unambiguous ASCII whitespace-to-letter/digit boundaries, omitting partial words and grapheme sequences. A huge unwrapped paragraph without such safe boundaries can conservatively remain in fallback; complete paragraphs are not clipped merely because they use another script. Only these immutable samples enter a serial background worker. `UITextChecker`, document access, decorations, and menus remain on the main thread. There is at most one active inference batch and one newest pending request; rapid typing cannot create an inference backlog.

The service retains at most 64 completed paragraph samples for the open view. An unchanged paragraph reuses its result, including an uncertain fallback result, even if another edit shifted its document offset. Only new or changed samples require recognition. Selection changes and dictionary refreshes retain the current regions, so an immediately opened spelling menu uses the same dictionary as the underlines. Text edits clear old range coordinates, then restore a matching cached paragraph during the next bounded viewport/menu preparation. A small edit to the same paragraph can keep the previous language while updated recognition is pending; an uncertain new result returns it to fallback. Wholesale paragraph replacement, document replacement, explicit-language changes, disabling checking, and Writing Tools transitions discard stale detection results. Applying a changed detection also invalidates existing spelling menu actions. Underlines, suggestions, Ignore/Learn actions, and correction validation all use the same paragraph dictionary policy. Detected languages are transient and are never written to document content or metadata.

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
