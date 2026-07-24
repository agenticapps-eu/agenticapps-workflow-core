# Publishing the cheatsheet on GitHub (agenticapps-eu)

The cheatsheet is a **single self-contained HTML file** (no external CSS/JS/fonts/images),
so it drops onto GitHub Pages as-is. First, the thing to know about "the org root":

## There are TWO different "org roots"

| What you visit | What controls it | Renders the HTML cheatsheet? |
|---|---|---|
| **github.com/agenticapps-eu** — the GitHub org page | a repo named **`.github`** with `profile/README.md` | No — Markdown only; show it as an **image linking to the live page** |
| **agenticapps-eu.github.io** — the org's Pages website | a repo named **`agenticapps-eu.github.io`** with `index.html` | Yes — a real web page; renders the full interactive cheatsheet |

So you can have both: the interactive cheatsheet **as the org's website root**, and an
**image of it on the GitHub org landing page** that links to that website.

---

## Surface 1 — Pages in `agenticapps-workflow-core` (what you asked for)

Publishes at **`https://agenticapps-eu.github.io/agenticapps-workflow-core/`**.
Recommended: use the GitHub Action below (auto-regenerates the PNG). Manual branch method:

```bash
mkdir -p docs && cp publish/index.html docs/index.html && cp publish/cheatsheet.png docs/cheatsheet.png
git add docs && git commit -m "docs: publish workflow cheatsheet to Pages" && git push
# Settings -> Pages -> Deploy from a branch -> main / docs
```

## Surface 2 — the GitHub org landing page (github.com/agenticapps-eu)

Create the special **`.github`** repo (public) and add the profile README:

```bash
gh repo create agenticapps-eu/.github --public -y
cd .github && mkdir -p profile
cp ../agenticapps-workflow-core/publish/org-profile-README.md profile/README.md
git add profile && git commit -m "org profile: workflow cheatsheet" && git push
```
Now https://github.com/agenticapps-eu shows the cheatsheet image (pulled from the Pages URL
in Surface 1) linking to the interactive page.

## Surface 3 — make the cheatsheet the org's website root (agenticapps-eu.github.io)

```bash
gh repo create agenticapps-eu/agenticapps-eu.github.io --public -y
cd agenticapps-eu.github.io
cp ../agenticapps-workflow-core/publish/index.html index.html
git add index.html && git commit -m "org site: workflow cheatsheet" && git push
# Settings -> Pages -> main / (root)
```
Live at **`https://agenticapps-eu.github.io/`** — the org's root website is the cheatsheet.

---

## Auto-deploy with GitHub Actions (never drifts)  ← recommended for Surface 1

The workflow at `.github/workflows/pages-cheatsheet.yml` + `scripts/render-cheatsheet.mjs`
are already in this repo. They publish the cheatsheet and **regenerate its PNG from the HTML
on every push**, so the live page and the org-README image stay in lockstep.

One-time: **Settings -> Pages -> Source = "GitHub Actions"**. After that:
- Edit **`publish/index.html`** (the source of truth) and push to `main` → auto-redeploys
  `https://agenticapps-eu.github.io/agenticapps-workflow-core/` and regenerates `cheatsheet.png`.
- There is a manual **"Run workflow"** button (`workflow_dispatch`) too.
- `docs/WORKFLOW.md` is in the trigger `paths`, so a workflow-doc change alone also redeploys.

Note: the cheatsheet HTML is hand-authored (not auto-generated from `docs/WORKFLOW.md`). When
the workflow itself changes, update both and push — the Action handles Pages + the PNG.
(Want the org-root site `agenticapps-eu.github.io` auto-synced from the same push? That's a
cross-repo deploy needing a small PAT — ask and I'll add it.)

> ⚠️ These pages are **public** once Pages is enabled and the repos are public. Nothing in
> the cheatsheet is sensitive (no cParx specifics, no secrets), but confirm before publishing.

## One-shot: let Claude Code do it
> Publish `publish/index.html` to GitHub Pages for `agenticapps-eu`. (1) enable the Actions
> workflow already in `.github/workflows/pages-cheatsheet.yml` (set Pages Source = GitHub
> Actions); (2) create public `agenticapps-eu/.github` with `profile/README.md` from
> `publish/org-profile-README.md`; (3) create public `agenticapps-eu/agenticapps-eu.github.io`
> with `index.html` = the cheatsheet. Use `gh`. Report each live URL. Confirm before making
> any repo public.
