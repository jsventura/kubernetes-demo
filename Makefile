# variables globales
OWNER   = punkerside
ENV     = demo

# variables de proveedor cloud
AWS_REGION = us-east-1
AWS_PRI = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].SubnetId" --output text | sed "s/\s/,/g")
AWS_PUB = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].SubnetId" --output text | sed "s/\s/,/g")

# variables de cluster kubernetes
NODE_VER   = 1.14
NODE_DES   = 2
NODE_MIN   = 1
NODE_MAX   = 10
NODE_TYPE  = r5.large
KUBECONFIG = $(HOME)/.kube/eksctl/clusters/$(OWNER)-$(ENV)


# capturando ids de subnets y zonas de disponibilidad
getSubnet:
	$(eval AWS_PRI_SB_A = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$1}' | sed -n 1p))
	$(eval AWS_PRI_AZ_A = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$2}' | sed -n 1p))
	$(eval AWS_PRI_SB_B = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$1}' | sed -n 2p))
	$(eval AWS_PRI_AZ_B = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$2}' | sed -n 2p))
	$(eval AWS_PRI_SB_C = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$1}' | sed -n 3p))
	$(eval AWS_PRI_AZ_C = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pri --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$2}' | sed -n 3p))
	$(eval AWS_PUB_SB_A = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$1}' | sed -n 1p))
	$(eval AWS_PUB_AZ_A = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$2}' | sed -n 1p))
	$(eval AWS_PUB_SB_B = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$1}' | sed -n 2p))
	$(eval AWS_PUB_AZ_B = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$2}' | sed -n 2p))
	$(eval AWS_PUB_SB_C = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$1}' | sed -n 3p))
	$(eval AWS_PUB_AZ_C = $(shell aws --region $(AWS_REGION) ec2 describe-subnets --filters Name=tag:Tier,Values=pub --query "Subnets[].[SubnetId, AvailabilityZone]" --output text | awk '{print $$2}' | sed -n 3p))

# creando cluster kubernetes
create: getSubnet
	export \
	  NAME=$(OWNER)-$(ENV) \
	  AWS_REGION=$(AWS_REGION) \
	  AWS_PRI_SB_A=$(AWS_PRI_SB_A) \
	  AWS_PRI_SB_B=$(AWS_PRI_SB_B) \
	  AWS_PRI_SB_C=$(AWS_PRI_SB_C) \
	  AWS_PRI_AZ_A=$(AWS_PRI_AZ_A) \
	  AWS_PRI_AZ_B=$(AWS_PRI_AZ_B) \
	  AWS_PRI_AZ_C=$(AWS_PRI_AZ_C) \
	  AWS_PUB_SB_A=$(AWS_PUB_SB_A) \
	  AWS_PUB_SB_B=$(AWS_PUB_SB_B) \
	  AWS_PUB_SB_C=$(AWS_PUB_SB_C) \
	  AWS_PUB_AZ_A=$(AWS_PUB_AZ_A) \
	  AWS_PUB_AZ_B=$(AWS_PUB_AZ_B) \
	  AWS_PUB_AZ_C=$(AWS_PUB_AZ_C) \
	&& envsubst < k8s/cluster.yaml | eksctl create cluster -f -

# instalando complemento dashboard
addon-dashboard:
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta1/aio/deploy/recommended.yaml
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f k8s/eks-admin-service-account.yaml
	@echo ""
	@kubectl -n kube-system describe secret $$(kubectl -n kube-system get secret | grep eks-admin | awk '{print $$1}') | grep "token:"
	@echo ""

# instalando complemento de metricas para pods
addon-metrics:
	@mkdir -p tmp/ && rm -rf tmp/metrics-server/ && cd tmp/ && git clone https://github.com/kubernetes-incubator/metrics-server.git
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f tmp/metrics-server/deploy/1.8+/

# instalando nginx ingress controller 
addon-ingress:
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f k8s/service-l7.yaml
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/patch-configmap-l7.yaml

# instalando complemento cluster autoscaler
addon-autoscaler:
	$(eval AWS_AUTOSCALING_GROUP = $(shell aws --region $(AWS_REGION) autoscaling describe-auto-scaling-groups | grep $(OWNER)-$(ENV) | grep AutoScalingGroupName | cut -d '"' -f 4))
	@export AWS_AUTOSCALING_GROUP=$(AWS_AUTOSCALING_GROUP) && envsubst < k8s/cluster-autoscaler-autodiscover.yaml | kubectl --kubeconfig=$(KUBECONFIG) apply -f -

# desplegando guestbook
deploy-guestbook:
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-master-controller.json
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-master-service.json
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-slave-controller.json
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/redis-slave-service.json
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook-go/guestbook-controller.json
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f guestbook/service.json
	@kubectl --kubeconfig=$(KUBECONFIG) apply -f guestbook/ingress.yaml
	@echo "" && echo "Configurar archivo hosts" && echo ""
	@sh k8s/getip.sh $(OWNER) $(ENV) $(AWS_REGION) && echo ""

# eliminando cluster kubernetes
delete:
	eksctl delete cluster \
	  --name $(OWNER)-$(ENV) \
	  --region=$(AWS_REGION)
