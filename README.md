# 🎬 Projet Hors Ligne : Déploiement HTPC Souverain (Kodi + mpv)

Ce dépôt héberge le script d'automatisation officiel permettant de transformer n'importe quel ordinateur ou mini-PC sous **Fedora Linux** en une platine de salon haut de gamme ultra-performante. 

Né d'une philosophie axée sur la souveraineté numérique et la préservation des médias physiques (UHD, Blu-ray, DVD) face aux contraintes du streaming, ce projet propose une synergie parfaite entre l'ergonomie de l'interface **Kodi** et la puissance brute du moteur de rendu **mpv**.

---

## 🚀 Fonctionnalités Centrales

* **Analyse & Détection Matérielle (Multi-GPU) :** Identification automatique de l'architecture graphique (NVIDIA, AMD, Intel) et déploiement des pilotes dédiés (pilotes propriétaires `akmod-nvidia` avec cœurs CUDA ou implémentations Mesa/VAAPI optimisées).
* **Moteur de Rendu Ultra-Haute Qualité :** Configuration avancée de `mpv` s'appuyant sur l'API Vulkan sous Wayland (`vo=gpu-next`) pour maximiser la fidélité de l'image.
* **Upscaling Neuronal (FSRCNNX) :** Intégration automatique du shader de traitement d'image par réseaux de neurones (variantes 8-bits ou 16-bits selon la puissance de la puce) pour magnifier les sources SD (DVD) et HD (Blu-ray 1080p).
* **Gestion Intelligente du Cache RAM (Pre-fetch) :** Évaluation de la mémoire vive globale du système et allocation dynamique d'un tampon mémoire massif pour immuniser la lecture contre les micro-coupures réseau (NAS) ou les latences mécaniques des lecteurs optiques externes.
* **Fluidité Cinéma Absolue (Autoframerate 24p) :** Resynchronisation fine de l'horloge interne (`display-resample`) associée au basculement de fréquence HDMI natif pour éradiquer définitivement l'effet de *judder*.
* **Bascule HDR Automatique (Script LUA) :** Déploiement d'un démon en arrière-plan qui surveille l'espace colorimétrique (BT.2020) afin de piloter l'activation de la dalle de l'écran en HDR, avec restauration propre du mode SDR en fin de lecture.
* **Le "Cerbère" de Routage :** Script lanceur d'interception permettant de contourner les restrictions d'encryptage et de forcer la lecture transparente des structures de dossiers (BDMV, VIDEO_TS), fichiers ISO et disques physiques.
* **Ancrage Réseau CIFS/FSTAB :** Montage direct au niveau du noyau Linux pour un accès instantané et ultra-rapide aux partages réseau du NAS local.
* **Mode Kiosque Épuré :** Configuration optionnelle de la session graphique (SDDM) pour un démarrage automatique direct en plein écran, offrant l'illusion parfaite d'une platine matérielle dédiée.

---

## 🛠️ Architecture du Script

L'installation est entièrement modulaire et s'exécute selon une logique séquentielle stricte :
1.  **Phase 0 :** Nettoyage des vestiges (Garantit l'idempotence du script)
2.  **Phase 1 :** Détection et isolation du processeur graphique
3.  **Phase 2 :** Interrogation du noyau Linux (Résolution, ports DRM, capacités audio)
4.  **Phase 2.5 & 2.6 :** Injection des dépôts requis (`Tainted`), des logiciels et des pilotes spécifiques
5.  **Phase 3 & 3.5 :** Rapatriement des shaders neuronaux et verrouillage des préférences linguistiques (VF/VOSTFR)
6.  **Phase 3.8 :** Évaluation de la RAM et calcul du tampon de sécurité
7.  **Phase 4 & 4.8 :** Forge de la configuration `mpv.conf` et écriture du script d'automatisme HDR (`auto-hdr.lua`)
8.  **Phase 5, 6 & 7 :** Déploiement de la base de données AACS (`keydb.cfg`), création du pont XML de Kodi et écriture du script lanceur d'interception
9.  **Phase 8 :** Configuration optionnelle de l'illusion de la platine (Autologin Kiosque)

---

## 💻 Utilisation

### Prérequis
* Une installation fraîche ou existante de **Fedora Linux** (Workstation ou Spin KDE Plasma recommandée).
* Une connexion internet active.
* Les privilèges d'administrateur (`sudo`).

### Exécution du déploiement
Pour déployer l'environnement complet, clonez ce dépôt ou téléchargez le script, puis exécutez les commandes suivantes dans votre terminal :

```bash
chmod +x install-htpc-souverain.sh
./install-htpc-souverain.sh
