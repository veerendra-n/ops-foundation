# Semaphore runner with the exact Ansible and collections CI tests against, so a runbook behaves the
# same in CI and on every edge node. Built and published by .github/workflows/runner-image.yml (next slice).
ARG SEMAPHORE_VERSION=v2.18.31
FROM semaphoreui/runner:${SEMAPHORE_VERSION}
USER root
COPY requirements.txt /tmp/requirements.txt
COPY ansible/requirements.yml /tmp/collections.yml
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt pywinrm[kerberos] pyvmomi hvac pynetbox \
 && ansible-galaxy collection install -r /tmp/collections.yml -p /usr/share/ansible/collections \
 && rm /tmp/requirements.txt /tmp/collections.yml
USER semaphore
