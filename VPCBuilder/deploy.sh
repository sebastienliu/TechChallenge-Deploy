aws --profile=default cloudformation create-stack \
--stack-name TechChallengeVPC \
--capabilities=CAPABILITY_IAM \
--template-body file://infra/vpc.yml \
--parameters ParameterKey=Environment,ParameterValue=Dev
