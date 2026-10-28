![](https://github.com/simonbs/Runestone/raw/main/Sources/Runestone/Documentation.docc/Resources/hero.png)

### 👋 Welcome to Runestone - a performant plain text editor for iOS with code editing features

Runestone uses GitHub's [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) to parse code to a syntax tree which is used for features that require an understanding of the code in the editor, for example syntax highlighting.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsimonbs%2FRunestone%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/simonbs/Runestone)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsimonbs%2FRunestone%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/simonbs/Runestone)
[![Build and Test](https://github.com/simonbs/Runestone/actions/workflows/build_and_test.yml/badge.svg)](https://github.com/simonbs/Runestone/actions/workflows/build_and_test.yml)
[![Build Documentation](https://github.com/simonbs/Runestone/actions/workflows/build_documentation.yml/badge.svg)](https://github.com/simonbs/Runestone/actions/workflows/build_documentation.yml)
[![Build Example Project](https://github.com/simonbs/Runestone/actions/workflows/build_example_project.yml/badge.svg)](https://github.com/simonbs/Runestone/actions/workflows/build_example_project.yml)
[![CodeQL](https://github.com/simonbs/Runestone/actions/workflows/codeql.yml/badge.svg)](https://github.com/simonbs/Runestone/actions/workflows/codeql.yml)
[![SwiftLint](https://github.com/simonbs/Runestone/actions/workflows/swiftlint.yml/badge.svg)](https://github.com/simonbs/Runestone/actions/workflows/swiftlint.yml)
[![Twitter](https://img.shields.io/badge/Twitter-@simonbs-blue.svg?style=flat)](https://twitter.com/simonbs)
[![Mastodon](https://img.shields.io/badge/Mastodon-@simonbs-blue.svg?style=flat)](https://mastodon.social/@simonbs)

## ✨ Features

- Syntax highlighting.
- Line numbers.
- Highlight the selected line.
- Show invisible characters (tabs, spaces and line breaks).
- Insertion of character pairs, e.g. inserting the trailing quotation mark when inserting the leading.
- Customization of colors and fonts.
- Toggle line wrapping on and off.
- Adjust height of lines.
- Add a page guide.
- Add vertical and horizontal overscroll.
- Highlight ranges in the text view.
- Search the text using regular expressions.
- Automatically detects if a file is using spaces or tabs for indentation.
- Specify line endings (CR, LF, CRLF) to use when inserting a line break.
- Automatically detect line endings in a text.

## 🚀 Getting Started

Please refer to the [Getting Started](https://docs.runestone.app/documentation/runestone/gettingstarted) article in the documentation and the [Meet Runestone](https://docs.runestone.app/tutorials/meet-runestone) series of tutorials.

## 📖 Documentation

The documentation of all public types is available at [docs.runestone.app](https://docs.runestone.app). The documentation is generated from the Swift code using Apple's [DocC documentation compiler](https://developer.apple.com/documentation/docc).

## Example app

Open `Example/Example.xcodeproj` and run the Example scheme. The ellipsis menu's
**Folding Examples** submenu loads JavaScript or Markdown and enables gutter
folding. Apps opt in with `textView.isCodeFoldingEnabled = true`; see the
[folding API documentation](Sources/Runestone/Documentation.docc/CodeFolding.md).

To inspect a local UTF-8 document without saving it to preferences, install the
Example and copy the file into its Documents directory:

```sh
device='<simulator UDID>'
container=$(xcrun simctl get_app_container "$device" dk.simonbs.Example data)
cp '/path/to/large-file.json' "$container/Documents/large-file.json"
SIMCTL_CHILD_RUNESTONE_DOCUMENT=large-file.json xcrun simctl launch "$device" dk.simonbs.Example
```

Fixture mode adds **Jump to Top** and **Jump to Bottom** and enables wrapping and
line numbers. Set `RUNESTONE_WRAP_LINES=0` to disable wrapping. Markdown fixtures
use `.md` or `.markdown`. Keep large fixtures local, and use Release builds for
performance checks; console navigation timings exclude document loading/parsing.

## 🏎 Performance

Runestone was built to be fast. Its good performance is by far mostly thanks to Tree-sitter's incremental parsing and [AvalonEdit's approach for managing lines in a document](https://github.com/icsharpcode/AvalonEdit/blob/master/ICSharpCode.AvalonEdit/Document/DocumentLineTree.cs).

When judging the performance of Runestone, it is key to build your app in the release configuration. The optimizations applied by the compiler when using the release configuration becomes very apparent when opening large documents.

## 🖥 Catalyst

The project should mostly work with Catalyst on the Mac, however, it isn't fully tested and the implementation isn't considered done. The focus is currently on the iPhone and iPad.

## 📱 Projects

The Runestone framework is used by an app of the same name. The Runestone app is a plain text editor for iPhone and iPad that uses all the features of this framework.

<a href="https://apps.apple.com/us/app/runestone-editor/id1548193893" target="_blank"><img width="150" alt="Runestone app icon" src="Assets/runestone-editor-app-icon.png"/></a>

<a href="https://apps.apple.com/us/app/runestone-editor/id1548193893" target="_blank"><img width="150" alt="Download on the App Store" src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg"/></a>

## 👨‍💻 Contributing

Pull requests with bugfixes and new features are much appreciated. I'll be happy to review them and merge them once they're ready, as long as they contain change that fit within the vision of Runestone and provide generally useful functionality.

Clone the repository to get started working on the project. Note that Runestone depends on Tree-sitter through a submodule. This submodule must be cloned as well before Runestone can be built. Pass the `--recurse-submodules` option when cloning the repository to clone all submodules.

```bash
git clone --recurse-submodules https://github.com/simonbs/Runestone.git
```

For an existing checkout, initialize or update the submodule to the commit recorded by Runestone:

```bash
git submodule update --init --recursive
```

SwiftPM initializes submodules automatically when resolving Runestone as a Git dependency. Downloaded GitHub source ZIP/tar archives omit submodule contents; use a Git checkout to build from source.

### Tree-sitter runtime

Runestone pins the upstream [Tree-sitter](https://github.com/tree-sitter/tree-sitter) submodule to **v0.27.1**, commit `10eb5ac119eec9cb4267a8e035066473983f5f3a`. Upstream [removed its Swift package manifest](https://github.com/tree-sitter/tree-sitter/pull/5849), so Runestone defines a local C target at `tree-sitter/lib`. It compiles only `src/lib.c`, which includes the runtime implementation, and exposes only `include/tree_sitter/api.h`. Private parser headers stay private; generated grammars compile against their own matching headers. This runtime supports grammar ABI versions 13–15.

To upgrade, fetch the desired upstream release tag, check it out inside `tree-sitter`, and commit the updated submodule pointer together with any required binding changes. Update the version and commit documented here. Do not use `git submodule update --remote` for normal setup or CI: builds must use the recorded commit. Before merging an upgrade, run the Runestone simulator tests, build the example, run TreeSitterLanguages' compatibility checks, and verify a fresh SwiftPM Git consumer.

Upstream licenses remain in the submodule, including `tree-sitter/LICENSE` and `tree-sitter/lib/src/unicode/LICENSE`. Preserve applicable notices when redistributing source or binaries, including in an application's third-party acknowledgements.

Consumers needing the C API can depend on the `TreeSitter` product from Runestone. Use one Tree-sitter runtime in an application; do not also link an independent copy from another package.

## ❤️ Acknowledgments

- [Tree-sitter](https://tree-sitter.github.io/tree-sitter) is used to parse code incrementally.
- Line management is translated to Swift from [AvalonEdit](https://github.com/icsharpcode/AvalonEdit).
- [swift-tree-sitter](https://github.com/viktorstrate/swift-tree-sitter) and [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) which have served as inspiration for the Tree-sitter bindings.
- Detection of indent strategy inspired by [auto-detect-indentation](https://github.com/jtokoph/auto-detect-indentation).
- And last (but not least!), thanks a ton to [Alexander Blach](https://twitter.com/Lextar) (developer of [Textastic](https://www.textasticapp.com)), [Till Konitzer](https://twitter.com/knutknatter) (developer of [Essayist](https://www.essayist.app)), [Greg Pierce](https://twitter.com/agiletortoise) (developer of [Drafts](https://getdrafts.com)) and [Max Brunsfeld](https://twitter.com/maxbrunsfeld) (developer of [Tree-sitter](https://tree-sitter.github.io/tree-sitter/)) for pointing me in the right direction when I got stuck.

### Writing Tools

When built with Xcode 16.2 or later, Runestone integrates with Apple's Writing Tools coordinator on iOS 18.2 and later. On supported Apple Intelligence devices this enables inline proofreading and rewriting, with line-by-line text previews, animations, and proofreading decorations. Runestone requests plain-text results and preserves the document's line endings. Earlier systems and builds retain the system-provided `UITextInput` experience; availability of Writing Tools is controlled by iOS.

`TextView.writingToolsBehavior` defaults to `.complete`. Set it to `.limited` for panel-based results or `.none` to disable Writing Tools. This configuration is available with Xcode 16.2 or later on iOS 18.0 and later.

Inline Writing Tools can replace text before the person accepts it. Observe `TextView.isWritingToolsActive` and the optional `textViewWritingToolsWillBegin(_:)` / `textViewWritingToolsDidEnd(_:)` delegate methods to defer autosaving or other persistent side effects until review finishes. Ordinary change callbacks still arrive for each revision, including restoration when a change is rejected. Suggestions remain one undo operation until an ordinary edit or undo/redo checkpoints them. User edits retain separate undo history, and later suggestions form a new checkpoint. Returning to a checkpoint's original text adds no undo entry.

`stopWritingTools()` ends the session synchronously from Runestone's perspective and keeps the currently displayed revision; it does not undo it. Typing, deletion, replacement, indentation, and undo/redo report changes through the coordinator's `updateRange` API and can keep the session active. UIKit may still end a session for a sufficiently large update. Programmatic document replacement, batch replacement, line moves, IME composition, read-only transitions, and removal from the window stop the session and invalidate outstanding context requests. When loading an external document, suppress persistence callbacks around stopping the session and assigning the new document so the previous editor contents cannot overwrite the incoming document.

Set `writingToolsExcludedRangesProvider` to return UTF-16 ranges for code, URLs, or other text that must be preserved. Runestone reevaluates the provider against the current text, applies Apple's `.writingToolsExclusionAttributeName` attribute to native contexts, and validates replacements before committing them. Explicit selections still honor exclusions; ordinary user edits remain allowed. Invalid or surrogate-splitting ranges are ignored. A replacement crossing protected content is rejected unless unchanged prefix/suffix text proves that content is preserved, so prefer localized exclusions over excluding whole documents. Changing the provider ends the session; changes to its text-dependent ranges are reported alongside ordinary edits, including syntax changes that alter exclusions outside the insertion itself. The provider must be pure and should cache expensive parsing.

Animation images contain only visible text and are bounded by the viewport. As the editor scrolls or reflows, Runestone refreshes the coordinator's geometry. Verifying the complete Apple Intelligence workflow, including generated results and animation timing, requires a supported physical device with Writing Tools enabled.
