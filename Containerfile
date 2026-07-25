FROM quay.io/fedora/fedora-silverblue:44

RUN dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo && \
    dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo && \
    dnf5 -y config-manager setopt fedora-multimedia.priority=90 && \
    dnf5 -y config-manager setopt fedora-nvidia.priority=90

## Fake it till you make it
RUN dnf5 -y in akmods && \
    mv /usr/bin/akmodsbuild{,.bak} && \
    ln -s /usr/bin/true /usr/bin/akmodsbuild

## Framework (gangster) shit
RUN dnf5 -y copr enable ublue-os/akmods && \
    dnf5 -y in framework-laptop-kmod && \
    dnf5 -y copr enable asmx2/keylightd && \
    dnf5 -y in keylightd && \
    systemctl enable keylightd && \
    dnf5 clean all

## Nvidia 
RUN dnf5 -y in nvidia-driver \
              nvidia-driver-cuda \
              cuda && \
    dnf5 -y copr enable @ai-ml/nvidia-container-toolkit && \
    dnf5 -y in nvidia-container-toolkit nvidia-container-toolkit-selinux && \
    dnf5 clean all

RUN rm /usr/bin/akmodsbuild && \
    mv /usr/bin/akmodsbuild{.bak,} && \
    akmods --force --kernels $(rpm -qva | grep "kernel-devel" | head -n 1 | sed "s/kernel-devel-//")

## kargs
RUN mkdir -p /usr/lib/bootc/kargs.d/ && \
    echo 'kargs = ["quiet", "splash", "loglevel=3", "rd.udev.log_level=3"]' > /usr/lib/bootc/kargs.d/01-silent-boot.toml && \
    echo 'kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nouveau.modeset=0"]' > /usr/lib/bootc/kargs.d/99-blacklist-nouveau.toml

## Codecs
RUN dnf5 -y --repo=fedora-multimedia in mesa-dri-drivers mesa-va-drivers mesa-vulkan-drivers libva libheif && \
    dnf5 versionlock add mesa-dri-drivers mesa-va-drivers mesa-vulkan-drivers libva libheif

## Desktop stuf
RUN dnf5 -y in virt-manager \
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
    dnf5 -y rm firefox \
    yelp \
    gnome-system-monitor \
    gnome-shell-extension-common \
    gnome-shell-extension-apps-menu \
    gnome-shell-extension-launch-new-instance \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-window-list \
    gnome-shell-extension-background-logo \
    malcontent-control && \
    dnf5 clean all

## Controller support
RUN dnf5 -y in steam-devices 

## Set up Just
RUN dnf5 -y in just

## Set up Nix
RUN dnf5 install -y nix nix-daemon && \ 
    dnf5 clean all

RUN mkdir -p /nix

COPY --chmod=644 files/ /

RUN systemctl enable nix.mount nix-store-init.service nix-daemon

## Set adw-gtk3
COPY files/etc/skel/.config/dconf/user /etc/skel/.config/dconf/user

## Systemd
RUN systemctl enable libvirtd.service lxc.service

## Signing
RUN mkdir -p /etc/pki/containers /etc/containers/registries.d

COPY cosign.pub /etc/pki/containers/hermes-bootc.pub

COPY policy.json /etc/containers/policy.json

COPY hermes-bootc.yaml /etc/containers/registries.d/hermes-bootc.yaml

RUN dnf5 clean all
