FROM ubuntu:mantic

COPY init.sh /init.sh
RUN /init.sh
COPY grub-uefi.sh /opt/ksl/grub-uefi.sh

WORKDIR /opt/ksl

ENTRYPOINT [ "/bin/bash" ]