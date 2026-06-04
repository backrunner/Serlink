FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash serlink \
    && echo 'serlink:serlink' | chpasswd \
    && mkdir -p /run/sshd /home/serlink/workspace \
    && chown -R serlink:serlink /home/serlink

RUN printf '%s\n' \
    'PasswordAuthentication yes' \
    'PermitRootLogin no' \
    > /etc/ssh/sshd_config.d/serlink-sftp.conf

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
