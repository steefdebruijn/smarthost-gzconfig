#!/bin/bash
#
# Usage: create-bucket-with-rw-policy.sh <configured-minio-host> <bucket-name> <extra-args-for-mc>
# Use --insecure as extra args for example when using self-signed certs on (test) server
#
mc mb $1/$2 $3
cat <<_eof > tmp.tmp
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": [
        "arn:aws:s3:::${2}"
      ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListMultipartUploadParts",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${2}/*"
      ]
    }
  ]
}
_eof
mc admin policies add $1 ${2}-rw tmp.tmp $3
