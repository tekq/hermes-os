ARG VERSION=44
ARG IMAGE_NAME=silverblue
FROM quay.io/fedora/fedora-$IMAGE_NAME:$VERSION

ENV IMAGE_NAME=silverblue
ENV VERSION=44

COPY --from=ghcr.io/ublue-os/akmods:main-${VERSION} /kernel-rpms /tmp/kernel

RUN dnf -y in /tmp/kernel/kernel*.rpm

COPY --from=ghcr.io/ublue-os/akmods:main-44 / /tmp/akmods-common

RUN dnf -y in /tmp/akmods-common/rpms/common/framework-laptop-kmod-common-*.rpm /tmp/akmods-common/rpms/kmods/kmod-framework-laptop-*.rpm

COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:main-44 /rpms /tmp/akmods-rpms

RUN dnf5 -y upgrade --refresh mesa*

RUN bash /tmp/akmods-rpms/ublue-os/nvidia-install.sh

RUN mkdir -p /usr/lib/bootc/kargs.d/ && \
    echo 'kargs = ["quiet", "splash", "loglevel=3", "rd.udev.log_level=3"]' > /usr/lib/bootc/kargs.d/01-silent-boot.toml && \
    echo 'kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nouveau.modeset=0"]' > /usr/lib/bootc/kargs.d/99-blacklist-nouveau.toml

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
    gnome-system-monitor \
    gnome-shell-extension-common \
    gnome-shell-extension-apps-menu \
    gnome-shell-extension-launch-new-instance \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-window-list \
    gnome-shell-extension-background-logo \
    malcontent-control && \
    dnf clean all

RUN dnf -y in steam-devices 

RUN dnf -y in just

RUN dnf install -y nix nix-daemon && dnf clean all

RUN mkdir -p /nix

COPY --chmod=644 files/ /

RUN systemctl enable nix.mount nix-store-init.service nix-daemon

COPY files/etc/skel/.config/dconf/user /etc/skel/.config/dconf/user

RUN systemctl enable libvirtd.service lxc.service

RUN mkdir -p /etc/pki/containers /etc/containers/registries.d

COPY cosign.pub /etc/pki/containers/hermes-bootc.pub

COPY policy.json /etc/containers/policy.json

COPY hermes-bootc.yaml /etc/containers/registries.d/hermes-bootc.yaml

RUN dnf clean all && \
    rm -rf /tmp/*
