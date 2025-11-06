.PHONY: help check setup ping install verify uninstall logs clean trust-ca dns-help configure

# Variables
INVENTORY := inventories/hosts.yml
INVENTORY_TEMPLATE := inventories/hosts.yml.template
PLAYBOOK_DIR := playbooks
KUBECONFIG := ~/.kube/config-k3s-local
CA_CERT := ~/.kube/k3s-local-ca.crt
CONFIG_FILE := .cluster-config

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)K3s HA Cluster LOCAL - Ansible Automation$(NC)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Initial setup:$(NC)"
	@echo "  1. ./lazykube configure  # Configure VM IPs and credentials"
	@echo "  2. ./lazykube check      # Verify connectivity"
	@echo "  3. ./lazykube install    # Install cluster"
	@echo ""
	@echo "$(YELLOW)Or use make commands:$(NC)"
	@echo "  make configure && make check && make install"
	@echo ""

configure: ## Configure VM IPs and credentials interactively
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)K3s HA Cluster Configuration$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Required 4 VMs configuration:$(NC)"
	@echo "  - 3 Master nodes (K3s control-plane + etcd)"
	@echo "  - 1 HAProxy Load Balancer"
	@echo ""
	@bash scripts/configure-cluster.sh

check: ## Verify prerequisites
	@if [ ! -f $(CONFIG_FILE) ]; then \
		echo "$(RED)Error: Cluster not configured!$(NC)"; \
		echo "$(YELLOW)Run first: ./lazykube configure$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Verifying prerequisites...$(NC)"
	@ansible all -i $(INVENTORY) -m ping -o > /dev/null 2>&1 || (echo "$(RED)✗ Some VMs are unreachable$(NC)" && exit 1)
	@echo "$(GREEN)✓ All VMs are reachable$(NC)"

setup: ## Install Ansible dependencies
	@echo "$(BLUE)Setting up Ansible dependencies...$(NC)"
	@pip3 install --user kubernetes --quiet || true
	@ansible-galaxy collection install -r requirements.yml
	@echo "$(GREEN)✓ Setup completed$(NC)"

ping: ## Test VM connectivity
	@if [ ! -f $(CONFIG_FILE) ]; then \
		echo "$(RED)Error: Cluster not configured!$(NC)"; \
		echo "$(YELLOW)Run first: ./lazykube configure$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Testing VM connectivity...$(NC)"
	@ansible all -i $(INVENTORY) -m ping

install: ## Install local K3s HA cluster
	@if [ ! -f $(CONFIG_FILE) ]; then \
		echo "$(RED)Error: Cluster not configured!$(NC)"; \
		echo "$(YELLOW)Run first: ./lazykube configure$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Installing local K3s HA cluster...$(NC)"
	@echo "$(YELLOW)This process may take some minutes...$(NC)"
	@echo ""
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/install-cluster-local.yml > /dev/null 2>&1 && \
		(echo "" && echo "$(GREEN)✓ Installation completed!$(NC)" && echo "" && make dns-help) || \
		(echo "$(RED)✗ Installation failed!$(NC)" && echo "$(YELLOW)Run './lazykube install-verbose' to see details$(NC)" && exit 1)

install-verbose: ## Install with verbose output (shows all stages)
	@if [ ! -f $(CONFIG_FILE) ]; then \
		echo "$(RED)Error: Cluster not configured!$(NC)"; \
		echo "$(YELLOW)Run first: ./lazykube configure$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Installing cluster (verbose mode - showing all stages)...$(NC)"
	@echo "$(YELLOW)This process may take some minutes...$(NC)"
	@echo ""
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/install-cluster-local.yml -v

verify: ## Verify cluster status
	@echo "$(BLUE)Verifying cluster status...$(NC)"
	@if [ ! -f $(KUBECONFIG) ]; then \
		echo "$(YELLOW)Kubeconfig not found$(NC)"; \
		exit 1; \
	fi
	@export KUBECONFIG=$(KUBECONFIG) && \
	echo "" && \
	echo "$(GREEN)Cluster Info:$(NC)" && \
	kubectl cluster-info && \
	echo "" && \
	echo "$(GREEN)Nodes:$(NC)" && \
	kubectl get nodes -o wide && \
	echo "" && \
	echo "$(GREEN)System Pods:$(NC)" && \
	kubectl get pods -A -l 'app.kubernetes.io/name in (metallb,traefik,cert-manager)' && \
	echo "" && \
	echo "$(GREEN)Services:$(NC)" && \
	kubectl get svc -A | grep -E 'traefik|metallb' && \
	echo "" && \
	echo "$(GREEN)ClusterIssuers:$(NC)" && \
	kubectl get clusterissuer && \
	echo "" && \
	echo "$(GREEN)Certificates:$(NC)" && \
	kubectl get certificate -A

logs: ## Show component logs
	@echo "$(BLUE)MetalLB Logs:$(NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl logs -n metallb-system -l component=controller --tail=20 || true
	@echo ""
	@echo "$(BLUE)cert-manager Logs:$(NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl logs -n cert-manager -l app=cert-manager --tail=20 || true
	@echo ""
	@echo "$(BLUE)Traefik Logs:$(NC)"
	@export KUBECONFIG=$(KUBECONFIG) && kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=20 || true

trust-ca: ## Import CA certificate into system (for HTTPS without warnings)
	@echo "$(BLUE)Importing CA certificate...$(NC)"
	@if [ ! -f $(CA_CERT) ]; then \
		echo "$(YELLOW)CA certificate not found at $(CA_CERT)$(NC)"; \
		echo "$(YELLOW)Run './lazykube install' first$(NC)"; \
		exit 1; \
	fi
	@sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $(CA_CERT)
	@echo "$(GREEN)✓ CA certificate imported!$(NC)"
	@echo "$(YELLOW)Restart your browser to apply changes$(NC)"

