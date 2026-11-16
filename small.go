// Package small embeds the autogluon/chronos-2-small checkpoint (a saved copy of the trained
// Chronos-2 model) and provides it as a ready-to-use [chronos2.Model].
// Importing this package adds the checkpoint's weights to the binary; package
// [github.com/pinkhop/chronos2-go] documents the forecasting API.
//
// It is the smaller of the two published models: it adds about 112 MB to a
// binary, runs faster, and predicts 13 percentile levels natively. Package
// [github.com/pinkhop/chronos2-go-base] embeds the larger model, with
// 21 native levels; switching between them changes only the import path.
package small

import (
	_ "embed"
	"sync"

	chronos2 "github.com/pinkhop/chronos2-go"
)

// checkpointName is the name the model reports through Model.Name.
const checkpointName = "chronos-2-small"

// config is the checkpoint's config.json.
//
//go:embed weights/config.json
var config []byte

// The shards are embedded as byte slices rather than strings because the Go
// linker currently aligns embedded byte-slice data but not string data (not
// a language guarantee; the alias test in the chronos2-go repository's parity
// module verifies it): chronos2.Load can then view the weights in place
// instead of copying the whole checkpoint onto the heap. Nothing may write to
// these slices; the model every goroutine shares reads them for the life of
// the process.
var (
	// shard01 is weights/model-00001-of-00003.safetensors.
	//
	//go:embed weights/model-00001-of-00003.safetensors
	shard01 []byte

	// shard02 is weights/model-00002-of-00003.safetensors.
	//
	//go:embed weights/model-00002-of-00003.safetensors
	shard02 []byte

	// shard03 is weights/model-00003-of-00003.safetensors.
	//
	//go:embed weights/model-00003-of-00003.safetensors
	shard03 []byte
)

// load decodes the embedded checkpoint once per process and caches the result.
var load = sync.OnceValues(func() (*chronos2.Model, error) {
	return chronos2.Load(chronos2.Checkpoint{
		Name:   checkpointName,
		Config: config,
		Shards: [][]byte{shard01, shard02, shard03},
	})
})

// New returns the package's shared, immutable Chronos-2 model. The first call
// decodes the embedded autogluon/chronos-2-small checkpoint, viewing its weights in place where
// the platform allows instead of copying them; every later call returns the same
// [*chronos2.Model]. The model is safe for concurrent use by any number of
// goroutines. An error matches [chronos2.ErrInvalidCheckpoint], indicates
// damaged embedded files, and is returned on every call.
func New() (*chronos2.Model, error) {
	return load()
}
