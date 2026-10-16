# Branches of the vietnt/goose fork

This fork carries the compiler changes the Rome port needs on top of
[aardappel/goose](https://github.com/aardappel/goose).

- `rome`, the default branch, is upstream `master` plus our commits. All of
  our work is committed here. Releases are tagged from it as
  `v<upstream version>-rome.<n>`, for example `v2026.1-rome.3`; a tag with a
  `-` in it is published as a prerelease.
- `master` is an exact mirror of upstream `master`. Nothing is committed to
  it; it only moves to upstream's head.

## Syncing with upstream

```sh
git remote add upstream https://github.com/aardappel/goose   # once
git fetch upstream
git push origin upstream/master:master                       # move the mirror
git push origin origin/rome:refs/tags/archive/rome-<date>    # keep the old head reachable
git checkout rome && git rebase upstream/master
cmake --build build -j4
python3 test/run_tests.py --exe build/goose -j4              # "all tests passed"
# and the goose_gfx suite with this build, from a goose_gfx checkout of its rome:
python3 test/run_gfx_tests.py --require-gpu --validate --goose <path>/build/goose
git push --force-with-lease origin rome
```

When CI is green on `rome`, tag the release; the tag starts the Release
workflow, which builds and publishes the four archives:

```sh
git tag -a v2026.1-rome.<n> -m "Goose v2026.1-rome.<n>" && git push origin v2026.1-rome.<n>
```

The archive tag keeps commits from before the rebase fetchable by hash.
Release tags keep their own commits reachable anyway.
