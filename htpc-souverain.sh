#!/bin/bash

# ==============================================================================
# PROJET HORS LIGNE : DÉPLOIEMENT HTPC SOUVERAIN (KODI + MPV)
# VERSION : 2.0 (Intégration Pilotes, RAM Cache, HDR Auto & Langues)
# ==============================================================================

# ==============================================================================
# PHASE 0 : NETTOYAGE DES VESTIGES (RESET / IDEMPOTENCE)
# ==============================================================================
whiptail --title "Initialisation" --infobox "Nettoyage des traces d'une éventuelle installation précédente..." 8 60

rm -rf ~/.config/mpv/shaders ~/.config/mpv/scripts ~/.config/aacs
rm -f ~/.smbcredentials
sudo sed -i '\|/mnt/Nas_Media|d' /etc/fstab
sudo umount /mnt/Nas_Media 2>/dev/null
sudo rm -rf /mnt/Nas_Media

# ==============================================================================
# PHASE 1 : DÉTECTION DU GPU
# ==============================================================================
whiptail --title "Analyse matérielle" --infobox "Recherche des processeurs graphiques (PCIe)..." 8 60

RAW_GPU_LIST=$(lspci | grep -iE 'vga|3d|display' | cut -d ':' -f 3 | sed 's/^[ \t]*//')
GPU_COUNT=$(echo "$RAW_GPU_LIST" | grep -c '^')

if [ "$GPU_COUNT" -gt 1 ]; then
    FINAL_VENDOR=$(whiptail --title "Multi-GPU Détecté" --menu "Sélectionnez le constructeur de la carte dédiée :" 14 65 3 \
    "NVIDIA" "GeForce RTX/GTX/Quadro" "AMD" "Radeon RX / RDNA" "INTEL" "Intel HD Graphics" 3>&1 1>&2 2>&3)
else
    if echo "$RAW_GPU_LIST" | grep -iq "nvidia"; then DETECTED_VENDOR="NVIDIA"
    elif echo "$RAW_GPU_LIST" | grep -iq "amd\|radeon"; then DETECTED_VENDOR="AMD"
    elif echo "$RAW_GPU_LIST" | grep -iq "intel"; then DETECTED_VENDOR="INTEL"
    else DETECTED_VENDOR="INCONNU"; fi

    if (whiptail --title "Détection Matérielle" --yesno "Matériel graphique : $RAW_GPU_LIST\nPuce estimée : $DETECTED_VENDOR\n\nConfirmer ?" 10 75); then
        FINAL_VENDOR=$DETECTED_VENDOR
    else
        FINAL_VENDOR=$(whiptail --title "Sélection Manuelle" --menu "Constructeur :" 12 60 3 "NVIDIA" "" "AMD" "" "INTEL" "" 3>&1 1>&2 2>&3)
    fi
fi

