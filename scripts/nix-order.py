"""Orders the attributes in Nix files by docs/layout.md's "Ordering" rule.

Run by `nix fmt` before nixfmt, so the flake's treefmt check fails on a file
that is out of order. Rewrites the files it is given in place. A set with a
comment that belongs to no attribute is named on stderr and left alone, and
the exit status is then 1: the check can't vouch for it either.

Usage: nix-order.py FILE..."""

import sys
import warnings
from itertools import pairwise

import tree_sitter_nix as tsn
from tree_sitter import Language, Parser

warnings.simplefilter("ignore", DeprecationWarning)
PARSER = Parser(Language(tsn.language()))
ATTRSETS = ("attrset_expression", "rec_attrset_expression")
BINDINGS = ("binding", "inherit", "inherit_from")
MODULE = ("imports", "options", "config")

# A value with one of these is a block. Any other value is a line, even one
# nixfmt wrapped, so an attribute doesn't move with the width of its value.
BLOCKY = (
    "attrset_expression",
    "rec_attrset_expression",
    "list_expression",
    "indented_string_expression",
    "function_expression",
    "let_expression",
    "if_expression",
    "with_expression",
)


class Skip(Exception):
    pass


def main():
    failed = False
    for path in sys.argv[1:]:
        with open(path, "rb") as f:
            src = f.read()
        tree = PARSER.parse(src)
        if tree.root_node.has_error:
            print(f"{path}: parse error, left alone", file=sys.stderr)
            failed = True
            continue
        ctx = {"src": src, "path": path, "failed": False}
        out = rewrite(tree.root_node, ctx)
        if out.encode() != src:
            with open(path, "w") as f:
                f.write(out)
        failed |= ctx["failed"]
    sys.exit(1 if failed else 0)


def text(node, ctx):
    return ctx["src"][node.start_byte : node.end_byte].decode()


def rewrite(node, ctx):
    """The node's source, with every attribute set and formals inside it
    reordered."""
    if node.type in ATTRSETS and not exempt(node, ctx):
        try:
            return rewrite_attrset(node, ctx)
        except Skip as e:
            print(
                f"{ctx['path']}:{node.start_point[0] + 1}: {e}, left alone",
                file=sys.stderr,
            )
            ctx["failed"] = True
    if node.type == "formals":
        return rewrite_formals(node, ctx)
    return splice(node, ctx)


def splice(node, ctx):
    """The node's source with each child replaced by its rewrite."""
    src, out, pos = ctx["src"], [], node.start_byte
    for child in node.children:
        out.append(src[pos : child.start_byte].decode())
        out.append(rewrite(child, ctx))
        pos = child.end_byte
    out.append(src[pos : node.end_byte].decode())
    return "".join(out)


def exempt(node, ctx):
    """mkOption's arguments keep nixpkgs' order."""
    parent = node.parent
    if parent is not None and parent.type == "apply_expression":
        fn = parent.child_by_field_name("function")
        if fn is not None and text(fn, ctx).split(".")[-1] == "mkOption":
            return True
    return False


def rewrite_formals(node, ctx):
    """Function arguments alphabetical; `...` stays where it is."""
    formals = [c for c in node.children if c.type == "formal"]
    if any(c.type == "comment" for c in node.children):
        return splice(node, ctx)
    ordered = iter(
        sorted(formals, key=lambda f: text(f.child_by_field_name("name"), ctx).lower())
    )
    src, out, pos = ctx["src"], [], node.start_byte
    for child in node.children:
        out.append(src[pos : child.start_byte].decode())
        out.append(rewrite(next(ordered) if child.type == "formal" else child, ctx))
        pos = child.end_byte
    out.append(src[pos : node.end_byte].decode())
    return "".join(out)


def elements(node):
    """Bindings and comments between the braces, in source order."""
    for child in node.children:
        if child.type == "binding_set":
            yield from child.children
        elif child.type in BINDINGS or child.type == "comment":
            yield child


def paragraphs(nodes):
    """The nodes split where a blank line sits between two of them."""
    out = []
    for n in nodes:
        if out and n.start_point[0] == out[-1][-1].end_point[0] + 1:
            out[-1].append(n)
        else:
            out.append([n])
    return out


