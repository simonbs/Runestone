#include "include/TreeSitterSupport.h"

// This proof deliberately uses the private structures of the pinned Tree-sitter
// submodule. Keep it conservative when updating that dependency. It neither
// changes trees nor replaces Tree-sitter's algorithm for structural changes.
#include "../../tree-sitter/lib/src/tree.h"

typedef struct {
    Subtree old_tree;
    Subtree new_tree;
} TreePair;

static bool points_equal(TSPoint left, TSPoint right) {
    return left.row == right.row && left.column == right.column;
}

static bool lengths_equal(Length left, Length right) {
    return left.bytes == right.bytes && points_equal(left.extent, right.extent);
}

bool runestone_trees_have_same_structure(const TSTree *old_tree, const TSTree *new_tree) {
    if (!old_tree || !new_tree || old_tree->language != new_tree->language ||
        old_tree->included_range_count != new_tree->included_range_count) {
        return false;
    }

    // Included-range changes are independently reported by the stock algorithm,
    // even when the resulting syntax trees would otherwise look identical.
    for (unsigned i = 0; i < old_tree->included_range_count; i++) {
        TSRange old_range = old_tree->included_ranges[i];
        TSRange new_range = new_tree->included_ranges[i];
        if (old_range.start_byte != new_range.start_byte || old_range.end_byte != new_range.end_byte ||
            !points_equal(old_range.start_point, new_range.start_point) ||
            !points_equal(old_range.end_point, new_range.end_point)) {
            return false;
        }
    }

    // Recovery and external scanner state have additional comparison semantics.
    // Leave them entirely to Tree-sitter, including when a subtree is shared.
    if (ts_subtree_error_cost(old_tree->root) || ts_subtree_error_cost(new_tree->root) ||
        ts_subtree_has_external_tokens(old_tree->root) || ts_subtree_has_external_tokens(new_tree->root)) {
        return false;
    }

    // Compare raw syntax nodes instead of expanding the visible cursor state.
    // Shared immutable repetition subtrees can be skipped altogether. Some
    // parsers rebuild repetition nodes, so also allow a bounded linear proof.
    // Different topology, deep trees, or excessive work simply use the fallback.
    enum { stack_capacity = 256, comparison_limit = 4000000 };
    TreePair pending[stack_capacity];
    unsigned pending_count = 1;
    unsigned comparisons = 0;
    pending[0] = (TreePair){old_tree->root, new_tree->root};
    while (pending_count > 0) {
        if (++comparisons > comparison_limit) {
            return false;
        }
        TreePair pair = pending[--pending_count];
        Subtree old = pair.old_tree;
        Subtree new = pair.new_tree;
        uint32_t child_count = ts_subtree_child_count(old);
        if (ts_subtree_symbol(old) != ts_subtree_symbol(new) ||
            ts_subtree_production_id(old) != ts_subtree_production_id(new) ||
            ts_subtree_parse_state(old) != ts_subtree_parse_state(new) ||
            ts_subtree_extra(old) != ts_subtree_extra(new) ||
            ts_subtree_visible(old) != ts_subtree_visible(new) ||
            ts_subtree_named(old) != ts_subtree_named(new) ||
            ts_subtree_missing(old) || ts_subtree_missing(new) ||
            ts_subtree_is_error(old) || ts_subtree_is_error(new) ||
            child_count != ts_subtree_child_count(new) ||
            !lengths_equal(ts_subtree_padding(old), ts_subtree_padding(new)) ||
            !lengths_equal(ts_subtree_size(old), ts_subtree_size(new))) {
            return false;
        }
        // Identical parent production IDs preserve the alias context of every
        // child. With identical geometry, shared immutable children need no scan.
        if (!old.data.is_inline && !new.data.is_inline && old.ptr == new.ptr) {
            continue;
        }
        if (child_count > stack_capacity - pending_count) {
            return false;
        }
        for (uint32_t i = 0; i < child_count; i++) {
            pending[pending_count++] = (TreePair){ts_subtree_children(old)[i], ts_subtree_children(new)[i]};
        }
    }

    // The edited old tree can retain has_changes markers even when every token,
    // alias and coordinate matches the new tree. The ordinary comparator then
    // descends to equivalent leaves and produces no range. The proof above does
    // the same without expanding shared hidden repetition subtrees into tokens.
    return true;
}
