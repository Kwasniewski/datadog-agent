#!/usr/bin/env bash


cd $(dirname $0)

set -ex

ssh-keygen -b 4096 -t rsa -C "datadog" -N "" -f "id_rsa"
SSH_RSA=$(cat id_rsa.pub)

tee ignition.json << EOF
{
  "passwd": {
    "users": [
      {
        "sshAuthorizedKeys": [
          "${SSH_RSA}"
        ],
        "name": "core"
      }
    ]
  },
  "systemd": {
    "units": [
      {
        "mask": true,
        "name": "user-configdrive.service"
      },
      {
        "mask": true,
        "name": "user-configvirtfs.service"
      },
      {
        "enabled": true,
        "name": "oem-cloudinit.service",
        "contents": "[Unit]\nDescription=Cloudinit from platform metadata\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/coreos-cloudinit --oem=ec2-compat\n\n[Install]\nWantedBy=multi-user.target\n"
      },
      {
        "enabled": true,
        "name": "setup-pupernetes.service",
        "contents": "[Unit]\nDescription=Setup pupernetes\n\n[Service]\nType=oneshot\nExecStart=/opt/bin/setup-pupernetes\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n"
      },
      {
        "enabled": true,
        "name": "pupernetes.service",
        "contents": "[Unit]\nDescription=Run pupernetes\nRequires=setup-pupernetes.service docker.service\nAfter=setup-pupernetes.service docker.service\n\n[Service]\nEnvironment=SUDO_USER=core\nExecStart=/opt/bin/pupernetes run /opt/sandbox --kubectl-link /opt/bin/kubectl -v 5 --timeout 6h\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n"
      },
      {
        "name": "terminate.service",
        "contents": "[Unit]\nDescription=Trigger a poweroff\n\n[Service]\nExecStart=/bin/systemctl poweroff\nRestart=no\n"
      },
      {
        "enabled": true,
        "name": "terminate.timer",
        "contents": "[Timer]\nOnBootSec=7200\n\n[Install]\nWantedBy=multi-user.target\n"
      }
    ]
  },
  "storage": {
    "files": [
      {
        "path": "/opt/bin/setup-pupernetes",
        "mode": 320,
        "contents": {
          "source": "data:,%23%21%2Fbin%2Fbash%20-ex%0Acurl%20-Lf%20https%3A%2F%2Fgithub.com%2FDataDog%2Fpupernetes%2Freleases%2Fdownload%2Fv0.1%2Fpupernetes%20-o%20%2Fopt%2Fbin%2Fpupernetes%0Asha512sum%20-c%20%2Fopt%2Fbin%2Fpupernetes.sha512sum%0Achmod%20%2Bx%20%2Fopt%2Fbin%2Fpupernetes%0A"
        },
        "filesystem": "root"
      },
      {
        "path": "/opt/bin/pupernetes.sha512sum",
        "mode": 256,
        "contents": {
          "source": "data:,1b56ea0b63bb977a28df04f3ff7e93263a7bc761f83796a07821dfedfac0de8f711c011ce1290370586149ec9237e325f95f9aab1fe983a8488c937920ea1ef7%20%2Fopt%2Fbin%2Fpupernetes%0A"
        },
        "filesystem": "root"
      },
      {
        "path": "/home/core/.kube/config",
        "filesystem": "root",
        "user": {
          "name": "core"
        },
        "mode": 420
      }
    ]
  },
  "ignition": {
    "version": "2.1.0"
  }
}
EOF