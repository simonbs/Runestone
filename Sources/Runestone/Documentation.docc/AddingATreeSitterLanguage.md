# Adding a Tree-sitter Language

Learn how to add one of Tree-sitter's many supported language and start syntax highlighting text.

## Overview

Runestone is built on the [Tree-sitter parser generator](https://tree-sitter.github.io/tree-sitter/). A parser generator is a tool that takes a grammar as input and outputs a parser for that language. For example, it could take the grammar for the JavaScript language as input and output code that can parse JavaScript source files. There is often a single parser for each language.

A Tree-sitter parser takes text as input and outputs a [syntax tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree), a structure that describes the contents of that file. This tree is used by Runestone to understand the contents of a file and ultimately syntax highlight the file. Syntax highlighting is performed by _querying_ the tree.

Querying the tree is a concept introduced by Tree-sitter and allows us to find nodes that match certain criteria, for example, we could find all nodes with the name `keyword`, `property`, or `string`, and by doing so we know the location of these nodes in the text and such which words to highlight.

All of this is supported by Tree-sitter and abstracted away by Runestone. All you need to do is provide Runestone with the parser to use, however, having a rough idea of the concepts involved is helpful to understand how a parser is used with Runestone.

Before diving into how we add a Tree-sitter language to a project and use it with Runestone, we should take a look at how a Tree-sitter parser is structured.

## File Structure of a Tree-sitter Parser

Tree-sitter parsers are typically distributed in repositories on GitHub. The official repositories reside under the [tree-sitter organization](https://github.com/tree-sitter). There are plenty of third-party parsers out there as well. In order to understand the structure of a Tree-sitter parser, we will have a look at the contents of the parser in the [tree-sitter/tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json) repository on GitHub. The parser hosted in that repository supports parsing JSON documents.

|File|Description|
|-|-|
|grammar.js|The grammar for the JSON language is written in Tree-sitter's domain-specific language. Learn more about the DSL by reading [Tree-sitter's documentation on the topic](https://tree-sitter.github.io/tree-sitter/creating-parsers#the-grammar-dsl).|
|src/parser.c|Parser generated from the grammar using Tree-sitter. Learn more about generating a parser from a grammar by reading [Tree-sitter's documentation on the topic](https://tree-sitter.github.io/tree-sitter/creating-parsers#command-generate).|
|src/tree_sitter/parser.h|Contains the basic C definitions that the generated parser needs.|
|queries/highlights.scm|Contains the query to be run on the syntax tree to provide us with the information needed to syntax highlight text.|
|queries/injections.scm|Contains a query that can be used to determine when other languages are injected into code. For example, Markdown files may contain code blocks that require other Tree-sitter parsers to be used in order to highlight the contents of those code blocks.|

A repository may contain other files. In rare cases, these are important to use but will usually reside under the `src` directory.

## Adding a Tree-sitter Parser to Your Project

Runestone abstracts everything related to parsing and syntax highlighting text away but you will need to provide Runestone with the parser to use. The first step is to add the source code for the parser to your project. There are many ways to do this, two of which are covered in this section.

#### Using the TreeSitterLanguages Swift Package

The easiest way to add a Tree-sitter parser to your project is by adding the [TreeSitterLanguages](https://github.com/simonbs/treesitterlanguages) Swift package. The package is used by the [Runestone Text Editor](https://apps.apple.com/us/app/runestone-editor/id1548193893) app and as such contains all languages supported by Runestone Text Editor.

TreeSitterLanguages contain three Swift packages for each language. These are detailed in the [README](https://github.com/simonbs/TreeSitterLanguages/blob/main/README.md) in the repository but at a high level they serve the following purposes.

|Name|Purpose|
|-|-|
|TreeSitter{Language}|The  C code for the generated Tree-sitter parser.|
|TreeSitter{Language}Queries|The queries to be used with the language, for example for highlighting text.|
|TreeSitter{Language}Runestone|Contains the Runestone bindings for the language. This is the only package you need to add to your project when using TreeSitterLanguages with Runestone as it depends on TreeSitter{Language} and TreeSitter{Language}Queries.|

You should also make sure to add the TreeSitterLanguagesCommon package to your project as it contains the basics needed for any language.

For more details on TreeSitterLanguages, refer to the [README](https://github.com/simonbs/TreeSitterLanguages/blob/main/README.md) in the repository.

> Important: The structure of the TreeSitterLanguages repository is likely to change in the future. It currently contains code copied from each of the Tree-sitter languages repositories. This is not ideal.

#### Manually Copying the Code

A Tree-sitter parser can be added to your project by manually copying the required source files to your project. The key files are covered previously in this article but they include `src/parser.c`, `src/tree_sitter/parser.h` and `queries/highlights.scm`.

A Tree-sitter parser is exposed as a C function with the name `tree_sitter_{language}`, like `tree_sitter_json` or `tree_sitter_javascript`. You will need to add the C definition for this function to your project. You can do this by creating a header file with the following contents and importing that in your bridging header.

```c
#ifdef __cplusplus
extern "C" {
#endif

typedef struct TSLanguage TSLanguage;

// Replace {language} with the name of the parser you are importing.
const TSLanguage *tree_sitter_{language}(void);

#ifdef __cplusplus
}
#endif
```

The [TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) package may serve as inspiration for how you can copy the files to your project.

## Using a Tree-sitter Parser with Runestone

After importing a Tree-sitter parser using the [TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) package, you can use the static property on <doc:TreeSitterLanguage> to create a language that can be passed to <doc:TextViewState> and pass that to <doc:TextView>.

```swift
let text = "let foo = \"Hello World\""
let state = TextViewState(text: text, language: .javaScript)
textView.setState(state)
```

If you have manually copied the source code for the Tree-sitter language into your project, you will need to manually create instances of <doc:TreeSitterLanguage/Query> and <doc:TreeSitterLanguage>.

```swift
let text = "let foo = \"Hello World\""
let highlightsQuery = TreeSitterLanguage.Query(contentsOf: "queries/highlights.scm")
let injectionsQuery = TreeSitterLanguage.Query(contentsOf: "queries/injections.scm")
let language = TreeSitterLanguage(tree_sitter_javascript(), highlightsQuery: highlightsQuery, injectionsQuery: injectionsQuery)
let state = TextViewState(text: text, language: language)
textView.setState(state)
```
