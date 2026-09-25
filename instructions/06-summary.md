# Summary

You moved the same file through three clouds from a single terminal:

| Step | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Upload | `aws s3 cp` | `az storage blob upload` | `gcloud storage cp` |
| Download | `aws s3 cp` | `az storage blob download` | `gcloud storage cp` |

All three copies are checked the same way: a SHA-256 checksum of the downloaded file must match the original.

See every copy side by side:

```bash
tree ~/multicloud-lab
sha256sum ~/multicloud-lab/upload/* ~/multicloud-lab/downloads/*/*
```

The cloud accounts and everything in them are removed automatically when the lab ends.
