#!/bin/bash

# ================================
# Log file
# ================================
LOG_FILE="build_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ================================
# Colors
# ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ================================
# Helper Functions
# ================================
error_exit() {
    echo -e "${RED}$1${RESET}"
    exit 1
}

print_header() {
    echo -e "${GREEN}============================${RESET}"
    echo -e "${GREEN}$1${RESET}"
    echo -e "${GREEN}============================${RESET}"
}

cleanup_repos() {
    echo -e "${YELLOW}Performing cleanup...${RESET}"
    rm -rf .repo/local_manifests/
    rm -rf hardware/qcom-caf/common
    rm -rf packages/apps/ThemePicker
    rm -rf vendor/qcom/opensource/healthd-ext
    rm -rf vendor/lineage
    print_header "Cleanup completed"
    sleep 0.5
    clear
}

clone_repo() {
    local repo_url=$1
    local branch=$2
    local dest=$3
    echo -e "${CYAN}Cloning $dest...${RESET}"
    git clone --depth 1 -b "$branch" "$repo_url" "$dest" || error_exit "Failed to clone $dest"
    print_header "$dest clone success"
    sleep 0.5
    clear
}

clone_hal() {
    local url=$1
    local path=$2
    local branch=$3
    rm -rf "$path"
    git clone --depth 1 -b "$branch" "$url" "$path" || error_exit "Failed to clone HAL $path"
}

# ================================
# Check/Create LineageOS-MicroG directory
# ================================
LINEAGE_DIR="LineageOS-MicroG"

if [ "$(basename "$PWD")" != "$LINEAGE_DIR" ]; then
    echo -e "${CYAN}Not in $LINEAGE_DIR directory. Checking/Creating...${RESET}"
    
    if [ -d "$HOME/$LINEAGE_DIR" ]; then
        cd "$HOME/$LINEAGE_DIR" || error_exit "Failed to cd to $HOME/$LINEAGE_DIR"
        echo -e "${GREEN}Changed to existing directory: $PWD${RESET}"
    else
        echo -e "${YELLOW}Creating $HOME/$LINEAGE_DIR...${RESET}"
        mkdir -p "$HOME/$LINEAGE_DIR" || error_exit "Failed to create $HOME/$LINEAGE_DIR"
        cd "$HOME/$LINEAGE_DIR" || error_exit "Failed to cd to $HOME/$LINEAGE_DIR"
        echo -e "${GREEN}Created and changed to: $PWD${RESET}"
    fi
    sleep 1
else
    echo -e "${GREEN}Already in $LINEAGE_DIR directory: $PWD${RESET}"
fi

# ================================
# Main Script
# ================================
echo -e "${CYAN}Starting LOS 23.2 build script...${RESET}"
echo -e "${CYAN}Log file: $LOG_FILE${RESET}"

cleanup_repos

# Initialize LOS repo
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs || error_exit "Repo init failed"
print_header "Repo init success"

# Clone local manifests
clone_repo "https://github.com/saroj-nokia/local_manifests_sapphire" "sapphire16" ".repo/local_manifests"

# Create MicroG manifest
echo -e "${CYAN}Creating MicroG manifest...${RESET}"
cat > .repo/local_manifests/microg.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="lineageos4microg"
            fetch="https://github.com/lineageos4microg/" />

    <project path="vendor/partner_gms"
             name="android_vendor_partner_gms"
             remote="lineageos4microg"
             revision="master" />
</manifest>
EOF
print_header "MicroG manifest created"

# Sync MicroG vendor
echo -e "${CYAN}Syncing MicroG vendor...${RESET}"
repo sync vendor/partner_gms || error_exit "Failed to sync MicroG vendor"
print_header "MicroG vendor synced"

# Sync repo
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j14 || error_exit "Repo sync failed"
print_header "Repo sync success"

# Clone HALs
echo -e "${CYAN}Cloning HALs for SM6225...${RESET}"
clone_hal "https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git" "hardware/qcom-caf/common" "lineage-23.2"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git" "hardware/qcom-caf/sm6225/audio/agm" "lineage-22.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_arpal-lx.git" "hardware/qcom-caf/sm6225/audio/pal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git" "hardware/qcom-caf/sm6225/data-ipa-cfg-mgr" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git" "hardware/qcom-caf/sm6225/dataipa" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_display.git" "hardware/qcom-caf/sm6225/display" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_media.git" "hardware/qcom-caf/sm6225/media" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_audio.git" "hardware/qcom-caf/sm6225/audio/primary-hal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/device_qcom_sepolicy_vndr.git" "device/qcom/sepolicy_vndr/sm6225" "lineage-23.2-caf-sm6225"
print_header "HALs cloned"

# Clone Via browser to packages/apps/Via
echo -e "${CYAN}Cloning Via browser...${RESET}"
mkdir -p packages/apps/Via
git clone --depth 1 https://github.com/AviumUI/android_packages_apps_Via.git packages/apps/Via
rm -rf packages/apps/Via/.git
print_header "Via browser cloned to packages/apps/Via"

# Cleanup vendor
rm -rf vendor/lineage
print_header "Vendor cleanup completed"

# Clone modified vendor
clone_repo "https://github.com/sapphire-sm6225/android_vendor_lineage.git" "lineage-23.2" "vendor/lineage"

# Add Via browser to device.mk
DEVICE_MK="device/xiaomi/sapphire/device.mk"
if [ -f "$DEVICE_MK" ]; then
    echo "PRODUCT_PACKAGES += Via" >> "$DEVICE_MK"
    print_header "Via added to device.mk"
else
    echo -e "${YELLOW}device.mk not found, skipping Via addition${RESET}"
fi

# Comment Gapps line and set WITH_GMS to false in lineage_sapphire.mk
LINEAGE_SAPPHIRE_MK="device/xiaomi/sapphire/lineage_sapphire.mk"
if [ -f "$LINEAGE_SAPPHIRE_MK" ]; then
    sed -i 's/^-include vendor\/gapps\/arm64\/arm64-vendor.mk/#-include vendor\/gapps\/arm64\/arm64-vendor.mk/' "$LINEAGE_SAPPHIRE_MK"
    sed -i 's/WITH_GMS := true/WITH_GMS := false/' "$LINEAGE_SAPPHIRE_MK"
    print_header "Gapps commented and WITH_GMS set to false in lineage_sapphire.mk"
else
    echo -e "${YELLOW}lineage_sapphire.mk not found, skipping modifications${RESET}"
fi

# Patch Signature Spoofing
COMPUTER_ENGINE="frameworks/base/services/core/java/com/android/server/pm/ComputerEngine.java"
if grep -q 'if (!isDebuggable())' "$COMPUTER_ENGINE"; then
    sed -i '/if (!isDebuggable()) {/{N;N;d}' "$COMPUTER_ENGINE"
    print_header "Signature Spoofing patch applied"
else
    echo -e "${YELLOW}Signature Spoofing patch: block not found or already patched${RESET}"
fi

# Setup build environment
source build/envsetup.sh
export BUILD_USERNAME=WhoFoss
export BUILD_HOSTNAME=los23
export SKIP_ABI_CHECKS=true
mkdir -p out/target/product/sapphire/obj/KERNEL_OBJ/usr

# ================================
# Build ROM
# ================================
export WITH_MICROG=true    # ativa o MicroG
brunch sapphire user || error_exit "Brunch failed"

print_header "Build process completed successfully!"
echo -e "${GREEN}Log saved to: $LOG_FILE${RESET}"
