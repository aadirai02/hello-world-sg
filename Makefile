# StackGen DevOps Assignment Makefile
# Usage: make all | make infra | make deploy | make destroy

-include config.env

# === Defaults (overridden by config.env) ===
AWS_ACCOUNT_ID      ?= 561030001202
AWS_REGION          ?= us-east-1
ECR_REPO            ?= hello-world
K8S_CLUSTER_NAME    ?= stackgen-eks
K8S_NAMESPACE       ?= stackgen
TF_DIR              ?= terraform
K8S_DIR             ?= k8s

ECR_URL   ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO)
IMAGE_TAG ?= latest

.PHONY: all sync-tfvars infra build-push deploy destroy clean \
        kubeconfig namespace k8s-deploy k8s-destroy \
        ecr-cleanup terraform-destroy

all: sync-tfvars infra build-push deploy

# Generate terraform/terraform.tfvars from config.env values
sync-tfvars:
	@echo "🧩 Syncing config.env -> terraform/terraform.tfvars..."
	@mkdir -p $(TF_DIR)
	@printf 'aws_account_id      = "%s"\n' "$(AWS_ACCOUNT_ID)" > $(TF_DIR)/terraform.tfvars
	@printf 'aws_region          = "%s"\n\n' "$(AWS_REGION)" >> $(TF_DIR)/terraform.tfvars
	@printf 'github_owner        = "%s"\n' "$(GITHUB_OWNER)" >> $(TF_DIR)/terraform.tfvars
	@printf 'github_repo         = "%s"\n\n' "$(GITHUB_REPO)" >> $(TF_DIR)/terraform.tfvars
	@printf 'developer_user_name = "%s"\n\n' "$(DEVELOPER_USER_NAME)" >> $(TF_DIR)/terraform.tfvars
	@printf 'k8s_cluster_name    = "%s"\n' "$(K8S_CLUSTER_NAME)" >> $(TF_DIR)/terraform.tfvars
	@printf 'k8s_namespace       = "%s"\n' "$(K8S_NAMESPACE)" >> $(TF_DIR)/terraform.tfvars
	@echo "✅ terraform/terraform.tfvars updated."

infra:
	@echo "🚀 Applying Terraform infrastructure..."
	cd $(TF_DIR) && terraform init
	cd $(TF_DIR) && terraform apply -auto-approve
	@echo "🔄 Updating kubeconfig..."
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(K8S_CLUSTER_NAME)
	@echo "✅ Infrastructure deployed!"

build-push:
	@echo "🐳 Building and pushing Docker image..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_URL)
	docker build -t $(ECR_URL):$(IMAGE_TAG) .
	docker push $(ECR_URL):$(IMAGE_TAG)
	@echo "✅ Image pushed: $(ECR_URL):$(IMAGE_TAG)"

deploy: kubeconfig namespace k8s-deploy
	@echo "✅ Deployment complete! Check LoadBalancer: kubectl get svc -n $(K8S_NAMESPACE)"

kubeconfig:
	@echo "🔌 Updating kubeconfig for EKS cluster..."
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(K8S_CLUSTER_NAME)
	@echo "⏳ Waiting for EKS endpoint DNS propagation..."
	@sleep 10
	@echo "✅ Kubeconfig ready! Testing connection..."
	@kubectl get nodes || (echo "❌ EKS not ready yet, wait 2min and retry"; exit 1)

namespace:
	@echo "🏷️ Creating namespace: $(K8S_NAMESPACE)"
	kubectl create namespace $(K8S_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

k8s-deploy:
	@echo "📦 Deploying Kubernetes resources to namespace: $(K8S_NAMESPACE)..."

	@export K8S_NAMESPACE=$(K8S_NAMESPACE); \
	export IMAGE_URI=$(ECR_URL):$(IMAGE_TAG); \
	for f in $(K8S_DIR)/*.yaml; do \
	  envsubst < $$f | kubectl apply -f -; \
	done

	@echo "⏳ Waiting for rollout..."
	kubectl rollout status deployment/hello-world -n $(K8S_NAMESPACE) --timeout=300s

	@echo "🌐 LoadBalancer URL:"
	kubectl get svc hello-world-lb -n $(K8S_NAMESPACE) \
	  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'


destroy: k8s-destroy ecr-cleanup terraform-destroy
	@echo "✅ Complete destruction successful!"

k8s-destroy:
	@echo "💥 Destroying Kubernetes resources..."
	kubectl delete all --all -n $(K8S_NAMESPACE) --force --grace-period=0 || true
	kubectl patch pvc hello-world-logs -n $(K8S_NAMESPACE) -p '{"metadata":{"finalizers":null}}' || true
	kubectl delete pvc hello-world-logs -n $(K8S_NAMESPACE) --force --grace-period=0 || true
	kubectl delete namespace $(K8S_NAMESPACE) --force --grace-period=0 || true

ecr-cleanup:
	@echo "🗑️  Cleaning ALL ECR repository images..."
	@aws ecr list-images \
		--region $(AWS_REGION) \
		--repository-name $(ECR_REPO) \
		--query 'imageIds[*].[imageDigest,imageTag]' \
		--output text | while read digest tag; do \
			if [ -n "$$tag" ] && [ "$$tag" != "None" ]; then \
				echo "🗑️  Deleting tagged image: $$tag ($$digest)"; \
				aws ecr batch-delete-image \
					--region $(AWS_REGION) \
					--repository-name $(ECR_REPO) \
					--image-ids imageTag="$$tag" || true; \
			else \
				echo "🗑️  Deleting untagged image: $$digest"; \
				aws ecr batch-delete-image \
					--region $(AWS_REGION) \
					--repository-name $(ECR_REPO) \
					--image-ids imageDigest="$$digest" || true; \
			fi; \
		done
	@echo "✅ ECR repository completely cleaned!"

terraform-destroy:
	@echo "🔥 Destroying Terraform infrastructure..."
	cd $(TF_DIR) && terraform destroy -auto-approve

clean:
	@echo "🧹 Cleaning local Terraform state..."
	rm -rf $(TF_DIR)/.terraform* $(TF_DIR)/terraform.tfstate*
	@echo "✅ Clean complete!"

