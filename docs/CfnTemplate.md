# CloudFormation Nested Stack Structure

## Template details

| Template | Description |
| --- | --- |
| [s3bucket.yml](../cfn_templates/s3bucket.yml) | This template is to create an S3 bucket to store the CloudFormation templates |
| [master.yml](../cfn_templates/master.yml) | This is the master template to deploy all the components automatically. |
| [ecr.yml](../cfn_templates/ecr.yml) | This template is to create an Elastic Container Registry for ECS to load images from. |
| [alb.yml](../cfn_templates/alb.yml) | This template is to create an Application Load Balancer. |
| [security_groups.yml](../cfn_templates/security_groups.yml) | This template is to create security groups for each component. |
| [vpc.yml](../cfn_templates/vpc.yml) | This template is to create a VPC with two public and private subnets respectively. |
| [rds.yml](../cfn_templates/rds.yml) | This template is to create a RDS with Postgres engine. |
| [ecs_cluster.yml](../cfn_templates/ecs_cluster.yml) | This template is to create the backend using AWS ECS. |
