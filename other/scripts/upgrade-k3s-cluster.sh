#!/bin/bash

# K3s Cluster Upgrade Script
# Upgrades the cluster with manual confirmation after the first node

set -e

# Configuration
K3S_VERSION="$1"
PRIMARY_MASTER="192.168.20.12"
ADDITIONAL_MASTERS=("192.168.20.10" "192.168.20.11" "192.168.20.13" "192.168.20.14")
WORKERS=("192.168.20.2" "192.168.20.3" "192.168.20.4" "192.168.20.5" "192.168.20.6")
USER="root"

# K3s extra arguments
K3S_EXTRA_ARGS="--disable servicelb --etcd-expose-metrics=true --kube-proxy-arg metrics-bind-address=0.0.0.0 --kube-controller-manager-arg bind-address=0.0.0.0 --kube-scheduler-arg bind-address=0.0.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

confirm_continue() {
	echo
	echo -e "${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC}"
	read -r
}

upgrade_primary_master() {
	print_status "Upgrading primary master node: $PRIMARY_MASTER"
	k3sup install \
		--ip "$PRIMARY_MASTER" \
		--user "$USER" \
		--k3s-version "$K3S_VERSION" \
		--k3s-extra-args "$K3S_EXTRA_ARGS"

	if [ $? -eq 0 ]; then
		print_success "Primary master ($PRIMARY_MASTER) upgraded successfully"
	else
		print_error "Failed to upgrade primary master ($PRIMARY_MASTER)"
		exit 1
	fi
}

upgrade_additional_masters() {
	print_status "Upgrading additional master nodes..."

	for master in "${ADDITIONAL_MASTERS[@]}"; do
		print_status "Upgrading master node: $master"
		k3sup join \
			--ip "$master" \
			--server-ip "$PRIMARY_MASTER" \
			--user "$USER" \
			--k3s-version "$K3S_VERSION" \
			--server-user "$USER" \
			--server \
			--k3s-extra-args "$K3S_EXTRA_ARGS"

		if [ $? -eq 0 ]; then
			print_success "Master node ($master) upgraded successfully"
		else
			print_error "Failed to upgrade master node ($master)"
			print_warning "Continuing with remaining nodes..."
		fi
	done
}

upgrade_workers() {
	print_status "Upgrading worker nodes..."

	for worker in "${WORKERS[@]}"; do
		print_status "Upgrading worker node: $worker"
		k3sup join \
			--ip "$worker" \
			--server-ip "$PRIMARY_MASTER" \
			--user "$USER" \
			--k3s-version "$K3S_VERSION"

		if [ $? -eq 0 ]; then
			print_success "Worker node ($worker) upgraded successfully"
		else
			print_error "Failed to upgrade worker node ($worker)"
			print_warning "Continuing with remaining nodes..."
		fi
	done
}

check_cluster_status() {
	print_status "Checking cluster status..."
	if command -v kubectl &> /dev/null; then
		echo
		kubectl get nodes -o wide
		echo
		kubectl get pods -A --field-selector=status.phase!=Running 2>/dev/null | grep -v "No resources found" || true
	else
		print_warning "kubectl not found. Please verify cluster status manually."
	fi
}

main() {
	# Check if version is provided
	if [ -z "$K3S_VERSION" ]; then
		print_error "K3s version is required!"
		echo
		echo "Usage: $0 <K3S_VERSION>"
		echo "Example: $0 v1.34.2+k3s1"
		echo
		echo "Use --help for more information."
		exit 1
	fi

	echo "========================================="
	echo "       K3s Cluster Upgrade Script       "
	echo "========================================="
	echo
	echo "Target K3s version: $K3S_VERSION"
	echo "Primary master: $PRIMARY_MASTER"
	echo "Additional masters: ${ADDITIONAL_MASTERS[*]}"
	echo "Workers: ${WORKERS[*]}"
	echo

	# Check if k3sup is available
	if ! command -v k3sup &> /dev/null; then
		print_error "k3sup is not installed or not in PATH"
		exit 1
	fi

	print_warning "This will upgrade your entire k3s cluster to version $K3S_VERSION."
	confirm_continue

	# Step 1: Upgrade primary master
	echo "========================================="
	echo "Step 1: Upgrading Primary Master"
	echo "========================================="
	upgrade_primary_master

	# Manual confirmation after first node
	echo
	echo "========================================="
	echo "Primary master upgrade completed!"
	echo "========================================="
	print_warning "Please verify the primary master is working correctly."
	print_warning "Check cluster status, workloads, and connectivity before proceeding."
	echo
	check_cluster_status
	echo
	print_warning "Continue with remaining nodes?"
	confirm_continue

	# Step 2: Upgrade additional masters
	echo "========================================="
	echo "Step 2: Upgrading Additional Masters"
	echo "========================================="
	upgrade_additional_masters

	# Step 3: Upgrade workers
	echo "========================================="
	echo "Step 3: Upgrading Worker Nodes"
	echo "========================================="
	upgrade_workers

	# Final status check
	echo
	echo "========================================="
	echo "Cluster upgrade completed!"
	echo "========================================="
	check_cluster_status

	print_success "All nodes have been processed. Please verify cluster functionality."
}

# Script usage
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	echo "Usage: $0 <K3S_VERSION>"
	echo
	echo "Upgrades the entire k3s cluster to the specified version."
	echo "K3s version is required and must be provided."
	echo
	echo "Examples:"
	echo "  $0 v1.34.2+k3s1      # Use specific version"
	echo "  $0 v1.35.0+k3s1      # Use newer version"
	echo
	echo "The script will:"
	echo "  1. Upgrade the primary master node"
	echo "  2. Wait for manual confirmation"
	echo "  3. Upgrade additional master nodes"
	echo "  4. Upgrade worker nodes"
	echo
	exit 0
fi

# Run main function
main "$@"