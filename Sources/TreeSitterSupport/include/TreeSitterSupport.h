#ifndef RUNESTONE_TREE_SITTER_SUPPORT_H
#define RUNESTONE_TREE_SITTER_SUPPORT_H

#include <stdbool.h>
#include <tree_sitter/api.h>

/// A conservative proof of identical syntax structure, not a comparison of text.
/// False means callers must use Tree-sitter's ordinary changed-range algorithm.
bool runestone_trees_have_same_structure(const TSTree *old_tree, const TSTree *new_tree);

#endif
