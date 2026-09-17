FROM docker/sandbox-templates:shell-0.5.0@sha256:16a88c7321c130de9aa8410ffd0865ea22dd051ebb7f58103fbf41ec50057476

LABEL org.opencontainers.image.title="Hermes Agent for Simple Hyprland" \
      org.opencontainers.image.source="https://github.com/xmbshwll/hermes-agent-docker" \
      org.opencontainers.image.version="v2026.9.14" \
      org.opencontainers.image.revision="c4bcbe2eb1cc92f36f74714f342fc1a5da4c3d9d" \
      io.simple-hyprland.hermes.revision="345cd2b057a452236de401d3534b8502a7465e8d"

COPY docker-entrypoint.sh /usr/local/bin/hermes-entrypoint

USER root

RUN rm -f /etc/sudoers.d/agent \
    && /usr/bin/gpasswd --delete agent sudo \
    && /usr/bin/gpasswd --delete agent docker \
    && mkdir -p /home/agent/.hermes/bin /home/agent/.local/bin \
    && /usr/bin/install -D -m 0755 -o agent -g agent \
        /usr/local/bin/uv /home/agent/.hermes/bin/uv \
    && chown -R agent:agent /home/agent/.hermes /home/agent/.local \
    && printf '%s  %s\n' \
        '9ecc9efaa151adc094989cb1004447aad1dc16dfd865fc37cb571a856f4c60a8' \
        /usr/local/bin/hermes-entrypoint \
        | sha256sum --check --strict -

USER agent
ENV HOME=/home/agent
ENV HERMES_HOME=/home/agent/.hermes
ENV PATH="/home/agent/.local/bin:${PATH}"
ENV PYTHONDONTWRITEBYTECODE=1
WORKDIR /home/agent

RUN curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
        --fail --show-error --silent --location --retry 3 --retry-all-errors \
        --output /tmp/hermes-install.sh \
        'https://raw.githubusercontent.com/NousResearch/hermes-agent/345cd2b057a452236de401d3534b8502a7465e8d/scripts/install.sh' \
    && printf '%s  %s\n' \
        '38547c22f4dd2224ba68a13bc3479309abb17e295b2a2ef79c2d1b8293bd822e' \
        /tmp/hermes-install.sh \
        | sha256sum --check --strict - \
    && bash /tmp/hermes-install.sh \
        --stage repository \
        --branch v2026.9.14 \
        --commit 345cd2b057a452236de401d3534b8502a7465e8d \
        --force-commit \
        --dir /home/agent/hermes-agent \
    && bash /tmp/hermes-install.sh \
        --stage venv \
        --dir /home/agent/hermes-agent \
    && mkdir -p /tmp/hermes-uv-config \
    && cd /home/agent/hermes-agent \
    && XDG_CONFIG_HOME=/tmp/hermes-uv-config \
        XDG_CONFIG_DIRS=/tmp/hermes-uv-config \
        UV_PROJECT_ENVIRONMENT=/home/agent/hermes-agent/venv \
        /home/agent/.hermes/bin/uv sync --extra all --locked \
            --no-install-project --no-build \
    && bash /tmp/hermes-install.sh \
        --stage path \
        --dir /home/agent/hermes-agent \
    && bash /tmp/hermes-install.sh \
        --stage config \
        --dir /home/agent/hermes-agent \
    && bash /tmp/hermes-install.sh \
        --stage complete \
        --branch v2026.9.14 \
        --commit 345cd2b057a452236de401d3534b8502a7465e8d \
        --dir /home/agent/hermes-agent \
    && test "$(git -C /home/agent/hermes-agent rev-parse HEAD)" = "345cd2b057a452236de401d3534b8502a7465e8d" \
    && rm -rf /tmp/hermes-install.sh /tmp/hermes-uv-config

RUN --network=none hermes skills list >/dev/null

USER root
RUN mkdir -p /usr/local/share/hermes-home \
    && cp -a /home/agent/.hermes/. /usr/local/share/hermes-home/ \
    && chmod 0755 /usr/local/bin/hermes-entrypoint \
    && chown -R agent:agent /usr/local/share/hermes-home

USER agent
WORKDIR /home/agent/workspace
VOLUME ["/home/agent/.hermes"]
ENTRYPOINT ["/usr/local/bin/hermes-entrypoint"]
CMD ["hermes"]
