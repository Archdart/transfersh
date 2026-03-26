# 📦 transfer.sh

A simple CLI tool to automate secure directory migration between GNU/Linux machines using `rsync` over SSH.

It includes advanced features such as temporary SSH key handling and post-transfer integrity checks.

---

## ✨ Features

- **Flexible Authentication**
  - Supports standard password authentication
  - Optional temporary SSH key generation to avoid repeated password prompts  
  - Can be disabled for troubleshooting or compatibility

- **Permission Handling**
  - Automatically adjusts source directory permissions to ensure all files are readable during transfer

- **Smart Exclusions**
  - Automatically skips temporary/system files such as:
    - `.sock`
    - `.lock`

- **Integrity Verification**
  - Compares file counts between source and destination after transfer

---

## ⚙️ Requirements

- **Source machine**
  - `rsync`
  - `ssh`

- **Destination machine**
  - Running SSH server
  - `rsync`

- **Privileges**
  - `sudo` access required on source machine (for permission adjustments)

---

## 🚀 Usage

### 1. Preparation

Copy the script to the source machine and make it executable:

```bash
chmod +x transfer.sh
```

---

### 2. Run

```bash
./transfer.sh
```

---

### 3. Interactive Prompts

The script will ask for:

- **Destination IP**
- **SSH Port** (default: `22`)
- **Source and destination paths** (e.g. `/var/www/data`)
- **Temporary SSH key usage** (`y/n`)

---

## 🔍 Technical Details

### Permission Handling

Before starting the transfer, the script runs:

```bash
chown -R $USER:$USER <source_path>
chmod -R 777 <source_path>
```

This ensures all files are accessible during transfer.

---

### Rsync Options Used

Core command:

```bash
rsync -avz -vv --exclude='*.sock' --exclude='*.lock'
```

- `-a` (archive): preserves structure, permissions, symlinks  
- `-v / -vv`: verbose output  
- `-z`: compression during transfer  
- `--info=progress2`: global progress indicator  

---

## ⚠️ Important Notes

### Excluded Files

Files with extensions `.sock` and `.lock` are ignored.

> ⚠️ This may cause differences between manual file counts and script results. This is expected behavior.

---

### Overwrite Behavior

Existing files on the destination will be updated if they have the same name.

---

### Temporary Key Cleanup

If you enable temporary SSH keys, the script will ask whether to remove them at the end.

> ✅ Recommended: remove them to keep the system clean

---

## 🛠 Troubleshooting

- **Connection errors**
  - Check IP address and SSH port  
  - Verify firewall rules on destination  

- **Sudo permission issues**
  - Ensure your user has sudo privileges on the source machine  

- **File count mismatch**
  - New files may have been created during transfer  
  - Excluded files (`.sock`, `.lock`) are not counted  

---

## 💡 Notes

This tool is designed to simplify bulk data migration tasks between Linux systems with minimal manual intervention, while maintaining transparency and control over the process.
