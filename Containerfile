ARG VERSION=44
ARG IMAGE_NAME=silverblue
FROM quay.io/fedora/fedora-$IMAGE_NAME:$VERSION

ARG VERSION
ARG IMAGE_NAME

ENV VERSION=$VERSION
ENV IMAGE_NAME=$IMAGE_NAME

## uBlue Kernel
COPY --from=ghcr.io/ublue-os/akmods:main-$VERSION /kernel-rpms /tmp/kernel

RUN dnf -y in /tmp/kernel/kernel*.rpm

## Framework Modules
COPY --from=ghcr.io/ublue-os/akmods:main-$VERSION / /tmp/akmods-common

RUN dnf -y in /tmp/akmods-common/rpms/common/framework-laptop-kmod-common-*.rpm /tmp/akmods-common/rpms/kmods/kmod-framework-laptop-*.rpm

## Nvidia
COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:main-$VERSION /rpms /tmp/akmods-rpms

RUN dnf5 -y upgrade --refresh mesa*

RUN bash /tmp/akmods-rpms/ublue-os/nvidia-install.sh

## Kargs
RUN mkdir -p /usr/lib/bootc/kargs.d/ && \
    echo 'kargs = ["quiet", "splash", "loglevel=3", "rd.udev.log_level=3"]' > /usr/lib/bootc/kargs.d/01-silent-boot.toml && \
    echo 'kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nouveau.modeset=0"]' > /usr/lib/bootc/kargs.d/99-blacklist-nouveau.toml

## Desktop
RUN dnf -y in virt-manager \
    lxc \
    libvirt-daemon-kvm \
    libvirt-daemon-lxc \
    distrobox \
    podman \
    plymouth \
    gnome-disk-utility \
    gnome-software \
    adw-gtk3-theme \
    input-remapper && \
    dnf -y rm firefox \
    yelp \
    gnome-tour \
    gnome-system-monitor \
    gnome-shell-extension-common \
    gnome-shell-extension-apps-menu \
    gnome-shell-extension-launch-new-instance \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-window-list \
    gnome-shell-extension-background-logo \
    malcontent-control && \
    dnf clean all

RUN systemctl enable libvirtd.service lxc.service

## Remove SUID (thanks SecureBlue <3)
COPY removesuid.sh /tmp/removesuid.sh

RUN bash /tmp/removesuid.sh && \
    systemctl enable polkit-agent-helper.socket

## Keylightd
RUN dnf -y copr enable asmx2/keylightd && \
    dnf -y in keylightd && \
    systemctl enable keylightd && \
    dnf clean all

## Controller support
RUN dnf -y in steam-devices 

## Set up Just
RUN dnf -y in just

## Set up Nix
RUN dnf install -y nix nix-daemon && dnf clean all

RUN mkdir -p /nix

COPY --chmod=644 files/ /

RUN systemctl enable nix.mount nix-store-init.service nix-daemon

## Default to adw-gtk3-dark
COPY files/etc/skel/.config/dconf/user /etc/skel/.config/dconf/user

## Signing
RUN mkdir -p /etc/pki/containers /etc/containers/registries.d

COPY cosign.pub /etc/pki/containers/hermes-bootc.pub

COPY policy.json /etc/containers/policy.json

COPY hermes-bootc.yaml /etc/containers/registries.d/hermes-bootc.yaml

## Cleanup
RUN dnf clean all && \
    rm -rf /tmp/*
