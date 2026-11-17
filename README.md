# agentica-lang.github.io

The www.agentica-lang.com home page and blog: a Hugo site with the
[docs theme](https://github.com/agentica-lang/docs-theme) of the project sites.

```sh
git submodule update --init
hugo server -D     # needs Hugo extended 0.167.0+ and Dart Sass on PATH
```

A push to `main` builds and deploys the site (`.github/workflows/pages.yml`).
Posts go in `content/blog/`; `draft: true` keeps one unpublished. A post's
link card uses its `cover.*` image (alt text: `imageAlt`), else
`static/social.png`, which `sh tools/social-image.sh` makes with headless
Chromium from `tools/social-image.html`.
