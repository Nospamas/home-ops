# Secrets are SOPS-encrypted in Git with age

All secrets are committed to the repo as SOPS-encrypted `*.sops.yaml` files,
decrypted at reconcile time by Flux using an age key (`.sops.yaml` configures the
recipients; `sops-age` is the in-cluster decryption Secret). We chose this over
Sealed Secrets, external-secrets, or Vault to keep a single source of truth in
Git with no external secret store to run or trust — the cost is that the age
private key is the one out-of-band credential, and `talhelper genconfig` and all
local tooling require it (`SOPS_AGE_KEY_FILE`).

Trade-off: rotating the age key or migrating away means re-encrypting every
`*.sops.yaml` in the repo, so this is expensive to reverse.
