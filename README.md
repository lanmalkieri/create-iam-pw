# create-iam-pw

This simple bash script is designed at making peoples lives easier who don't have full blown SSO but still manage lots of users in IAM that require Console access. 

With this script you can simple use a pre-existing AWS SES setup and send emails to new users with sign on information, including an intial password. 

The initial password is generated locally, and stored securely in a (preferably encrypted) S3 bucket. 

We then generate a presigned URL to that object in S3 and provide it to the user via email.
