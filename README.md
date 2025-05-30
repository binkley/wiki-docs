<a href="./LICENSE.md">
<img src="./images/public-domain.svg" alt="Public Domain"
align="right" width="10%" height="auto"/>
</a>

# GitHub Wiki Documentation

[![pull requests](https://img.shields.io/github/issues-pr/binkley/wiki-docs.svg)](https://github.com/binkley/wiki-docs/pulls)
[![issues](https://img.shields.io/github/issues/binkley/wiki-docs.svg)](https://github.com/binkley/wiki-docs/issues/)
[![license](https://img.shields.io/badge/license-Public%20Domain-blue.svg)](http://unlicense.org/)

Welcome to the GitHub repository on documenting REST APIs for the GitHub wiki!

The example is for adding toppings to a pizza.
This is similar to the traditional shopping cart but more flavorable.

There is nothing to build or run in this repository:<br/>
_The wiki markdown is the source code._

You want to go to the **wiki pages** which is the purpose of this project:
[Home wiki page](//github.com/binkley/wiki-docs/wiki).
For any GitHub project, it's in the GitHub top bar as "📖 Wiki" [when
enabled](https://docs.github.com/en/communities/documenting-your-project-with-wikis).

## Extras

This repository includes the [`wiki-to-pdf.sh`](./wiki-to-pdf.sh) script and
matching [action workflow in CI](./.github/workflows/ci.yml).
It generates a single merged PDF file for your wiki repository that goes with
your code repository.

To see an example PDF:
1. Navigate to the [Actions](https://github.com/binkley/wiki-docs/actions) tab
   for this project.
2. Navigate into the latest _green_ workflow run.
3. At bottom is an "Artifacts" section and the "wiki-docs" artifact is a ZIP of
   the PDF generated for the run.

(There does not seem to be a nice way for this README to make a direct link
into the latest workflow run and point to the ZIP or PDF.
All artifacts are always in a compressed file to help GitHub conserve storage
and bandwidth.)
