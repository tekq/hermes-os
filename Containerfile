FROM quay.io/fedora/fedora-silverblue:44

## RPMFusion
RUN dnf -y install \
     https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
     https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
     dnf clean all

## Fake it till you make it
RUN dnf -y in akmods rpmfusion-nonfree-release-tainted && \
    mv /usr/bin/akmodsbuild{,.bak} && \
    ln -s /usr/bin/true /usr/bin/akmodsbuild

## Framework (gangster) shit
RUN dnf -y copr enable ublue-os/akmods && \
    dnf -y in framework-laptop-kmod && \
    dnf clean all

## Nvidia 
RUN dnf -y in akmod-nvidia-open \
              xorg-x11-drv-nvidia-cuda && \
    dnf -y copr enable @ai-ml/nvidia-container-toolkit && \
    dnf -y in nvidia-container-toolkit nvidia-container-toolkit-selinux && \
    dnf clean all

RUN rm /usr/bin/akmodsbuild && \
    mv /usr/bin/akmodsbuild{.bak,} && \
    akmods --force --kernels $(rpm -qva | grep "kernel-devel" | head -n 1 | sed "s/kernel-devel-//")

## kargs
RUN mkdir -p /usr/lib/bootc/kargs.d/ && \
    echo 'kargs = ["quiet", "splash", "loglevel=3", "rd.udev.log_level=3"]' > /usr/lib/bootc/kargs.d/01-silent-boot.toml && \
    echo 'kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nouveau.modeset=0"]' > /usr/lib/bootc/kargs.d/99-blacklist-nouveau.toml

## Desktop stuf
RUN dnf -y in virt-manager \
    lxc \
    libvirt-daemon-kvm \
    libvirt-daemon-lxc \
    distrobox \
    podman \
    plymouth \
    gnome-disk-utility \
    gnome-software \
    adw-gtk3-theme && \
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

## Set adw-gtk3
COPY skel/.config/dconf/user /etc/skel/.config/dconf/user

## Systemd
RUN systemctl enable libvirtd.service && \
    systemctl enable bootc-fetch-apply-updates.service

## Signing
RUN mkdir -p /etc/pki/containers /etc/containers/registries.d

COPY cosign.pub /etc/pki/containers/hermes-bootc.pub

COPY policy.json /etc/containers/policy.json

COPY hermes-bootc.yaml /etc/containers/registries.d/hermes-bootc.yaml

RUN dnf clean all

