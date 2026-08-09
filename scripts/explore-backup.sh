#!/usr/bin/env bash
set -euo pipefail

# sudo restic -r /media/DSK/mediaserver-data/<backup>/restic --password-file /run/secrets/restic_passwd forget --keep-last 3 --dry-run
# sudo restic -r /media/DSK/mediaserver-data/<backup>/restic --password-file /run/secrets/restic_passwd prune

# 1. Configuration - adjust paths if needed

restic_repo=("/media/DSK/mediaserver-data/config-backups/restic" 
             "/media/DSK/mediaserver-data/data-backups/restic")

echo "Available Restic repositories:"
for i in "${!restic_repo[@]}"; do
  echo "$((i + 1)). ${restic_repo[$i]}"
done

echo ""
echo "Select a repository to explore (1-${#restic_repo[@]}):"
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#restic_repo[@]}" ]; then
  echo "Invalid choice. Exiting."
  exit 1
fi

RESTIC_REPO="${restic_repo[$((choice - 1))]}"
PASSWORD_FILE="/run/secrets/restic_passwd"  # Standard sops-nix secret path
MOUNT_POINT="/tmp/restic-mount"

# 2. Check if the sops secret is accessible
if [[ ! -f "$PASSWORD_FILE" ]]; then
  echo "Error: Password file not found at $PASSWORD_FILE"
  echo "Make sure sops-nix is active and decrypted properly."
  exit 1
fi

# 3. Create mount directory if it doesn't exist
mkdir -p "$MOUNT_POINT"

# 4. Handle cleanup on exit or Ctrl+C
cleanup() {
  echo ""
  echo "Unmounting $MOUNT_POINT..."
  fusermount -u -z "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
  rmdir "$MOUNT_POINT" 2>/dev/null || true
  echo "Done!"
}
trap cleanup EXIT INT TERM

# 5. Mount the repository
echo "Mounting Restic repository at $MOUNT_POINT..."
echo "You can open another terminal and browse your backups at: $MOUNT_POINT"
echo "Press Ctrl+C in this terminal to unmount and exit."
echo "--------------------------------------------------------"

restic -r "$RESTIC_REPO" --password-file "$PASSWORD_FILE" mount "$MOUNT_POINT"
