#!/bin/bash -e
script_name="$(basename "${0}")"

function put_param() {
  input=$(aws ssm put-parameter --name "$1" --type "String" --value "$2" --overwrite)
  echo ${input}
}

function upload_param() {
  put_param "RDSMasterUsername" "${dbuser}"
  put_param "RDSMasterUserPassword" "${dbpassword}"
  put_param "RDSDBName" "${dbname}"
}

function deploy_enc() {
  bucket_stack_name="TechChallengeS3"
  if ! aws cloudformation describe-stacks --stack-name ${bucket_stack_name}; then
    aws --profile=default cloudformation create-stack \
    --stack-name ${bucket_stack_name} \
    --capabilities=CAPABILITY_IAM \
    --template-body file://cfn_templates/s3bucket.yml \
    --parameters ParameterKey=BucketName,ParameterValue=tcbucketdev
  fi
  
  aws s3 sync \
      --acl public-read \
      --delete \
      ./cfn_templates/ s3://tcbucketdev/cfn_templates/

  vpc_stack_name="TechChallengeMaster"
  aws cloudformation deploy \
      --stack-name ${vpc_stack_name} \
      --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM \
      --template-file ./cfn_templates/master.yml \
      --parameter-overrides \
          Environment=${environment} \
          S3BucketUrl=https://s3.amazonaws.com/tcbucketdev/cfn_templates/ 
}

function get_param() {
  data=$(aws ssm get-parameters --name "$1" | jq -r '.Parameters[0].Value')
  echo ${data}
}

function modify_toml() {
  DbUser=$(get_param "RDSMasterUsername")
  if [[ ! -z "${DbUser}" ]]; then
    sed -i -e "/DbUser/ s/postgres/${DbUser}/;" conf.toml
  else
    echo "DbUser value is empty."
    exit 1
  fi

  DbPassword=$(get_param "RDSMasterUserPassword")
  if [[ ! -z "${DbPassword}" ]]; then
    sed -i -e "/DbPassword/ s/changeme/${DbPassword}/;" conf.toml
  else
    echo "DbPassword value is empty."
    exit 1
  fi

  DbName=$(get_param "RDSDBName")
  if [[ ! -z "${DbName}" ]]; then
    sed -i -e "/DbName/ s/app/${DbName}/;" conf.toml
  else
    echo "DbName value is empty."
    exit 1
  fi

  DbHost=$(aws rds describe-db-instances | jq -r '.DBInstances[0].Endpoint.Address')
  sed -i -e "/DbHost/ s/localhost/${DbHost}/;" conf.toml

  sed -i -e "/ListenHost/ s/localhost/0.0.0.0/;" conf.toml
}

function dockerising() {
  docker build -t servian/techchallengeapp:latest .
  
  aws ecr get-login-password | \
  	docker login -u AWS \
  	--password-stdin "https://$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.ap-southeast-2.amazonaws.com"
  
  docker tag servian/techchallengeapp:latest \
  	$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.ap-southeast-2.amazonaws.com/${environment}-tcapp:latest
  
  docker push $(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.ap-southeast-2.amazonaws.com/${environment}-tcapp:latest
}

function deploy_ecs(){
  ecs_stack_name="TechChallengeECS"
  aws cloudformation deploy \
      --stack-name ${ecs_stack_name} \
      --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM \
      --template-file ./cfn_templates/ecs_cluster.yml \
      --parameter-overrides \
          Environment=${environment}
}

function usage {
  echo ""
  echo "Usage"
  echo "./${script_name} \\"
  echo "    --profile <aws profile, default value is \"default\"> \\"
  echo "    --environment <Environment for deploying the stack, default value is \"dev\"> \\"
  echo "    --dbuser <database username> \\"
  echo "    --dbpassword <database password> \\"
  echo "    --dbname <database name> \\"
  echo ""
  echo "Summary"
  echo "Deploy TechChallenge application an AWS environment"
  echo ""
  echo "Options"
  echo "--profile            The AWS Cli profile."
  echo "--environment        The environment for deploying the app"
  echo "--dbuser             The username to connect to the database."
  echo "--dbpassword         The password to connect to the database."
  echo "--dbname             The database name to be created."
  echo "-h | --help          Display this help text"
  echo ""
}

all_params="$@"
# Processing script arguments
while :
do
  case "${1}" in
    --profile)
      profile="${2}"
      shift 2
      ;;
    --environment)
      environment="${2}"
      shift 2
      ;;
    --dbuser)
      dbuser="${2}"
      shift 2
      ;;
    --dbpassword)
      dbpassword="${2}"
      shift 2
      ;;
    --dbname)
      dbname="${2}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: Unknown option (${1})!" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

[[ -z "${profile}" ]] && profile="default"
export AWS_PROFILE=${profile}

[[ -z "${environment}" ]] && environment="dev"

[[ -z "${dbuser}" || -z "${dbpassword}" || -z "${dbname}" ]] && echo "Script arguments parsing error." && usage && exit 1

echo "Uploading parameters to SSM parameter store"
upload_param

echo "Deploying S3 and VPC"
deploy_enc

echo "Populating parameters..."
root_dir=$(pwd)
cd "${root_dir}/TechChallengeApp"
modify_toml

echo "Building and pushing the Docker image"
dockerising

echo "Deploying to ECS cluster..."
cd "${root_dir}"
deploy_ecs
