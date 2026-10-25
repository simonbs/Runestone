# Tree-sitter runtime

This directory contains the unmodified C runtime from [Tree-sitter v0.27.1](https://github.com/tree-sitter/tree-sitter/releases/tag/v0.27.1), commit `10eb5ac119eec9cb4267a8e035066473983f5f3a`.

Upstream [removed its Swift package manifest](https://github.com/tree-sitter/tree-sitter/pull/5849). Runestone builds the runtime as the `TreeSitter` target, exposing only `include/tree_sitter/api.h`. The private parser headers must not be exposed to Swift: languages are opaque pointers, and each generated grammar must compile against its own matching private header.

The upstream MIT license is in `LICENSE`; the Unicode dependency's license remains in `src/unicode/LICENSE`. Grammar ABI versions 13 through 15 are supported.

To update, clone the desired upstream release, replace `src` and `include` with the complete upstream `lib/src` and `lib/include` directories, copy the root `LICENSE`, and update the version and commit above. Compile only `src/lib.c`, which includes the other runtime sources. Run Runestone's simulator tests, build the example, and run TreeSitterLanguages' runtime compatibility checks before merging.

The `TreeSitter` product is available to consumers needing the C API. Use this product instead of linking a second copy of the Tree-sitter runtime into the same application.
