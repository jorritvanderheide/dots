"""Orders the attributes in Nix files by docs/layout.md's "Ordering" rule.

Run by `nix fmt` before nixfmt, so the flake's treefmt check fails on a file
that is out of order. Rewrites the files it is given in place, and names any
set it had to leave alone on stderr, and then exits 1: a set it can't order
is one the check can't vouch for either.

Usage: nix-order.py FILE..."""

import sys
import warnings

import tree_sitter_nix as tsn
from tree_sitter import Language, Parser

warnings.simplefilter("ignore", DeprecationWarning)
PARSER = Parser(Language(tsn.language()))
ATTRSETS = ("attrset_expression", "rec_attrset_expression")
BINDINGS = ("binding", "inherit", "inherit_from")


class Skip(Exception):
    pass


def main():
    left_alone = False
    for path in sys.argv[1:]:
        src = open(path, "rb").read()
        tree = PARSER.parse(src)
        if tree.root_node.has_error:
            print(f"{path}: parse error, left alone", file=sys.stderr)
            left_alone = True
            continue
        ctx = {"src": src, "path": path, "left_alone": False}
        out = rewrite(tree.root_node, ctx)
        if out.encode() != src:
            open(path, "w").write(out)
        left_alone |= ctx["left_alone"]
    sys.exit(1 if left_alone else 0)


def text(node, ctx):
    return ctx["src"][node.start_byte : node.end_byte].decode()


def rewrite(node, ctx):
    """The node's source, with every attribute set and formals inside it
    reordered."""
    if node.type in ATTRSETS and not exempt(node, ctx):
        try:
            return rewrite_attrset(node, ctx)
        except Skip as e:
            if str(e) != "set on one line":
                print(
                    f"{ctx['path']}:{node.start_point[0] + 1}: {e}, left alone",
                    file=sys.stderr,
                )
                ctx["left_alone"] = True
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
    formals = [c for c in node.children if c.type == "formal"]
    if any(c.type == "comment" for c in node.children):
        return splice(node, ctx)
    ordered = sorted(
        formals, key=lambda f: text(f.child_by_field_name("name"), ctx).lower()
    )
    src, out, pos = ctx["src"], [], node.start_byte
    slot = iter(ordered)
    for child in node.children:
        out.append(src[pos : child.start_byte].decode())
        out.append(
            rewrite(next(slot), ctx) if child.type == "formal" else rewrite(child, ctx)
        )
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


def has_blocky(node):
    return node.type in BLOCKY or any(has_blocky(c) for c in node.children)


def is_block(item, body):
    """Multi-line, unless nixfmt only wrapped a plain value onto a second line."""
    if "\n" not in body:
        return False
    n = item["node"]
    if n.type != "binding":
        return True
    return has_blocky(n.child_by_field_name("expression"))


