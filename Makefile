SERVICE:=$(dirname)
BRANCH:=$(git rev-parse --abbrev-ref HEAD)
HASH:=$(git rev-parse --short HEAD)
ENVIRONMENT=:$(if [$BRANCH == master]; then echo production; else echo development; fi)

# AWS
AWS_ECR:=ecrhost.com
AWS_REGION:=us-east-1
AWS_ACCOUNT_ID:=1111111111
ACM_ID:=ACMASSIGNDID

# Docker
DOCKER_REGISTRY:=${AWS_ECR}/${SERVICE}

# Postgres
PSG_HOST:=psgres_$(ENVIRONMENT).shrtb.red
PSG_PORT:=5432
PSG_USER:=admin
PSG_PASS:=password
PSG_REMOTE_DUMP:=https://gist.githubusercontent.com/jamster/7cd070880698efdd7828/raw/6cb716467b10c44647ab707be3e8d74ec689e60c/links.sql

release: build test push launch-rds deploy

# Build container image and tag for local.
build: build-app build-nginx

build-app:
  docker build -t $(SERVICE):build \
    --build-arg RACK_ENV=$(ENVIRONMENT) \
    -f Dockerfile .

build-nginx:
  docker build -t $(SERVICE)-nginx:build \
    -f Dockerfile.nginx .

test:
  docker run -it -rm $(SERVICE):build /bin/bash rspec

# To provide site reliability managment to container images
# push to branch and short hash.  We can also take advantage
# of version tags but this will make development more difficult. (TOPIC TO DISCUSS)
# Also note we are simulating use of ECR and assume build and
# deployment environment have been logged in.
push: push-app push-nginx

push-app:
	docker tag $(SERVICE):build $(DOCKER_REGISTRY):$(HASH)
	docker tag $(SERVICE):build $(DOCKER_REGISTRY):$(BRANCH)
	docker push $(DOCKER_REGISTRY):$(HASH)
	docker push $(DOCKER_REGISTRY):$(BRANCH)
ifeq $(BRANCH) 'master'
	docker tag $(SERVICE):build $(DOCKER_REGISTRY):latest
	docker push $(DOCKER_REGISTRY):latest

push-nginx:
	docker tag $(SERVICE)-nginx:build $(DOCKER_REGISTRY)-nginx:latest
	docker push $(DOCKER_REGISTRY):latest

# For now I am going to assume a slow rollout is sufficient and will
# include those instructions in deployment template.
deploy:
	# Convert template to kubernetes manifest YAML using ENVIRONMENT values.
	# Only going to explain the kubemanifest.tmpl gets converted to
	# kubemanifest.yaml via templating.  Many tools to do this including my own.
  kubectl apply -f kubemanifest.yaml
	kubectl autoscale deployment $(SERVICE) --cpu-percent=50 --min=5 --max=10 # (DISCUSS CPU THRESH)
	rm kubemanifest.yaml

# To create Postgres lets use RDS for both production and development.
# It would be safer and more consistant to use Infrastructure As Code like
# Cloudformation/Terraform/Puppet or Ansible but I will break it down using cmds.
launch-rds:
  # Create DBMS
  aws rds create-db-instance \
    --db-instance-identifier psgres \
    --db-instance-class db.t3.micro \
    --engine postgresql \
    --master-username $(PSG_USER) \
    --master-user-password $(PSG_PASS) \
    --allocated-storage 20
	# Wait for instance to boot and get host id (ie example.com).
	# Use this to update R53 record.
	# NOTE: Polling for the instance would be better than sleep but for simplicity.
	sleep 120
  RDS_HOST_ID=$(aws rds describe-db-instances \
    --db-instance-identifier psgres | jq ..FILTER HOSTZONEID)
  # Run rake command from build container.
  docker run -it -rm -e DATABASE_URL=postgres://$(PSG_USER):$(PSG_PASS)@$(PSG_HOST):$(PSG_PORT)/$(SERVICE)_$(ENVIRONMENT) \
    $(SERVICE):build /bin/bash -c "rake db:migrate"
  # Grab last dump file and update RDS.
  curl -o $(PSG_REMOTE_DUMP) > postgresdump.sql
  psql \
    -f postgresdump.sql \
    --host $(RDS_HOST_ID) \
    --port $(PSG_PORT) \
    --username $(PSG_USER) \
    --password $(PSG_PASS) \
    --dbname $(SERVICE)_$(ENVIRONMENT)
  echo "{\"Comment\": \"Adding a new DBMS host.\", \"Changes\":[{\"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"$(PSG_HOST).\", \"Type\": \"CNAME\", \"ResourceRecords\": [{\"Value\": \"$(RDS_HOST_ID)\"}]}}]}" > route53change.json
  aws route53 change-resource-record-sets --hosted-zone-id $(PSG_HOST) --change-batch file://${PWD}/route53change.json
  rm route53change.json postgresdump.sql
