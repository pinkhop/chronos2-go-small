# Agent Guide

This repository is `chronos2-go-small`, a Go module that embeds the `autogluon/chronos-2-small` Chronos-2 checkpoint for [`chronos2-go`](https://github.com/pinkhop/chronos2-go), the pure-Go Chronos-2 forecasting library. Its one package, `small`, exposes the checkpoint as a ready-to-use model through `New()`. These instructions apply to any agent or developer changing the repository.

The forecasting library, its design, and its parity tests live in `chronos2-go`. Its [`AGENTS.md`](https://github.com/pinkhop/chronos2-go/blob/main/AGENTS.md) holds the full set of conventions, and its `docs/DESIGN.md` describes how the library loads and runs this checkpoint. [`chronos2-go-base`](https://github.com/pinkhop/chronos2-go-base) packages the larger checkpoint the same way; keep the two repositories parallel in structure.


## Repository Layout

The module sits at the repository root, and the repository holds nothing else:

| Path | Role |
|---|---|
| `small.go` | Package `small`: the `//go:embed` declarations for the config and every shard, and `New()`. |
| `weights/config.json` | The checkpoint's configuration, as published upstream. |
| `weights/manifest.json` | The upstream source (repository, revision, file, and SHA-256), `max_shard_bytes`, the config's SHA-256, and each shard's file name, byte count, SHA-256, and tensor count. |
| `weights/*.safetensors` | The weights as fp32 safetensors shards. |
| `go.mod` | The module definition, which requires `github.com/pinkhop/chronos2-go` alone. |
| `README.md` | The consumer-facing overview. |
| `AGENTS.md` | This guide; `CLAUDE.md` is a symbolic link to it. |
| `Makefile` | Formatting, analysis, builds, and the weight and size checks. |
| `mise.toml`, `mise.lock` | The pinned Go toolchain and developer tools. |
| `LICENSE`, `NOTICE` | The Apache-2.0 license and the attribution for Chronos-2. |
| `.editorconfig`, `.gitattributes`, `.gitignore` | Editor and Git settings; `.gitattributes` keeps `*.safetensors` binary and out of Git LFS. |


## Commands

Tool versions, including Go itself, are pinned in `mise.toml` and `mise.lock`. Run `mise install` once, then use the `Makefile`:

| Command | Purpose |
|---|---|
| `make help` | List all targets. |
| `make format` | Format Go files with `goimports`, then `gofumpt`. |
| `make lint` | Check formatting, then run `go vet`, `staticcheck`, `errcheck`, `ineffassign`, `misspell`, and `typos`. |
| `make security` | Run `gosec` and `govulncheck`. |
| `make build` | Compile the package, which embeds every shard. |
| `make verify-weights` | Check `config.json` and every shard against `weights/manifest.json`: SHA-256s, byte counts, the `max_shard_bytes` ceiling, and that the shards on disk are exactly the ones listed, each listed once. |
| `make check-size` | Check the working tree, as it would be committed, against Go's two 500 MiB module limits, and print the headroom under each. |
| `make check` | Run `verify-weights`, then `check-size`. |

`check-size` stages the working tree into a temporary index, so it measures exactly what `git add -A` and a commit would publish without touching the real index, `HEAD`, or any ref.

Before considering a change complete, run `make format`, `make lint`, `make security`, and `make check`.


## Hard Constraints

These protect properties that are expensive or impossible to restore once broken.

### Weights

- Never store weights with Git LFS; `go get` cannot fetch LFS content. Weights are committed as plain safetensors shards of at most 45 MB each (`max_shard_bytes` in the manifest).
- Never edit, re-encode, or re-shard weight files by hand. Every tensor stays bit-identical to the upstream checkpoint at the revision the manifest pins.
- Keep `weights/manifest.json` accurate. Any change to the config or the shards updates the manifest's SHA-256s and byte counts in the same change, and `make verify-weights` must pass.
- Embed shards with `//go:embed` into `[]byte` variables, never `string`. `chronos2.Load` aliases aligned shard bytes as float32 tensors instead of copying them, and the Go linker currently aligns `[]byte` embeds but not string data. The alias test in `chronos2-go`'s `parity` module enforces both the embed type and the absence of a copy.
- When the set of shards changes, change the `//go:embed` declarations and the `Shards` list in `small.go` to match, in shard order.

### Module Size

- Go downloads a module at a repository root as a `git archive` of the whole repository and refuses that archive above 500 MiB. It also refuses a module whose files total more than 500 MiB uncompressed. Everything committed counts toward both limits.
- Never add Go tests, `testdata/`, nested modules, or any other large file. Tests of this checkpoint belong in `chronos2-go`'s `parity` module.
- `make check` must pass before any change is considered complete.

### Dependencies and API

- The module requires `github.com/pinkhop/chronos2-go` and nothing else. Never add a third-party dependency.
- The package's API is `New()` alone, returning the shared `*chronos2.Model`. Never change its signature, and never add an exported symbol without discussing the need.
- `checkpointName` is the name the model reports through `Model.Name`. Keep it equal to the upstream repository's name without its owner (`chronos-2-small`).


## Go Conventions

`chronos2-go`'s `AGENTS.md` ("Go Conventions") governs Go code here. The rules that apply most often:

- Every declaration, exported or not, has a doc comment stating what it does and why a caller would use it.
- Assign every returned error, including one being discarded, and wrap returned errors with `%w`.
- Use American spelling and the serial comma in identifiers, file names, and comments.
- Keep the Go version in `mise.toml` and `go.mod` in sync with `chronos2-go`'s.
- Pin every Go-based developer tool in `mise.toml` (adding with `mise use --pin`) and commit `mise.lock`, at the versions `chronos2-go` pins. Never declare tools with `go.mod` `tool` directives, and never use `golangci-lint`.


## Documentation

- Documents describe the current state of the repository. Keep decision history, superseded approaches, and change narratives out of them; commit messages carry history.
- Keep `README.md` consistent with `chronos2-go`'s README and with `chronos2-go-base`'s, including the sizes, capabilities, and provenance they state.
- Markdown uses ATX headings in title case, two blank lines before every H1 and H2 (except a first-line title), `-` list markers, four-space nested indents, one paragraph per source line, and a language tag on every fenced code block.


## Commits

Write commit messages in the Conventional Commits format (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`), with the subject in lowercase imperative mood.
