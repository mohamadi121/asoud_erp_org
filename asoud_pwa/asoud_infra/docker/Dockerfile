ARG ERPNEXT_VERSION=v15.117.0
FROM frappe/erpnext:${ERPNEXT_VERSION}

USER root

COPY --from=asoud_core --chown=frappe:frappe . /opt/asoud/apps/asoud_core
COPY --from=asoud_iran --chown=frappe:frappe . /opt/asoud/apps/asoud_iran
COPY --from=asoud_hr --chown=frappe:frappe . /opt/asoud/apps/asoud_hr

RUN /home/frappe/frappe-bench/env/bin/pip install --no-cache-dir \
        -e /opt/asoud/apps/asoud_core \
        -e /opt/asoud/apps/asoud_iran \
        -e /opt/asoud/apps/asoud_hr \
    && ln -s /opt/asoud/apps/asoud_core /home/frappe/frappe-bench/apps/asoud_core \
    && ln -s /opt/asoud/apps/asoud_iran /home/frappe/frappe-bench/apps/asoud_iran \
    && ln -s /opt/asoud/apps/asoud_hr /home/frappe/frappe-bench/apps/asoud_hr \
    && printf "\nasoud_core\nasoud_iran\nasoud_hr\n" >> /home/frappe/frappe-bench/sites/apps.txt

USER frappe
