# v0.8.2 / Build70 — public release and website closure

- Owner accepted Preview69 and approved publication. [GitHub v0.8.2](https://github.com/Xiye88/NotchMuse/releases/tag/v0.8.2) is the regular Latest release. Tag and website deployment source: `0e98ad09e093e61cea4686acbb369154446fbc0a`; [CI passed](https://github.com/Xiye88/NotchMuse/actions/runs/42745321470). Anonymous DMG download matched the frozen SHA256 `f0aef83093c7bd0845816f4a52986d8cd3dee1d9c2381145e53c6fdd8226540c` (7,270,643 bytes).
- Official website serves the GitHub website tree `1bdc6ca03838353d7226b4f93ba1839239186a9a` from `/opt/notchmuse-site/releases/20261110-v082-0e98ad0`. Origin: 48 exact file hashes with preserved CSP. Public apex/www: 36 exact HTTP checks, including 12 pages on each domain with 3 Build70 download links per page. Existing appcast, v0.8.0 notes and v0.8.1 notes preserved byte-for-byte. No DNS or Tunnel changes.
- Manual installation only; automatic update feed remains Build47. Local Stable61 and Preview69 were not replaced. Bilingual lyrics remain deferred.

The website was deployed to the existing origin after confirming its active service and previous release. The deployment preserved Cloudflare routing, server behavior and the original site directory. A first archive transfer timed out before activation; its existing prefix was hash-verified, the remainder was resumed, and the completed archive and all staged files were checked before switching.

Rollback: restore `/opt/notchmuse-site/site_server.before-v082-20261110.py` and restart `notchmuse-site.service`; previous directory `/opt/notchmuse-site/releases/20261104-seo-9d1d50e` is retained. Release v0.8.1 and its DMG remain available.

```text
Current status: RELEASED / DEPLOYED / PUBLIC_VERIFIED.
Completed: GitHub Latest and frozen DMG, source/README, exact origin and public website checks, rollback retention.
Pending confirmation: None. Automatic update qualification is separate.
Key files: docs/releases/v0.8.2/SOURCE_PROVENANCE.json; website/; docs/reports/release/V082_PUBLICATION_COMPLETION.md.
Next step: Collect feedback; bilingual lyrics only in a later task.
Do not repeat: Release uploads, deployment, accepted listening tests or automatic feed activation.
```
