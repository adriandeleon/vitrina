# Vitrina

The apt repository for Editora, Termina, Torrenta, Mirada, Nux, Modula and jkit, served at
<https://vitrina-project.dev>.

Nothing is committed here but the list of apps and the builder. Every build downloads the `.deb`
files from each app's latest GitHub release, rebuilds the repository from scratch, signs it with
the release key, and deploys it to GitHub Pages.

```
apps.txt                       the app repositories to publish
scripts/fetch-debs.sh          downloads each app's latest .deb files
scripts/build-apt.sh           lays out pool/ and dists/, writes and signs the index
site/                          the landing page, copied to the site root
ci/notify-vitrina.yml          copy into each app's .github/workflows/
.github/workflows/publish.yml  builds and deploys
```

The published site:

```
/vitrina.asc                   public key
/apt/dists/stable/InRelease    signed index
/apt/pool/main/e/editora/editora_0.27.0_amd64.deb
```

## When it rebuilds

- An app's release finishes (`repository_dispatch`, sent by `ci/notify-vitrina.yml`)
- Daily at 06:43 UTC, in case a notification was missed
- A push to `main` that changes the app list, the site or the scripts
- By hand, from the Actions tab

If any app's latest release has no `.deb`, the build fails and the previous deployment stays up,
so an app never vanishes from the repository because of one bad release.

## Adding an app

1. Add its `owner/repo` to `apps.txt`.
2. Copy `ci/notify-vitrina.yml` to its `.github/workflows/` and give it the `VITRINA_TOKEN` secret.
3. Add it to the table in `site/index.html`.

The `.deb` must be for `amd64`, `arm64` or `all`, and its `Package` name must be unique.

## Secrets

| Repository | Secret | What |
|---|---|---|
| vitrina | `LINUX_GPG_KEY` | the release key, `gpg --armor --export-secret-keys 8486A7AF4FC8FEE93D83CDB4EA5FA138C2C09C4A` |
| vitrina | `LINUX_GPG_PASSPHRASE` | its passphrase |
| each app | `VITRINA_TOKEN` | fine-grained token, Contents read/write on `adriandeleon/vitrina` |

## Building locally

```bash
scripts/fetch-debs.sh apps.txt debs
mkdir -p public && cp -r site/. public/
SIGNING_KEY=8486A7AF4FC8FEE93D83CDB4EA5FA138C2C09C4A scripts/build-apt.sh debs public
python3 -m http.server -d public
```

## Limits

GitHub Pages sites can be at most 1 GB, and bandwidth has a soft cap of 100 GB a month. Today's
packages come to about 450 MB, and the build warns above 850 MB. If either limit becomes a
problem, keep the index here and serve `pool/` from somewhere else (Cloudflare R2, for example):
users' sources point at `vitrina-project.dev`, so they never need to change anything.
