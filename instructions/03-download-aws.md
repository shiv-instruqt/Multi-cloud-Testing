# Download From AWS S3

Now pull the file back from each cloud, one at a time, into its own folder. Start with S3.

Download the object from `s3://{{aws_bucket}}` into `~/multicloud-lab/downloads/aws/`:

```bash
aws s3 cp s3://$AWS_BUCKET/hello-multicloud.txt ~/multicloud-lab/downloads/aws/
```

Compare it with the original:

```bash
sha256sum ~/multicloud-lab/upload/hello-multicloud.txt ~/multicloud-lab/downloads/aws/hello-multicloud.txt
```

Both lines should show the same checksum.

## Verify

Click **Check**. The check confirms the downloaded file exists and that its SHA-256 matches both the original file and the object currently stored in S3.

<instruqt-task id="download_aws"></instruqt-task>
