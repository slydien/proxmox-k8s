#!/usr/bin/env bash
# Upload Ubuntu 24.04 cloud image to Proxmox local ISO storage.
# Usage: ./scripts/upload-ubuntu-image.sh <proxmox_ip> [proxmox_user]
#
# Prerequisites: wget (or curl), ssh access to Proxmox host as root.

set -euo pipefail

PROXMOX_IP="${1:?Usage: $0 <proxmox_ip> [proxmox_user]}"
PROXMOX_USER="${2:-root}"
IMAGE_NAME="ubuntu-24.04-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
REMOTE_PATH="/var/lib/vz/template/iso/${IMAGE_NAME}"

echo "==> Checking if image already exists on Proxmox..."
if ssh "${PROXMOX_USER}@${PROXMOX_IP}" "test -f ${REMOTE_PATH}"; then
  echo "    Image already present, skipping upload."
  exit 0
fi

echo "==> Downloading ${IMAGE_NAME} locally..."
TMP_FILE=$(mktemp /tmp/ubuntu-cloudimg-XXXXXX.img)
trap 'rm -f "${TMP_FILE}"' EXIT

if command -v wget &>/dev/null; then
  wget -q --show-progress -O "${TMP_FILE}" "${IMAGE_URL}"
elif command -v curl &>/dev/null; then
  curl -L --progress-bar -o "${TMP_FILE}" "${IMAGE_URL}"
else
  echo "ERROR: wget or curl is required." >&2
  exit 1
fi

echo "==> Uploading to ${PROXMOX_USER}@${PROXMOX_IP}:${REMOTE_PATH}..."
scp "${TMP_FILE}" "${PROXMOX_USER}@${PROXMOX_IP}:${REMOTE_PATH}"

echo "==> Done. Image available at ${REMOTE_PATH} on Proxmox."
