FROM tailscale/tailscale@sha256:5bbcf89bb34fd477cae8ff516bddb679023f7322f1e959c0714d07c622444bb4

# Install scripts with deterministic permissions via bind mount
RUN --mount=type=bind,source=scripts,target=/tmp/scripts,ro \
    /bin/sh -o pipefail -c 'set -euo pipefail; \
        rm -rf /scripts && mkdir -p /scripts && chmod 755 /scripts && \
        cd /tmp/scripts && \
        find . -type d -print0 | while IFS= read -r -d "" dir; do \
            rel="${dir#./}"; \
            [[ -z "$rel" ]] && continue; \
            install -d -m 755 "/scripts/$rel"; \
        done && \
        find . -type f -print0 | while IFS= read -r -d "" file; do \
            rel="${file#./}"; \
            perm=644; \
            case "$rel" in \
                *.sh) perm=755 ;; \
                *.py) case "$rel" in */*) perm=644 ;; *) perm=755 ;; esac ;; \
            esac; \
            install -m "$perm" "$file" "/scripts/$rel"; \
        done'

COPY --chmod=664 .GIT_REV /etc/

ENTRYPOINT ["/scripts/entrypoint.sh"]

