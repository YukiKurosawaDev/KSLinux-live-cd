FROM ubuntu:noble

COPY init.sh /init.sh
RUN /init.sh
COPY grub-uefi.sh /opt/ksl/grub-uefi.sh

WORKDIR /opt/ksl

ENTRYPOINT [ "/opt/ksl/grub-uefi.sh" ]