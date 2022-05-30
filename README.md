# sbtree_test

Repository for testing AWS deployment

### TO deploy infrastructure

1. create AWS free tier account
2. go to the account and get account data
3. go to the console and create `sb_backend_ec2_key` key
4. download key file to the folder
5. install `aws cli`
6. `aws configure` - enter data for account
7. install `terraform`
8. run `deploy_infrastructure.sh`
9. run `deploy.sh`