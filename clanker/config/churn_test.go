package config

import "testing"

func TestExtractChurnLimitReadsTheHookConstant(t *testing.T) {
	core := "// leading comment\nexport const MIN_LINES = 250\n\nexport function x() {}\n"
	got, ok := extractChurnLimit(core)
	if !ok {
		t.Fatal("extractChurnLimit: not found in a core that declares MIN_LINES")
	}
	if got != "250" {
		t.Fatalf("extractChurnLimit = %q, want %q", got, "250")
	}
}

func TestWithChurnLimitSubstitutesEveryToken(t *testing.T) {
	core := "export const MIN_LINES = 250\n"
	body := "Hand back under __CHURN_LIMIT__ lines.\nOver __CHURN_LIMIT__ and it stops being reviewable.\n"
	want := "Hand back under 250 lines.\nOver 250 and it stops being reviewable.\n"
	if got := withChurnLimit(body, core); got != want {
		t.Fatalf("withChurnLimit =\n%q\nwant\n%q", got, want)
	}
}

func TestWithChurnLimitPanicsWhenTheConstantIsRenamed(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Fatal("withChurnLimit: substituted silently instead of panicking when MIN_LINES is absent")
		}
	}()
	withChurnLimit("under __CHURN_LIMIT__ lines", "export const THRESHOLD = 250\n")
}
