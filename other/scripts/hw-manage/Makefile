# Common targets
.PHONY: help check upgrade reboot status k3s-upgrade
.PHONY: inventory install ansible

ANSIBLE = ansible-playbook
INVENTORY = inventory/hosts.yml

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

ansible: ## Install Ansible
	command -v ansible >/dev/null || pipx install ansible-core

check: ## Pre-flight check (dry run)
	$(ANSIBLE) site.yml -i $(INVENTORY) -b --check

upgrade: ## Full hardware upgrade
	$(ANSIBLE) site.yml -i $(INVENTORY) -b

reboot: ## Reboot nodes (with Longhorn)
	$(ANSIBLE) reboot.yml -i $(INVENTORY) -b

k3s-upgrade: ## K3s upgrade
	K3S_VERSION=v1.30.0 $(ANSIBLE) site.yml -i $(INVENTORY) -b --extra-vars 'k3s_upgrade=true'

status: ## Cluster health
	$(ANSIBLE) status.yml -i $(INVENTORY) -b

clean: ## Remove temp files
	rm -f /etc/hw-manage/post-reboot
