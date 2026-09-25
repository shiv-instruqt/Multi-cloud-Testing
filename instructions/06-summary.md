# Summary

You moved the same file through two clouds from a single terminal:

| Step | AWS | Google Cloud |
| --- | --- | --- |
| Upload | `aws s3 cp` | `gcloud storage cp` |
| Download | `aws s3 cp` | `gcloud storage cp` |

Both copies are checked the same way: a SHA-256 checksum of the downloaded file must match the original.

See every copy side by side:

```bash
tree ~/multicloud-lab
sha256sum ~/multicloud-lab/upload/* ~/multicloud-lab/downloads/*/*
```

The cloud accounts and everything in them are removed automatically when the lab ends.
