import glob

matches = glob.glob("**/editbooks.py", recursive=True)
if not matches:
    raise SystemExit("editbooks.py not found")
path = matches[0]

with open(path, "r") as f:
    content = f.read()

target = "                db_book, input_authors, title_dir = create_book_on_upload(modify_date, meta)\n\n                # Comments need book id"
replacement = """                db_book, input_authors, title_dir = create_book_on_upload(modify_date, meta)

                # Tag book with uploader's username
                username_tag = calibre_db.session.query(db.Tags).filter(db.Tags.name == current_user.name).first()
                if not username_tag:
                    username_tag = db.Tags(name=current_user.name)
                    calibre_db.session.add(username_tag)
                if username_tag not in db_book.tags:
                    db_book.tags.append(username_tag)
                modify_date = True

                # Comments need book id"""

if target not in content:
    raise SystemExit("Patch target not found — calibre-web source may have changed")

with open(path, "w") as f:
    _ = f.write(content.replace(target, replacement))
