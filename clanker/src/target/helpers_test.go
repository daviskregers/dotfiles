package target_test

import (
	"testing"

	"clanker/src/target"
)

// assertFiles fails the test unless got equals want, file for file.
func assertFiles(t *testing.T, got, want []target.OutputFile) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("got %d files, want %d: %+v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("file %d:\n got %#v\nwant %#v", i, got[i], want[i])
		}
	}
}

// contentOf returns the first file's content, or "" — for error messages.
func contentOf(f []target.OutputFile) string {
	if len(f) == 0 {
		return ""
	}
	return f[0].Content
}
