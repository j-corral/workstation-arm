#!/usr/bin/env bash
# The current official ARM64 full bundle includes a model. Do not download it
# into the guest, even temporarily. See docs/compatibility.md for exact evidence.
main() {
    record SKIPPED 'LM Studio headless installer' 'Current official ARM64 bundle includes a GGUF model; conflicts with the no-models-in-VM policy.'
    manual 'LM Link tooling' 'No verified current model-free official llmster bootstrap found. Reassess official packaging with IT; do not run the full installer in this VM.'
    manual 'LM Link pairing' 'Only after compliant tooling is available: lms login; lms link enable; ./verify.sh --lm-link. Existing installations are not modified.'
}
