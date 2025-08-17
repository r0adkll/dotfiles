# Google Drive Setup with rclone

This configuration sets up Google Drive mounting using rclone on your NixOS system.

## Initial Setup

1. **Configure rclone for Google Drive:**
   ```bash
   rclone config
   ```

2. **Follow the interactive setup:**
   - Choose `n` for new remote
   - Name: `gdrive`
   - Storage type: `13` (Google Drive)
   - Leave `client_id` and `client_secret` empty (uses rclone's built-in credentials)
   - Scope: `1` (Full access to all files)
   - Leave `root_folder_id` empty
   - Leave `service_account_file` empty
   - Advanced config: `n`
   - Auto config: `y` (this will open a browser for OAuth)
   - Team drive: `n`
   - Confirm: `y`

3. **Extract the token:**
   ```bash
   cat ~/.config/rclone/rclone.conf
   ```
   
   Copy the entire `token` line value (the JSON object).

4. **Add token to SOPS secrets:**
   ```bash
   cd /home/r0adkll/.config/nixos
   sops secrets/secrets.yaml
   ```
   
   Add the following entry:
   ```yaml
   rclone:
     gdrive-token: '{"access_token":"...","token_type":"Bearer","refresh_token":"...","expiry":"..."}'
   ```

5. **Rebuild and switch:**
   ```bash
   sudo nixos-rebuild switch
   ```

6. **Start the mount service:**
   ```bash
   sudo systemctl enable mount-gdrive
   sudo systemctl start mount-gdrive
   ```

## Usage

- Google Drive will be mounted at `/mnt/gdrive`
- The service runs automatically on boot
- Check status: `sudo systemctl status mount-gdrive`
- View logs: `sudo journalctl -u mount-gdrive -f`

## Manual Commands

- Mount manually: `rclone mount gdrive: /mnt/gdrive --daemon`
- Unmount: `fusermount -u /mnt/gdrive`
- List files: `rclone ls gdrive:`
- Copy files: `rclone copy /local/path gdrive:remote/path`

## Troubleshooting

1. **Token expires:** Re-run the setup process and update the token in SOPS
2. **Mount fails:** Check network connectivity and token validity
3. **Permission issues:** Ensure the mount point exists and has correct permissions

## Helper Script

A helper script `setup-gdrive` is available to guide you through the initial setup process.
