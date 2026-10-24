# Publishing the source on GitHub

Everything the repository needs is already in place. This is the short checklist of what to do, in
order, and what to replace with your own account name.

---

## 0. What is already prepared

| File | Purpose |
|---|---|
| [LICENSE](LICENSE) | GNU GPL v3.0, verbatim upstream text (674 lines) |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | Godot (MIT) + the three OFL fonts, so the license story is complete |
| [.gitignore](.gitignore) | Excludes `build/`, `release/`, `.build/`, `.godot/` and logs |
| [.gitattributes](.gitattributes) | Normalizes line endings to LF, so Windows/Linux CI agree |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Architecture conventions, test gate, PR process |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Short, enforceable, no committee theatre |
| [SECURITY.md](SECURITY.md) | What is actually in scope for an offline game |
| [.github/workflows/tests.yml](.github/workflows/tests.yml) | Runs all ten headless suites on every push and PR |
| [.github/workflows/export-windows.yml](.github/workflows/export-windows.yml) | Builds the Windows zip on release tags |
| Issue forms and PR template | Structured bug reports, feature requests, review checklist |

All badges, issue-template links and the README header already point at **github.com/r48n34/riftward**
and **r48n34.itch.io/riftward**, so there is nothing left to rename.

---

## 1. The repository

Already created and empty at <https://github.com/r48n34/riftward>, and this folder already has it as
`origin`. If you ever recreate it, keep it **empty** — no README, no .gitignore, no license — because
those files already exist here, and an initialized remote forces a merge on the first push.

---

## 2. First commit and push

The local repository is ready: branch `main`, one commit, `origin` already configured. Push it:

```powershell
cd D:\godotGa\game
git push -u origin main
```

If `git log` ever reports that the branch has no commits while the files are still present, re-create
the commit — safe, because nothing has been pushed yet:

```powershell
git add -A
git commit -m "RIFTWARD 0.1.0 - initial source release"
```

That exact state occurred once here: `origin` was configured and a fetch had run, but the local commit
and index were gone. Re-committing restored it in one step; the working tree was never at risk.

**Check before pushing** — these must all be true:

```powershell
git ls-files | Measure-Object -Line          # 477 tracked files, not tens of thousands
git ls-files | Select-String -Pattern '^(build|release|\.build|\.godot)/'   # must print nothing
git ls-files | Select-String -Pattern '\.(exe|pck|tpz)$'                    # must print nothing
```

The last two are the ones that matter: a committed `RIFTWARD.exe` would put a 104 MB binary in history
permanently, and GitHub rejects files over 100 MB.

### Safety check before pushing

Run these four checks. All four should come back clean.

```powershell
# 1. Credentials or private keys in tracked files
#    (LICENSE and this guide contain the search words themselves, so both are excluded)
git grep -n -I -i -E "password|api[_-]?key|access[_-]?token|BEGIN [A-Z ]*PRIVATE KEY|ghp_|AKIA" -- . ":(exclude)LICENSE" ":(exclude)docs/GITHUB.md"

# 2. Home-directory paths, which leak your Windows account name
git grep -n -I -F "C:\Users\" -- . ":(exclude)docs/GITHUB.md"

# 3. The author identity that will be public on every commit
git log --format="%an <%ae>"

# 4. Nothing generated is about to be shipped
git status --porcelain --ignored
```

If step 3 shows an address you would rather not publish, switch to GitHub's noreply address (copy the
exact one from Settings -> Emails) and amend. This is safe only before the first push; afterwards it
needs a force push and rewrites shared history.

```powershell
git config user.email "YOUR_ID+USERNAME@users.noreply.github.com"
git commit --amend --reset-author --no-edit
```

What this repository currently passes: no credentials, no `C:\Users\...` paths, no save files or logs,
no `.env`/keystore/private-key files, largest tracked file 1.24 MB, and exactly five ignored entries
(`.build/`, `.godot/`, `build/`, `release/`, `tests/artifacts/logs/`).

---

## 3. Fill in the repository metadata

On the repo page, click the gear next to **About**:

| Field | Suggested value |
|---|---|
| Description | `Single-player first-person extraction shooter built in Godot 4.7. Fighting, looting and extracting on a seeded alien frontier.` |
| Website | your itch.io URL |
| Topics | `godot` `godot-engine` `gdscript` `fps` `first-person` `extraction-shooter` `procedural-generation` `single-player` `game` |

