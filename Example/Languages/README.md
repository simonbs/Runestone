# Languages

The Example uses the maintained JavaScript, Markdown, and Markdown-inline grammars
and folding queries from the `codex/code-folding-queries` branch of
[simonbs/TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages/tree/codex/code-folding-queries).
The local wrapper keeps the Example's existing `RunestoneJavaScriptLanguage` import.
SwiftPM uses the local Runestone checkout for the editor and its Tree-sitter runtime.