dns-help: ## Show instructions to configure local DNS
	@echo ""
	@echo "$(BLUE)========================================$(NC)"
	@echo "$(BLUE)POST-INSTALLATION SETUP$(NC)"
	@echo "$(BLUE)========================================$(NC)"
	@echo ""
	@if [ -f $(CONFIG_FILE) ]; then \
		source $(CONFIG_FILE) && \
		echo "$(YELLOW)1. Configure local DNS (/etc/hosts):$(NC)" && \
		echo "" && \
		echo "$(GREEN)sudo bash -c 'cat >> /etc/hosts << EOF" && \
		echo "" && \
		echo "# K3s Local Cluster (via HAProxy)" && \
		echo "$${HAPROXY_IP}  traefik.k3cluster.local" && \
		echo "$${HAPROXY_IP}  demo.k3cluster.local" && \
		echo "EOF'$(NC)" && \
		echo "" && \
		echo "$(YELLOW)2. Import CA certificate (disable SSL warnings):$(NC)" && \
		echo "" && \
		echo "$(GREEN)./lazykube trust-ca$(NC)" && \
		echo "" && \
		echo "$(YELLOW)This will import the self-signed CA into your system keychain.$(NC)" && \
		echo "$(YELLOW)After importing, restart your browser to see HTTPS without warnings.$(NC)"; \
	else \
		echo "$(YELLOW)Run first: ./lazykube configure$(NC)"; \
	fi
	@echo ""
	@echo "$(BLUE)========================================$(NC)"
	@echo ""

uninstall: ## Remove K3s cluster
	@echo "$(YELLOW)⚠️  WARNING: Removing K3s cluster$(NC)"
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo "$(BLUE)Removing cluster...$(NC)"
	@ansible k3s_masters -i $(INVENTORY) -m shell -a "sudo /usr/local/bin/k3s-uninstall.sh" -b || true
	@ansible haproxy -i $(INVENTORY) -m shell -a "sudo systemctl stop haproxy && sudo apt remove -y haproxy" -b || true
	@rm -f /tmp/k3s-token-local
	@rm -f $(KUBECONFIG)
	@echo "$(GREEN)Cluster removed$(NC)"

clean: ## Clean temporary files and configuration
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@rm -f /tmp/k3s-token-local
	@rm -rf /tmp/ansible_facts_local
	@find . -name "*.retry" -delete
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-config: ## Remove cluster configuration (requires reconfiguration)
	@echo "$(YELLOW)⚠️  WARNING: Removing cluster configuration$(NC)"
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@rm -f $(CONFIG_FILE)
	@rm -f $(INVENTORY)
	@echo "$(GREEN)Configuration removed. Run './lazykube configure' to reconfigure.$(NC)"

dashboard: ## Open Traefik dashboard
	@echo "$(BLUE)Opening Traefik dashboard...$(NC)"
	@open https://traefik.k3cluster.local/dashboard/ || \
		echo "$(YELLOW)Configure local DNS first: ./lazykube dns-help$(NC)"

haproxy-stats: ## Open HAProxy stats dashboard
	@if [ -f $(CONFIG_FILE) ]; then \
		source $(CONFIG_FILE) && \
		echo "$(BLUE)Opening HAProxy stats dashboard...$(NC)" && \
		open http://$${HAPROXY_IP}:8404/stats || \
			echo "$(YELLOW)Dashboard not accessible$(NC)"; \
	else \
		echo "$(YELLOW)Run first: ./lazykube configure$(NC)"; \
	fi

config: ## Show current configuration
	@echo "$(BLUE)Configuration:$(NC)"
	@echo ""
	@if [ -f $(CONFIG_FILE) ]; then \
		echo "$(YELLOW)Configured VMs:$(NC)"; \
		source $(CONFIG_FILE) && \
		echo "  Master 1: $${MASTER1_IP} (user: $${MASTER1_USER})"; \
		echo "  Master 2: $${MASTER2_IP} (user: $${MASTER2_USER})"; \
		echo "  Master 3: $${MASTER3_IP} (user: $${MASTER3_USER})"; \
		echo "  HAProxy:  $${HAPROXY_IP} (user: $${HAPROXY_USER})"; \
		echo ""; \
	else \
		echo "$(RED)Cluster not configured$(NC)"; \
		echo "$(YELLOW)Run: ./lazykube configure$(NC)"; \
	fi
	@echo "$(YELLOW)Inventory:$(NC)"
	@ansible-inventory -i $(INVENTORY) --graph 2>/dev/null || echo "  $(RED)Inventory not found$(NC)"

kubeconfig: ## Information about KUBECONFIG
	@if [ ! -f $(KUBECONFIG) ]; then \
		echo "$(YELLOW)Kubeconfig not found. Run './lazykube install'$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Kubeconfig generated at: $(KUBECONFIG)$(NC)"
	@echo ""
	@echo "$(YELLOW)To merge with existing kubeconfig:$(NC)"
	@echo ""
	@echo "  # Backup"
	@echo "  cp ~/.kube/config ~/.kube/config.backup-\$$(date +%Y%m%d-%H%M%S)"
	@echo ""
	@echo "  # Merge"
	@echo "  KUBECONFIG=~/.kube/config:$(KUBECONFIG) kubectl config view --flatten > ~/.kube/config-merged"
	@echo "  mv ~/.kube/config-merged ~/.kube/config"
	@echo ""
	@echo "  # Switch to k3s-local cluster"
	@echo "  kubectl config use-context k3s-local"
	@echo ""
	@echo "  # Verify"
	@echo "  kubectl get nodes"
