#!/bin/bash

echo "=== Tambah SSH Key ke GitHub Otomatis ==="

# === INPUT ===
read -p "Masukkan email GitHub kamu: " email
read -s -p "Masukkan Personal Access Token (PAT): " token
echo ""

# === VALIDASI ===
if [[ -z "$email" || -z "$token" ]]; then
    echo "[❌] Email dan Token tidak boleh kosong."
    exit 1
fi

# === PATH KEY ===
KEY_PATH="$HOME/.ssh/id_ed25519"
PUB_PATH="${KEY_PATH}.pub"

# === CEK / BUAT SSH KEY ===
if [ ! -f "$KEY_PATH" ]; then
    ssh-keygen -t ed25519 -C "$email" -f "$KEY_PATH" -N ""
    if [ $? -ne 0 ]; then
        echo "[❌] Gagal membuat SSH key."
        exit 1
    fi
    echo "[✔] SSH key berhasil dibuat."
else
    echo "[✔] SSH key sudah ada."
fi

# === CEK SSH AGENT ===
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH" > /dev/null
echo "[✔] SSH key aktif di ssh-agent."

# === CEK KE GITHUB ===
PUB_KEY=$(cat "$PUB_PATH")
EXISTING_KEYS=$(curl -s -H "Authorization: token $token" https://api.github.com/user/keys)

if echo "$EXISTING_KEYS" | grep -q "$PUB_KEY"; then
    echo "[✔] SSH key ini sudah ada di akun GitHub."
else
    TITLE="SSH-Key-$(hostname)-$(date +%Y%m%d%H%M)"
    RESP=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $token" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$TITLE\", \"key\":\"$PUB_KEY\"}" \
        https://api.github.com/user/keys)

    if [ "$RESP" == "201" ]; then
        echo "[✔] SSH key berhasil ditambahkan ke GitHub!"
    elif [ "$RESP" == "422" ]; then
        echo "[⚠] SSH key sudah ada di GitHub (duplikat)."
    elif [ "$RESP" == "401" ]; then
        echo "[❌] Token tidak valid atau tidak punya akses!"
        exit 1
    else
        echo "[❌] Gagal menambahkan SSH key. Kode: $RESP"
        exit 1
    fi
fi

# === TES KONEKSI ===
echo ""
echo "Tes koneksi ke GitHub..."
ssh -T git@github.com