def has_blocky(node):
    return node.type in BLOCKY or any(has_blocky(c) for c in node.children)


def key(node, ctx):
    if node.type != "binding":
        return "inherit"
    return text(node.child_by_field_name("attrpath"), ctx).replace('"', "").lower()


def rewrite_attrset(node, ctx):
    elems = list(elements(node))
    # A set on one line has one attribute after nixfmt, which expands any
    # other.
    if node.start_point[0] == node.end_point[0] or not any(
        e.type in BINDINGS for e in elems
    ):
        return splice(node, ctx)
    open_row = node.start_point[0]

    # Each unit is an attribute with the comments directly above it, and a
    # trailing one on its last line. Comment paragraphs before the first
    # attribute, set off by a blank line, are a header about the whole set.
    header, units, pending = [], [], []
    for e in elems:
        if e.type == "comment":
            if e.start_point[0] == open_row:
                raise Skip("comment on the opening line")
            if units and not pending and e.start_point[0] == units[-1]["end"]:
                units[-1]["trailing"] = e
                units[-1]["end"] = e.end_point[0]
            else:
                pending.append(e)
            continue
        *rest, lead = paragraphs(pending + [e])
        if rest and units:
            raise Skip("comment that belongs to no attribute")
        header = rest
        units.append(
            {"node": e, "lead": lead[:-1], "trailing": None, "end": e.end_point[0]}
        )
        pending = []
    if pending:
        raise Skip("comment after the last attribute")

    first = header[0][0] if header else (units[0]["lead"] or [units[0]["node"]])[0]
    last = units[-1]["trailing"] or units[-1]["node"]
    line_start = ctx["src"].rfind(b"\n", 0, first.start_byte) + 1
    indent = ctx["src"][line_start : first.start_byte].decode()
    if indent.strip():
        raise Skip("attribute not at the start of its line")

    heads = {key(u["node"], ctx).split(".")[0] for u in units}
    module = "config" in heads and len(heads & set(MODULE)) > 1
    for pos, u in enumerate(units):
        n = u["node"]
        k = key(n, ctx)
        head = k.split(".")[0]
        if n.type != "binding":
            u["rank"] = 0
        elif k == "enable":
            u["rank"] = 1
        elif module and head in MODULE:
            u["rank"] = 2
        else:
            u["rank"] = 3
        u["order"] = MODULE.index(head) if u["rank"] == 2 else len(MODULE)
        u["block"] = n.start_point[0] != n.end_point[0] and (
            n.type != "binding" or has_blocky(n.child_by_field_name("expression"))
        )
        u["spaced"] = u["rank"] == 2 or u["block"] or bool(u["lead"])
        u["key"] = (u["order"], k, pos)

    # inherit, then enable, lead the set in their own order; then the bare
    # lines, packed; then the paragraphs, a blank line between each.
    leading = sorted((u for u in units if u["rank"] < 2), key=lambda u: u["rank"])
    bare = sorted((u for u in units if u["rank"] == 3 and not u["spaced"]), key=key_of)
    spaced = sorted((u for u in units if u["rank"] >= 2 and u["spaced"]), key=key_of)

    sep = "\n" + indent
    chunks = [(sep.join(text(c, ctx) for c in p), True) for p in header]
    chunks += [(render(u, ctx, sep), u["spaced"]) for u in leading + bare + spaced]
    out = chunks[0][0]
    for (_, before), (piece, spaced) in pairwise(chunks):
        out += ("\n" + sep if before or spaced else sep) + piece

    src = ctx["src"]
    return (
        src[node.start_byte : first.start_byte].decode()
        + out
        + src[last.end_byte : node.end_byte].decode()
    )


def key_of(unit):
    return unit["key"]


def render(unit, ctx, sep):
    body = rewrite(unit["node"], ctx)
    if unit["trailing"]:
        gap = ctx["src"][unit["node"].end_byte : unit["trailing"].start_byte].decode()
        body += gap + text(unit["trailing"], ctx)
    return sep.join([text(c, ctx) for c in unit["lead"]] + [body])


if __name__ == "__main__":
    main()
