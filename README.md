# AWS Amplify Deploy

This repo contains a bash script to automate the manual deployment on AWS Amplify. 

## Usages
The script will upload a dist (build dir) of a web app to S3 a zip. Next it creates a branch if non existing and start a deployment for the app. Optional a basic authentication can be set

```
aws-amplify-deploy.sh --app-id <APP_ID> --branch-name <BRANCH_NAME> \
  --dist-dir <build-dir> --bucket-name <S3_BUCKET_NAME> \
  --basic-auth <BASE64>
```


## Example

First create your app
```
export APP_ID=$(aws amplify create-app --name my-app | jq -r '.app.appId')```
```

Now you can deploy your branch as follow:
```
aws-amplify-deploy.sh -b new-feature -s my-bucket -d public
```

This will upload the dist dir `public` to a S3 bucket `my-bucket` and initiate a deployment to Amplify app `$APP_ID`. 

