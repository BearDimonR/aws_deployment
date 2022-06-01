# AWS deployment

Repository for AWS deployment with domain name and SSL

### Prerequisite

1. Register new AWS account with [this guide](https://analyticshut.com/create-aws-account/). You need `email`, `telephone`, and `credit card` (create and use a virtual one). 

2. Install [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). To validate: `aws --version`

3. Install [terraform](https://www.terraform.io/downloads). To validate: `terraform --version`

### TO deploy infrastructure


#### Configure AWS

1. Go to the [aws console](http://console.aws.amazon.com)

2. Go to the User > Settings and change Default Region to `us-east-2`

3. Change region to your default (and use it further)

4. Follow [this](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-creds) guide to create user with administrator access and get credentials for aws cli.

5. Download them as `.csv` file and open file.

6. Get AccessKeyId and SecretAccessKey from this file (splited by commas)

7. Open terminal and run `aws configure`

8. Paste AccessKeyId, enter. Paste SecretAccessKey, enter. Default region: `us-east-2`, enter. Default output: `text`, enter.

9. Delete `.csv` file for security


#### Creating key for EC2 access

1. Go to the [aws console](http://console.aws.amazon.com).

2. Go to the Key pairs service.

3. Create key pair with some name (lets call it `key_name`).

4. Move downloaded `key_name.pem` to the project root folder.

5. Open infrastructure/main.tf and change variable `key_name` default to the name of your key.


#### Creating domain name

1. Go to the [site](https://www.freenom.com/en/index.html?lang=en)

2. Enter domain you want and check it

3. Find domain with "Get it now" button, copy it and paste in the search and check it again (search with extension like `domain.tk`)

4. You should see checkout button, click it

5. Select period and click Continue

6. Enter email (can use [fake](https://10minutemail.com) one) and follow link in the email.

7. Use fake address generator for country where your ip located to generate address ([example](https://www.fakexy.com/ua-fake-address-generator-volinska-oblast)).

10. Enter data and complete order. If all is fine you won't get Technical error.

11. Log in to the site and go to Services > MyDomain > Manage Domain > Management Tools > Nameservers. Select use custom nameservers

12.  Open infrastructure/main.tf and change variable `key_name` default to the name of your domain.

13. Do not close this site, here you will enter aws nameservers from the generated infrastructure (from `.nameservers` file).


#### Deploying infrastructure

1. Go to the infrastructure/main.tf and check if variables and data comfortable for you.

2. Open terminal in root project folder.

3. Enter `cd infrastructure` and run `sh deploy_infrastructure.sh`

4. Wait for infrastructure to be deployed (if needed, confirm)

5. After ending, check `.infrastructure_output` file. There will be stored all necessary variables for deployment.

6. Also, check `.nameservers` file. Here you will see nameservers, which can be used to fill in nameservers for your domain.

#### Deploying project (Optionally)

1. Create `.env` file and copy content from `.infrastructure_output`

2. Add variables DOMAIN_NAME (which you created before) and DOMAIN_EMAIL (which will be used by certbot for maintenance), so the keys of `.env` is equal to the `.env.example`

3. Be sure that you can access your ec2 instance with the DOMAIN_NAME

2. Open terminal in root project folder.

3. Run `deploy.sh`