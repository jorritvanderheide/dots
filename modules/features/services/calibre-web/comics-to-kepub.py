"""Give comics in the calibre library a KEPUB that Kobo sync can send.

Kobo sync only offers EPUB/KEPUB. KCC turns a CBZ into a fixed-layout KEPUB
sized for the Kobo Clara Colour. AZW3 needs a detour first, since calibre's
own AZW3 -> EPUB conversion mangles image-only books: AZW3 -> EPUB (calibre,
only to get at the pages) -> CBZ (page images in spine order) -> KCC.

Every CBZ is converted. AZW3 is mostly prose, so it's only converted when
tagged `manga` or `comic`. Reading direction comes from the book itself where
it records one (AZW3 does), and otherwise from the tag: `manga` means
right-to-left. A book whose conversion fails is tagged `kepub-failed` so the
timer doesn't retry it every run; remove that tag to retry.
"""

import json
import posixpath
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from urllib.parse import unquote

LIBRARY = sys.argv[1]
MANGA_TAG = "manga"
COMIC_TAG = "comic"
FAILED_TAG = "kepub-failed"

SEARCH = (
    f'(formats:"=cbz" or (formats:"=azw3" and (tags:"={MANGA_TAG}" or tags:"={COMIC_TAG}")))'
    f' and not formats:"=kepub" and not tags:"={FAILED_TAG}"'
)

CONTAINER_NS = "{urn:oasis:names:tc:opendocument:xmlns:container}"
OPF_NS = {"opf": "http://www.idpf.org/2007/opf"}
IMAGE_REF = re.compile(r'<(?:img|image)\b[^>]*?\b(?:src|xlink:href)="([^"]+)"')


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def calibredb(*args):
    return run("calibredb", "--library-path", LIBRARY, *args)


def epub_pages(epub):
    """Return [(name, data)] for each page image in reading order, and the
    spine's page-progression-direction (None if unset)."""
    with zipfile.ZipFile(epub) as z:
        container = ET.fromstring(z.read("META-INF/container.xml"))
        opf_path = container.find(f".//{CONTAINER_NS}rootfile").get("full-path")
        opf = ET.fromstring(z.read(opf_path))
        base = posixpath.dirname(opf_path)
        manifest = {
            item.get("id"): posixpath.join(base, unquote(item.get("href")))
            for item in opf.iterfind("opf:manifest/opf:item", OPF_NS)
        }

        pages = []
        for itemref in opf.iterfind("opf:spine/opf:itemref", OPF_NS):
            # calibre prepends its own title page showing the metadata cover,
            # which comics already have as their first page. It's usually a
            # separately scaled copy, so it can't be deduplicated by content.
            if itemref.get("idref") == "titlepage":
                continue
            page = manifest[itemref.get("idref")]
            html = z.read(page).decode("utf-8", "replace")
            # Each image once per page: Kindle Panel View (as KCC writes it)
            # repeats the page image in four magnification regions.
            for src in dict.fromkeys(IMAGE_REF.findall(html)):
                name = posixpath.normpath(
                    posixpath.join(posixpath.dirname(page), unquote(src))
                )
                pages.append((name, z.read(name)))
        direction = opf.find("opf:spine", OPF_NS).get("page-progression-direction")
    return pages, direction


def azw3_to_cbz(azw3, work):
    epub = work / "book.epub"
    run("ebook-convert", azw3, str(epub))

    # AZW3 records the direction (EXTH 527), and calibre carries it through
    # to the EPUB's spine.
    pages, direction = epub_pages(epub)
    if not pages:
        raise RuntimeError("no page images found")

    cbz = work / "book.cbz"
    with zipfile.ZipFile(cbz, "w", zipfile.ZIP_STORED) as z:
        for count, (name, data) in enumerate(pages, start=1):
            z.writestr(f"{count:04d}{posixpath.splitext(name)[1]}", data)
    return str(cbz), direction


def convert(book, work):
    formats = {Path(f).suffix.lower(): f for f in book["formats"]}
    if ".cbz" in formats:
        cbz, direction = formats[".cbz"], None
    else:
        cbz, direction = azw3_to_cbz(formats[".azw3"], work)
    rtl = direction == "rtl" if direction else MANGA_TAG in book["tags"]

    out = work / "out"
    out.mkdir()
    run(
        "kcc-c2e",
        "--profile",
        "KoCC",
        *(["--manga-style"] if rtl else []),
        "--forcecolor",
        "--format",
        "EPUB",
        "--title",
        book["title"],
        "--author",
        book["authors"],
        "--output",
        str(out),
        cbz,
    )
    (result,) = out.glob("*.epub")

    # The extension is what makes calibre file this as KEPUB rather than EPUB.
    kepub = result.rename(work / "book.kepub")
    calibredb("add_format", str(book["id"]), str(kepub))


def main():
    books = json.loads(
        calibredb(
            "list",
            "--for-machine",
            "--fields",
            "title,authors,tags,formats",
            "--search",
            SEARCH,
        )
    )
    for book in books:
        print(f"Converting {book['id']}: {book['title']}", flush=True)
        try:
            with tempfile.TemporaryDirectory() as work:
                convert(book, Path(work))
        except Exception as e:
            detail = e.stderr if isinstance(e, subprocess.CalledProcessError) else e
            print(f"Failed {book['id']}: {detail}", file=sys.stderr, flush=True)
            calibredb(
                "set_metadata",
                str(book["id"]),
                "--field",
                f"tags:{','.join([*book['tags'], FAILED_TAG])}",
            )


main()