def rewrite_attrset(node, ctx):
    elems = list(elements(node))
    if not any(e.type in BINDINGS for e in elems):
        return splice(node, ctx)
    if node.start_point[0] == node.end_point[0]:
        raise Skip("set on one line")
    open_row = node.start_point[0]

    # Comment paragraphs before the first attribute that end in a blank line
    # are a note about the whole set; they stay on top.
    header, i = [], 0
    while i < len(elems) and elems[i].type == "comment":
        j = i
        while (
            j + 1 < len(elems)
            and elems[j + 1].type == "comment"
            and elems[j + 1].start_point[0] == elems[j].end_point[0] + 1
        ):
            j += 1
        nxt = elems[j + 1] if j + 1 < len(elems) else None
        if nxt is not None and nxt.start_point[0] > elems[j].end_point[0] + 1:
            header.append(elems[i : j + 1])
            i = j + 1
        else:
            break
    if any(c.start_point[0] == open_row for para in header for c in para):
        raise Skip("comment on the opening line")

    items, pending, last = [], [], None
    prev_end = header[-1][-1].end_point[0] if header else None
    for e in elems[i:]:
        if e.type == "comment":
            if (
                last is not None
                and not pending
                and e.start_point[0] == last["node"].end_point[0]
            ):
                last["trailing"] = e
            elif e.start_point[0] == open_row:
                raise Skip("comment on the opening line")
            else:
                pending.append(e)
            continue
        if last is not None and e.start_point[0] == last["node"].end_point[0]:
            raise Skip("two attributes on one line")
        rows = [c.start_point[0] for c in pending] + [e.start_point[0]]
        ends = [c.end_point[0] for c in pending]
        if any(rows[k + 1] != ends[k] + 1 for k in range(len(pending))):
            raise Skip("comment separated from its attribute by a blank line")
        first_row = (pending[0] if pending else e).start_point[0]
        before = last["trailing"] or last["node"] if last else None
        gap = (
            first_row
            - (
                before.end_point[0]
                if before
                else (prev_end if prev_end is not None else open_row)
            )
            > 1
        )
        last = {"node": e, "leading": pending, "trailing": None, "gap": gap}
        items.append(last)
        pending = []
    footer = pending
    if (
        footer
        and footer[0].start_point[0]
        == (items[-1]["trailing"] or items[-1]["node"]).end_point[0] + 1
    ):
        raise Skip("comment right after the last attribute")

    first = (
        header[0][0]
        if header
        else (items[0]["leading"][0] if items[0]["leading"] else items[0]["node"])
    )
    end = footer[-1] if footer else (items[-1]["trailing"] or items[-1]["node"])
    line_start = ctx["src"].rfind(b"\n", 0, first.start_byte) + 1
    indent = ctx["src"][line_start : first.start_byte].decode()
    if indent.strip():
        raise Skip("attribute not at the start of its line")

    keys = [key(it, ctx) for it in items]
    heads = [k.split(".")[0] for k in keys]
    module = {"imports", "options", "config"} & set(heads)
    module = "config" in module and len(module) > 1

    units = []
    for it, k in zip(items, keys):
        body = rewrite(it["node"], ctx)
        block = is_block(it, body)
        if it["trailing"]:
            gap = ctx["src"][it["node"].end_byte : it["trailing"].start_byte].decode()
            body += gap + text(it["trailing"], ctx)
        lead = [text(c, ctx) for c in it["leading"]]
        if it["node"].type != "binding":
            rank = 0
        elif k == "enable":
            rank = 1
        elif module and k.split(".")[0] in ("imports", "options", "config"):
            rank = 2
        else:
            rank = 3
        member = {"key": k.lower(), "body": body}
        # A comment covers the run of plain one-liners directly below it.
        prev = units[-1] if units else None
        if (
            prev is not None
            and prev["group"]
            and rank == 3
            and not lead
            and not block
            and not it["gap"]
        ):
            prev["members"].append(member)
            continue
        units.append(
            {
                "lead": lead,
                "members": [member],
                "block": block,
                "commented": bool(lead),
                "group": bool(lead) and not block and rank == 3,
                "rank": rank,
                "order": ("imports", "options", "config").index(k.split(".")[0])
                if rank == 2
                else 99,
                "pos": len(units),
            }
        )

    for u in units:
        u["members"].sort(key=lambda m: m["key"])
        u["key"] = u["members"][0]["key"]
        u["lines"] = u["lead"] + [m["body"] for m in u["members"]]

    def by_name(u):
        return (u["order"], u["key"], u["pos"])

    leading = sorted(
        (u for u in units if u["rank"] < 2), key=lambda u: (u["rank"], u["pos"])
    )
    # A module's imports, options and config keep that order whatever their
    # length: all three go with the multi-line attributes, ahead of them.
    singles = sorted(
        (u for u in units if u["rank"] == 3 and not u["block"]), key=by_name
    )
    blocks = sorted(
        (u for u in units if u["rank"] == 2 or (u["rank"] == 3 and u["block"])),
        key=by_name,
    )

    sep = "\n" + indent
    out = []
    for para in header:
        out.append(("\n" + sep if out else "") + sep.join(text(c, ctx) for c in para))
    head = leading + singles
    for n, u in enumerate(head):
        piece = sep.join(u["lines"])
        prev = head[n - 1] if n else None
        if prev is None:
            out.append(("\n" + sep if out else "") + piece)
        elif u["commented"] or prev["commented"] or prev["block"] or u["block"]:
            out.append("\n" + sep + piece)
        else:
            out.append(sep + piece)
    for u in blocks:
        out.append(("\n" + sep if out else "") + sep.join(u["lines"]))
    if footer:
        out.append("\n" + sep + sep.join(text(c, ctx) for c in footer))

    src = ctx["src"]
    return (
        src[node.start_byte : first.start_byte].decode()
        + "".join(out)
        + src[end.end_byte : node.end_byte].decode()
    )


def key(item, ctx):
    n = item["node"]
    if n.type != "binding":
        return "inherit"
    return text(n.child_by_field_name("attrpath"), ctx).replace('"', "")


if __name__ == "__main__":
    main()
