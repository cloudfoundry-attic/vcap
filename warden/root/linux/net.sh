#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob

filter_dispatch_chain="warden-dispatch"
filter_default_chain="warden-default"
filter_instance_prefix="warden-instance-"
nat_prerouting_chain="warden-prerouting"
nat_instance_prefix="warden-instance-"

function teardown_filter() {
  # Prune dispatch chain
  iptables -S ${filter_dispatch_chain} 2> /dev/null |
    grep "\-g ${filter_instance_prefix}" |
    sed -e "s/-A/-D/" -e "s/\s\+\$//" |
    xargs --no-run-if-empty --max-lines=1 iptables

  # Prune per-instance chains
  iptables -S 2> /dev/null |
    grep "^-A ${filter_instance_prefix}" |
    sed -e "s/-A/-D/" -e "s/\s\+\$//" |
    xargs --no-run-if-empty --max-lines=1 iptables

  # Delete per-instance chains
  iptables -S 2> /dev/null |
    grep "^-N ${filter_instance_prefix}" |
    sed -e "s/-N/-X/" -e "s/\s\+\$//" |
    xargs --no-run-if-empty --max-lines=1 iptables

  # Flush dispatch chain
  iptables -F ${filter_dispatch_chain} 2> /dev/null || true

  # Flush default chain
  iptables -F ${filter_default_chain} 2> /dev/null || true
}

function setup_filter() {
  teardown_filter

  # Create or flush dispatch chain
  iptables -N ${filter_dispatch_chain} 2> /dev/null || iptables -F ${filter_dispatch_chain}
  iptables -A ${filter_dispatch_chain} -j DROP

  # If the packet is NOT a canonical SYN packet, allow immediately
  iptables -I ${filter_dispatch_chain} 1 -p tcp ! --syn --jump ACCEPT

  # Create or flush default chain
  iptables -N ${filter_default_chain} 2> /dev/null || iptables -F ${filter_default_chain}

  # Whitelist
  for n in "${ALLOW_NETWORKS}"; do
    if [${n} -eq '']; then break; fi
    iptables -A ${filter_default_chain} --destination "${n}" --jump RETURN
  done

  for n in "${DENY_NETWORKS}"; do
    if [${n} -eq '']; then break; fi
    iptables -A ${filter_default_chain} --destination "${n}" --jump DROP
  done

  # Bind chain
  (iptables -S INPUT | grep -q "\-j ${filter_dispatch_chain}\b") ||
    iptables -A INPUT -i veth-+ --jump ${filter_dispatch_chain}
  (iptables -S FORWARD | grep -q "\-j ${filter_dispatch_chain}\b") ||
    iptables -A FORWARD -i veth-+ --jump ${filter_dispatch_chain}
}

function teardown_nat() {
  # Prune prerouting chain
  iptables -t nat -S ${nat_prerouting_chain} 2> /dev/null |
    grep "\-j ${nat_instance_prefix}" |
    sed -e "s/-A/-D/" -e "s/\s\+\$//" |
    xargs --no-run-if-empty --max-lines=1 iptables -t nat

  # Prune per-instance chains
  iptables -t nat -S 2> /dev/null |
    grep "^-A ${nat_instance_prefix}" |
    sed -e "s/-A/-D/" -e "s/\s\+\$//" |
    xargs --no-run-if-empty --max-lines=1 iptables -t nat

  # Delete per-instance chains
  iptables -t nat -S 2> /dev/null |
    grep "^-N ${nat_instance_prefix}" |
    sed -e "s/-N/-X/" -e "s/\s\+\$//" |
    xargs --no-run-if-empty --max-lines=1 iptables -t nat

  # Flush prerouting chain
  iptables -t nat -F ${nat_prerouting_chain} 2> /dev/null || true
}

function setup_nat() {
  teardown_nat

  #create chain
  iptables -t nat -N ${nat_prerouting_chain} 2> /dev/null || true

  external_interface=$(ip route get 1.1.1.1 | head -n1 | cut -d" " -f5)

  # Bind chain
  (iptables -t nat -S PREROUTING | grep -q "\-j ${nat_prerouting_chain}\b") ||
    iptables -t nat -A PREROUTING \
      --in-interface "${external_interface}" \
      --jump ${nat_prerouting_chain}

  # Enable NAT on outgoing traffic
  (iptables -t nat -S POSTROUTING | grep -q "\-j MASQUERADE\b") ||
    iptables -t nat -A POSTROUTING \
      --out-interface "${external_interface}" \
      --jump MASQUERADE
}

case "${1}" in
  setup)
    setup_filter
    setup_nat

    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ;;
  teardown)
    teardown_filter
    teardown_nat
    ;;
  *)
    echo "Unknown command: ${1}" 1>&2
    exit 1
    ;;
esac
