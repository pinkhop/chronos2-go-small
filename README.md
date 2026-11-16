# chronos2-go-small

The small variant of Amazon's [Chronos-2](https://huggingface.co/amazon/chronos-2) forecasting model, embedded for [`chronos2-go`](https://github.com/pinkhop/chronos2-go), the pure-Go library for probabilistic time series forecasting.

> [!NOTE]
> `chronos2-go-small` is at v1, and its API is stable: later v1 releases add capabilities and fixes without breaking code written against earlier ones.

This module carries the `autogluon/chronos-2-small` checkpoint, the smaller of the two Chronos-2 models `chronos2-go` supports. Importing it adds the model's weights to your binary, about 112 MB, and `small.New()` hands you a ready-to-use model. The forecasting API itself lives in `chronos2-go`, which this module brings with it.


## Capabilities

| Property | Value |
|---|---|
| Checkpoint | `autogluon/chronos-2-small` |
| Parameters | ~28M |
| Adds to Binary | ~112 MB |
| Context | up to 8,192 steps of history |
| Single-Pass Horizon | up to 1,024 steps |
| Native Percentiles | 13 levels: 1, 5, 10, 20, 30, …, 80, 90, 95, 99 |
| Embedding Dimension | 512 |

The model predicts its native percentile levels directly, and each has a named method on the forecast (`Percentile10`, `Percentile90`, and so on). The named methods for levels it does not predict, such as `Percentile15`, return `nil`; `Percentile(p)` interpolates any level from 1 to 99.


## Installation

Add the module; it brings the core library with it:

```console
$ go get github.com/pinkhop/chronos2-go-small
```

Requires Go 1.27.4 or later.


## Usage

```go
import (
    small "github.com/pinkhop/chronos2-go-small"
)

m, err := small.New()
if err != nil {
    return fmt.Errorf("load model: %w", err)
}

fc, err := m.Forecast(ctx, hourlyLoad, 24)
if err != nil {
    return fmt.Errorf("forecast load: %w", err)
}

median := fc.Median()     // the most likely path, 24 steps
p90 := fc.Percentile90()  // a natively predicted percentile
```

`small.New()` returns the same shared model on every call, so call it wherever convenient; the model is safe for concurrent use. The [`chronos2-go` README](https://github.com/pinkhop/chronos2-go) covers the rest of the API: batches, multivariate forecasts, covariates, embeddings, and options.


## Choosing Between Base and Small

| Module | Checkpoint | Adds to Binary | Native Percentiles | Embedding Dimension |
|---|---|---|---|---|
| [`github.com/pinkhop/chronos2-go-base`](https://github.com/pinkhop/chronos2-go-base) | `amazon/chronos-2` | ~478 MB | 21 | 768 |
| `github.com/pinkhop/chronos2-go-small` | `autogluon/chronos-2-small` | ~112 MB | 13 | 512 |

The base model is more accurate and predicts more percentile levels natively; the small model is faster and lighter. Both read the same history length, forecast the same horizon in one pass, and return the same `*chronos2.Model`, so switching between them changes only the import. Importing either under one neutral name, such as `model`, makes the switch a one-line change.

Embeddings from the two models differ in length and are not comparable with each other; compare only embeddings produced by the same model.


## Provenance

The weights come from the [`autogluon/chronos-2-small`](https://huggingface.co/autogluon/chronos-2-small) repository on Hugging Face, pinned to revision [`ddec01313e50b6bc58ebaa92ede81bc24a3d9f9a`](https://huggingface.co/autogluon/chronos-2-small/tree/ddec01313e50b6bc58ebaa92ede81bc24a3d9f9a). The upstream `model.safetensors` there has this SHA-256:

```text
492290ae82bb89f9769e3479ce90b3179de1f33e600c34daa0352531538b23cd
```

They ship as fp32 safetensors shards of at most 45 MB each, split from that file with every tensor bit-identical to upstream. [`weights/manifest.json`](weights/manifest.json) records the upstream source and each shard's size and SHA-256, and `make verify-weights` checks the files against it.


## Contributing

[`AGENTS.md`](AGENTS.md) describes the repository, the `make` targets, and the rules every change follows, for human and AI contributors alike.


## License

Licensed under the Apache License, Version 2.0; see [`LICENSE`](LICENSE).

Chronos-2 was created by Amazon, and its weights are distributed under Apache-2.0; see [`NOTICE`](NOTICE). If you use Chronos-2 in research, cite the authors' paper, [Chronos-2: From Univariate to Universal Forecasting](https://arxiv.org/abs/2510.15821).