# ==============================================================================
# PHASE 2 : DÉTECTION VIDÉO ET AUDIO (KERNEL)
# ==============================================================================
CONNECTED_PORT_FILE=$(grep -l "^connected" /sys/class/drm/*/status 2>/dev/null | head -n 1)
if [ -n "$CONNECTED_PORT_FILE" ]; then
    DISPLAY_NAME=$(echo "$CONNECTED_PORT_FILE" | awk -F'/' '{print $5}' | cut -d'-' -f2-)
fi
RAW_DISPLAY=$(kscreen-doctor -o 2>/dev/null | grep -A 2 "connected")
if echo "$RAW_DISPLAY" | grep -iq "hdr"; then DISPLAY_HDR="Oui"; else DISPLAY_HDR="Non"; fi

FINAL_DISPLAY=${DISPLAY_NAME:-HDMI-A-1}
FINAL_HDR=$DISPLAY_HDR
FINAL_AUDIO=$(aplay -L 2>/dev/null | grep -iE "^hdmi:" | head -n 1 | tr -d '\n')
if [ -z "$FINAL_AUDIO" ]; then FINAL_AUDIO="hdmi:CARD=HDMI,DEV=0"; fi

# ==============================================================================
# PHASE 2.5 : INSTALLATION SOCLE LOGICIEL
# ==============================================================================
whiptail --title "Installation" --infobox "Installation du socle (Kodi, mpv, libdvdcss)..." 8 60
clear
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf install rpmfusion-free-release-tainted -y
sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
sudo dnf install mpv kodi socat libbluray libdvdcss unzip cifs-utils -y
sudo usermod -aG cdrom $USER

# ==============================================================================
# PHASE 2.6 : DÉPLOIEMENT DES PILOTES GRAPHIQUES
# ==============================================================================
if [ "$FINAL_VENDOR" = "NVIDIA" ]; then
    echo -e "\e[1;32m[NVIDIA] Installation du pilote propriétaire...\e[0m"
    sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y
elif [ "$FINAL_VENDOR" = "INTEL" ]; then
    echo -e "\e[1;34m[INTEL] Installation des ponts VAAPI...\e[0m"
    sudo dnf install intel-media-driver libva-intel-driver -y
elif [ "$FINAL_VENDOR" = "AMD" ]; then
    echo -e "\e[1;31m[AMD] Vérification des pilotes Vulkan (Mesa)...\e[0m"
    sudo dnf install mesa-vulkan-drivers mesa-dri-drivers -y
fi

# ==============================================================================
# PHASE 3 : UPSCALING NEURONAL
# ==============================================================================
mkdir -p ~/.config/mpv/shaders ~/.config/mpv/scripts ~/.config/autostart ~/.kodi/userdata/ ~/.config/aacs/

CHOIX_SHADER=$(whiptail --title "Architecture Upscaling" --menu "Réseau FSRCNNX pour $FINAL_VENDOR :" 12 70 2 "16-bits" "Exigeant (RTX, RX...)" "8-bits" "Léger (Intel HD...)" 3>&1 1>&2 2>&3)
if [ "$CHOIX_SHADER" = "16-bits" ]; then NOM_FICHIER="FSRCNNX_x2_16-0-4-1.glsl"
else NOM_FICHIER="FSRCNNX_x2_8-0-4-1.glsl"; fi

curl -L -# -o ~/.config/mpv/shaders/$NOM_FICHIER "https://github.com/igv/FSRCNN-TensorFlow/releases/download/1.1/$NOM_FICHIER"
FINAL_SHADER_FILE=$NOM_FICHIER

# ==============================================================================
# PHASE 3.5 : PRÉFÉRENCES LINGUISTIQUES
# ==============================================================================
if (whiptail --title "Langues" --yesno "Priorité audio par défaut ?\n\n► OUI : Version Française (VF) + Sous-titres forcés\n► NON : Version Originale (VOSTFR) + Sous-titres complets" 10 70); then
    MPV_ALANG="alang=fr,fre,fra,en,eng\nslang=fr,fre,fra\nsubs-with-matching-audio=no"
else
    MPV_ALANG="alang=en,eng,ja,jpn,ko,kor,auto\nslang=fr,fre,fra\nsubs-with-matching-audio=yes"
fi

# ==============================================================================
# PHASE 3.8 : TAMPON MÉMOIRE (RAM CACHE)
# ==============================================================================
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
CHOIX_CACHE=$(whiptail --title "Tampon Mémoire" --menu "RAM Dispo : ${TOTAL_RAM_MB} Mo\nAllouer un cache pour éviter les coupures réseau/DVD ?" 12 70 4 "500M" "Léger" "1G" "Standard" "2G" "Lourd" "Désactivé" "Direct" 3>&1 1>&2 2>&3)
if [ "$CHOIX_CACHE" = "Désactivé" ] || [ -z "$CHOIX_CACHE" ]; then MPV_CACHE="cache=no"
else MPV_CACHE="cache=yes\ndemuxer-max-bytes=$CHOIX_CACHE\ndemuxer-max-back-bytes=100M"; fi

# ==============================================================================
# PHASE 4 : FORGE MPV.CONF
# ==============================================================================
MPV_HWDEC=$([ "$FINAL_VENDOR" = "NVIDIA" ] && echo "nvdec" || echo "vaapi")
MPV_HDR=$([ "$FINAL_HDR" = "Oui" ] && echo "target-colorspace-hint=yes" || echo "target-colorspace-hint=no\ntarget-trc=auto\ntone-mapping=auto")

cat <<EOF > ~/.config/mpv/mpv.conf
vo=gpu-next
gpu-api=vulkan
gpu-context=waylandvk
hwdec=$MPV_HWDEC

$(echo -e $MPV_HDR)

audio-device=$FINAL_AUDIO
ao=alsa
audio-exclusive=yes
audio-spdif=ac3,dts,dts-hd,eac3,truehd

$(echo -e $MPV_ALANG)

$(echo -e $MPV_CACHE)
video-sync=display-resample

fullscreen=yes
keep-open=yes

[upscale-dvd]
profile-cond=width < 1280 and height < 720
profile-restore=copy
deinterlace=yes
deband=yes
deband-iterations=2
deband-threshold=35
deband-range=20
glsl-shader="~~/shaders/$FINAL_SHADER_FILE"
scale=ewa_lanczos
cscale=ewa_lanczos

[upscale-bluray]
profile-cond=(width >= 1280 or height >= 720) and (width < 3840 and height < 2160)
profile-restore=copy
glsl-shader="~~/shaders/$FINAL_SHADER_FILE"
scale=ewa_lanczossharp
cscale=ewa_lanczossharp

[passthrough-4k]
profile-cond=width >= 3840 or height >= 2160
profile-restore=copy
glsl-shaders-clr
scale=bilinear
EOF

# ==============================================================================
# PHASE 4.8 : SCRIPT BASCULE HDR (LUA)
# ==============================================================================
cat <<EOF > ~/.config/mpv/scripts/auto-hdr.lua
local mp = require 'mp'
function check_hdr(name, value)
    if value and (value["colorlevels"] == "limited" or value["colorlevels"] == "full") then
        if (value["color-space"] == "bt.2020-ncl" or value["color-space"] == "bt.2020-c") then
            os.execute("kscreen-doctor output.$FINAL_DISPLAY.hdr.enable")
        else
            os.execute("kscreen-doctor output.$FINAL_DISPLAY.hdr.disable")
        end
    end
end
function on_file_end()
    os.execute("kscreen-doctor output.$FINAL_DISPLAY.hdr.disable")
end
mp.observe_property("video-out-params", "native", check_hdr)
mp.register_event("end-file", on_file_end)
EOF

# ==============================================================================
# PHASE 5 : AACS KEYDB ET NAS (Optionnel)
# ==============================================================================
curl -L -# -o /tmp/keydb.zip "http://fvonline-db.bplaced.net/fv_download.php?lang=fra"
unzip -q -o /tmp/keydb.zip -d ~/.config/aacs/ && rm -f /tmp/keydb.zip

if (whiptail --title "NAS" --yesno "Connecter un NAS local ?" 8 60); then
    NAS_IP=$(whiptail --inputbox "IP du NAS :" 8 60 3>&1 1>&2 2>&3)
    NAS_SHARE=$(whiptail --inputbox "Dossier partagé :" 8 60 3>&1 1>&2 2>&3)
    NAS_USER=$(whiptail --inputbox "Utilisateur :" 8 60 3>&1 1>&2 2>&3)
    NAS_PASS=$(whiptail --passwordbox "Mot de passe :" 8 60 3>&1 1>&2 2>&3)
    
    CRED_FILE="$HOME/.smbcredentials"
    echo -e "username=$NAS_USER\npassword=$NAS_PASS" > $CRED_FILE
    chmod 600 $CRED_FILE
    sudo mkdir -p /mnt/Nas_Media
    echo "//$NAS_IP/$NAS_SHARE /mnt/Nas_Media cifs credentials=$CRED_FILE,uid=$(id -u),gid=$(id -g),iocharset=utf8,_netdev,nofail 0 0" | sudo tee -a /etc/fstab > /dev/null
    sudo mount -a
fi

# ==============================================================================
# PHASE 6 & 7 : LE CERBÈRE ET KODI BRIDGE
# ==============================================================================
cat <<EOF > ~/.kodi/userdata/playercorefactory.xml
<playercorefactory>
    <rules action="prepend">
        <rule dvd="true" player="mpv-launcher"/>
        <rule bluray="true" player="mpv-launcher"/>
        <rule optical="true" player="mpv-launcher"/>
        <rule video="true" player="mpv-launcher"/>
    </rules>
    <players>
        <player name="mpv-launcher" type="ExternalPlayer" audio="false" video="true">
            <filename>$HOME/.config/mpv/htpc-launcher.sh</filename>
            <args>"{1}"</args>
            <hidexbmc>false</hidexbmc>
        </player>
    </players>
</playercorefactory>
EOF

if (whiptail --title "Menus" --yesno "Lancer les disques avec menus Java ?" 8 60); then
    sudo dnf install java-latest-openjdk-headless -y
    L_BD="bd://" && L_DVD="dvdnav://"
else
    L_BD="bd://longest" && L_DVD="dvd://"
fi

cat <<EOF > ~/.config/mpv/htpc-launcher.sh
#!/bin/bash
FILE="\$1"
MPV_ARGS="--config-dir=$HOME/.config/mpv --input-ipc-server=/tmp/mpvsocket"
if [[ "\${FILE,,}" == *bdmv/index.bdmv* ]] || [[ "\${FILE,,}" == *.iso ]]; then
    /usr/bin/mpv \$MPV_ARGS $L_BD --bluray-device="\${FILE%/*/*}"
elif [[ "\${FILE,,}" == *video_ts/video_ts.ifo* ]]; then
    /usr/bin/mpv \$MPV_ARGS $L_DVD --dvd-device="\${FILE%/*/*}"
elif [[ "\${FILE}" == /dev/sr* ]] || [[ "\${FILE}" == *optical* ]]; then
    /usr/bin/mpv \$MPV_ARGS $L_DVD --dvd-device=/dev/sr0 --bluray-device=/dev/sr0
else
    /usr/bin/mpv \$MPV_ARGS "\$FILE"
fi
EOF
chmod +x ~/.config/mpv/htpc-launcher.sh

# ==============================================================================
# PHASE 8 : MODE KIOSQUE
# ==============================================================================
if (whiptail --title "Kiosque" --yesno "Démarrer directement sur Kodi ?" 8 60); then
    sudo mkdir -p /etc/sddm.conf.d
    sudo bash -c "cat <<EOF > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER
Session=plasma
EOF"
    cp /usr/share/applications/kodi.desktop ~/.config/autostart/
fi

whiptail --title "Terminé" --msgbox "Déploiement achevé.\n\n⚠️ Redémarrez le PC pour valider les droits DVD et les pilotes matériels." 10 60