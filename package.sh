#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================="
echo "Starting IP Call Desktop Packaging Script"
echo "=========================================="

# 1. Build the application in release mode
echo "Step 1: Building Flutter app in release mode..."
flutter build linux --release

# Define paths
PROJECT_DIR="$(pwd)"
BUNDLE_DIR="${PROJECT_DIR}/build/linux/x64/release/bundle"
DIST_DIR="${PROJECT_DIR}/dist"
APPIMAGE_DIR="${DIST_DIR}/appimage"
DEB_DIR="${DIST_DIR}/deb"

# Clean up previous distribution folder
echo "Step 2: Preparing distribution directories..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
mkdir -p "${APPIMAGE_DIR}"
mkdir -p "${DEB_DIR}"

# ==========================================
# PACKAGING OPTION 1: Portable Tarball (.tar.gz)
# ==========================================
echo "Step 3: Creating portable Tarball (.tar.gz)..."
tar -czf "${DIST_DIR}/ip_call_desktop_1.0.0_linux_x64.tar.gz" -C "${BUNDLE_DIR}" .
echo "✓ Created: ${DIST_DIR}/ip_call_desktop_1.0.0_linux_x64.tar.gz"

# ==========================================
# PACKAGING OPTION 2: Debian Package (.deb)
# ==========================================
echo "Step 4: Creating Debian package (.deb)..."
# Create DEBIAN folder and control file
mkdir -p "${DEB_DIR}/DEBIAN"
cat <<EOT > "${DEB_DIR}/DEBIAN/control"
Package: ip-call-desktop
Version: 1.0.0
Architecture: amd64
Maintainer: Rayyan <rayyannur5@github>
Description: Nurse Call Desktop Application
Section: utils
Priority: optional
Depends: libc6, libgtk-3-0, libglib2.0-0, libasound2, libwebkit2gtk-4.1-0
EOT

# Create system directories
mkdir -p "${DEB_DIR}/usr/share/ip-call-desktop"
mkdir -p "${DEB_DIR}/usr/bin"
mkdir -p "${DEB_DIR}/usr/share/applications"
mkdir -p "${DEB_DIR}/usr/share/pixmaps"

# Copy build files to /usr/share/ip-call-desktop
cp -r "${BUNDLE_DIR}/"* "${DEB_DIR}/usr/share/ip-call-desktop/"

# Create wrapper script in /usr/bin/ip-call-desktop
cat <<'EOT' > "${DEB_DIR}/usr/bin/ip-call-desktop"
#!/bin/sh
exec /usr/share/ip-call-desktop/ip_call_desktop "$@"
EOT
chmod 755 "${DEB_DIR}/usr/bin/ip-call-desktop"

# Copy icon
if [ -f "${PROJECT_DIR}/assets/icons/logo_web_2.png" ]; then
    cp "${PROJECT_DIR}/assets/icons/logo_web_2.png" "${DEB_DIR}/usr/share/pixmaps/ip-call-desktop.png"
fi

# Create desktop entry
cat <<EOT > "${DEB_DIR}/usr/share/applications/ip-call-desktop.desktop"
[Desktop Entry]
Name=IP Call Desktop
Comment=Nurse Call Desktop Application
Exec=ip-call-desktop
Icon=ip-call-desktop
Type=Application
Categories=Utility;
Terminal=false
EOT
chmod 644 "${DEB_DIR}/usr/share/applications/ip-call-desktop.desktop"

# Build Debian Package
dpkg-deb --root-owner-group --build "${DEB_DIR}" "${DIST_DIR}/ip_call_desktop_1.0.0_amd64.deb"
echo "✓ Created: ${DIST_DIR}/ip_call_desktop_1.0.0_amd64.deb"

# ==========================================
# PACKAGING OPTION 3: AppImage (.AppImage)
# ==========================================
echo "Step 5: Creating AppImage..."
# Copy bundle contents to AppImage staging directory
cp -r "${BUNDLE_DIR}/"* "${APPIMAGE_DIR}/"

# Copy icon to root of AppImage
if [ -f "${PROJECT_DIR}/assets/icons/logo_web_2.png" ]; then
    cp "${PROJECT_DIR}/assets/icons/logo_web_2.png" "${APPIMAGE_DIR}/ip_call_desktop.png"
fi

# Create desktop entry in root of AppImage
cat <<EOT > "${APPIMAGE_DIR}/ip_call_desktop.desktop"
[Desktop Entry]
Name=IP Call Desktop
Comment=Nurse Call Desktop Application
Exec=ip_call_desktop
Icon=ip_call_desktop
Type=Application
Categories=Utility;
Terminal=false
EOT
chmod 644 "${APPIMAGE_DIR}/ip_call_desktop.desktop"

# Create AppRun launcher script in root of AppImage
cat <<'EOT' > "${APPIMAGE_DIR}/AppRun"
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/ip_call_desktop" "$@"
EOT
chmod 755 "${APPIMAGE_DIR}/AppRun"

# Download appimagetool if not already downloaded
APPIMAGE_TOOL="${PROJECT_DIR}/appimagetool-x86_64.AppImage"
if [ ! -f "${APPIMAGE_TOOL}" ]; then
    echo "Downloading appimagetool..."
    wget -O "${APPIMAGE_TOOL}" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x "${APPIMAGE_TOOL}"
fi

# Package AppImage
# Using --appimage-extract-and-run in case FUSE is not loaded on the host machine
"${APPIMAGE_TOOL}" --appimage-extract-and-run "${APPIMAGE_DIR}" "${DIST_DIR}/ip_call_desktop_1.0.0-x86_64.AppImage"
echo "✓ Created: ${DIST_DIR}/ip_call_desktop_1.0.0-x86_64.AppImage"

# Clean up build folders to save space
rm -rf "${APPIMAGE_DIR}"
rm -rf "${DEB_DIR}"

echo "=========================================="
echo "Packaging Completed successfully!"
echo "All packages are saved in the './dist/' folder:"
echo "1. Tarball: dist/ip_call_desktop_1.0.0_linux_x64.tar.gz"
echo "2. Debian Package: dist/ip_call_desktop_1.0.0_amd64.deb"
echo "3. AppImage: dist/ip_call_desktop_1.0.0-x86_64.AppImage"
echo "=========================================="
