# Knitting Projects Markdown Format

The knitting projects file lives at `../knitting/projects.md` relative to the site root.

---

## Structure

The file is a sequence of **project blocks**, separated by `---`.

Each block must contain exactly these three fields, in any order:

```
## Project Name

description: A short description of the project.
images: path/to/image/folder
```

### Fields

| Field | Description |
|---|---|
| `## <name>` | H2 heading — the project title. Required, must be unique. |
| `description:` | One-line description shown beneath the title. Required. |
| `images:` | Path to a folder of images, relative to the `../knitting/` directory. Required. |

---

## Full Example

```markdown
## Cozy Cable Sweater

description: A chunky Aran-weight pullover with classic cable panels down the front.
images: photos/cable-sweater

---

## Colorwork Mittens

description: Stranded colorwork mittens in a snowflake motif, worked in the round.
images: photos/colorwork-mittens

---

## Lace Shawl

description: A crescent shawl with a delicate leaf border, blocked to open up the lace.
images: photos/lace-shawl
```

---

## Rules

- Separate every project with `---` on its own line.
- The `##` heading is the only heading level used for project titles.
- `description:` and `images:` values are on the same line as the key.
- The `images:` path is relative to the `../knitting/` directory (i.e. `../knitting/<images path>`).
- The image folder may contain `.jpg`, `.jpeg`, `.png`, `.gif`, or `.webp` files.
- Blank lines between fields are fine and encouraged for readability.
- Do not use other heading levels (`#`, `###`, etc.) in the file.