Topics are how people find Godot projects on GitHub; the first three do most of the work.

---

## 4. Verify the license and the first CI run

- The repo sidebar should show **GPL-3.0 license**. If it shows "Unknown", the license file was not
  pushed or was renamed — it must be `LICENSE` at the root.
- Open the **Actions** tab. `headless-tests` starts on the first push. It downloads Godot 4.7.2, imports
  the project and runs all ten suites.

The workflow was written against the same commands that pass locally (`tests/run_all.ps1`), but it has
**not been executed on GitHub's runners yet**. Watch the first run; the most likely snags:

| Symptom | Cause | Fix |
|---|---|---|
| `godot: command not found` | cache restored without binary | clear the Actions cache, re-run |
| Import step slow or noisy | first import writes `.godot/` | it is ignored and disposable; `--import` is idempotent |
| UI suite fails only on CI | font rendering in headless | confirm your local run also uses `--headless` |
| Total time > 30 min | cold cache + ten suites | raise `timeout-minutes`, or split jobs |

---

## 5. Protect `main` (optional but recommended)

Settings → Branches → **Add branch protection rule** for `main`:

- Require a pull request before merging.
- Require status checks to pass: `Headless suites (Linux)`.
- Disallow force pushes.

Solo projects can skip this; it matters the moment someone else sends a PR.

---

## 6. Tag the first release

A tag is what makes a version linkable from the itch page, and the `export-windows` workflow uses it to
build and attach the zip.

```powershell
git tag -a v0.1.0 -m "RIFTWARD 0.1.0 - first public build"
git push origin v0.1.0
```

Then GitHub → **Releases** → **Draft a new release**:

- Tag: `v0.1.0`
- Title: `RIFTWARD 0.1.0`
- Description: paste the body of `docs/STORE_PAGE.md` (or a short version), plus
  `Windows 10/11, DirectX 12 GPU. Unzip and run RIFTWARD.exe.`
- Publish. The action attaches `RIFTWARD-win64.zip` and `SHA256SUMS.txt` automatically; if the workflow
  failed, upload them by hand.

GitHub also offers **Source code (zip)** on every release — that is your GPL source distribution, no
extra work.

---

## 7. GPL-3.0 obligations (read this once)

You chose GPL-3.0, which has one practical consequence: **whenever you distribute a compiled build, you
must make the corresponding source available.**

- Publishing the source here satisfies that — as long as the build you ship matches the tagged source.
- Add a link to this repository on your itch.io page and in the game's README inside the zip. Something
  like: `Source code (GPL-3.0): https://github.com/<your-user>/riftward`
- If you ever ship a build from modified, uncommitted source, the repo no longer corresponds to the
  binary. Commit the change and tag it before publishing that build.
- You cannot add a license restriction that forbids redistribution; anyone who receives your build may
  also redistribute the source under GPL-3.0.
- Commercial use, including paid distribution, is allowed under GPL-3.0. You are not giving away the
  right to sell the game.

Full obligations: sections 4–6 of [LICENSE](LICENSE).

---

## 8. Things that will bite you later

- **Never commit build output.** `build/`, `release/`, `.build/`, `.godot/` are ignored. If someone runs
  `git add -f build/`, history gets a 100 MB+ blob that is painful to remove (`git filter-repo`).
- **Line endings.** `.gitattributes` forces LF in the repo and lets Git check out native endings. Do not
  remove it on Windows; the CI suites and `.gd` scripts assume consistent newlines.
- **Absolute paths.** `docs/TECHNICAL.md` and README examples reference `D:\godotGa\game`. That's fine
  in docs, but never let a runtime script depend on it — the game must run from any path.
- **The `.uid` files are intentional.** Godot 4.4+ writes `*.gd.uid`; commit them so scene references
  stay stable across machines.
- **Godot's `.godot/` is disposable.** Never commit it, never ship it; it regenerates on import.
- **Binary assets in the repo** (~2.5 MB of preview/QA PNGs) are deliberate: the README and docs link to
  them. If the repo grows, move them to an `artifacts` release rather than deleting the references.
