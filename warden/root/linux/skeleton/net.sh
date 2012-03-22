#!/bin/bash -x

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./config

filter_dispatch_chain="warden-dispatch"
filter_default_chain="warden-default"
filter_instance_prefix="warden-instance-"
filter_instance_chain="${filter_instance_prefix}${id}"
nat_prerouting_chain="warden-prerouting"
nat_instance_prefix="warden-instance-"
nat_instance_chain="${filter_instance_prefix}${id}"

function teardown_filter() {
  # Prune dispatch chain
  iptables -S ${filter_dispatch_chain} 2> /dev/null |
    grep "\-g ${filter_instance_chain}\b" |
    sed -e "s/-A/-D/" |
    xargs --no-run-if-empty --max-lines=1 iptables

  # Flush and delete instance chain
  iptables -F ${filter_instance_chain} 2> /dev/null || true
  iptables -X ${filter_instance_chain} 2> /dev/null || true
}

function setup_filter() {
  teardown_filter

  # Create instance chain
  iptables -N ${filter_instance_chain}
  iptables -A ${filter_instance_chain} \
    --goto ${filter_default_chain}

  # Bind instance chain to dispatch chain
  iptables -I ${filter_dispatch_chain} 2 \
    --in-interface ${network_iface_host} \
    --goto ${filter_instance_chain}
}

function teardown_nat() {
  # Prune prerouting chain
  iptables -t nat -S ${nat_prerouting_chain} 2> /dev/null |
    grep "\-j ${nat_instance_chain}\b" |
    sed -e "s/-A/-D/" |
    xargs --no-run-if-empty --max-lines=1 iptables -t nat

  # Flush and delete instance chain
  iptables -t nat -F ${nat_instance_chain} 2> /dev/null || true
  iptables -t nat -X ${nat_instance_chain} 2> /dev/null || true
}

function setup_nat() {
  teardown_nat

  # Create instance chain
  iptables -t nat -N ${nat_instance_chain}

  # Bind instance chain to prerouting chain
  iptables -t nat -A ${nat_prerouting_chain} \
    --jump ${nat_instance_chain}
}

case "${1}" in
  "setup")
    setup_filter
    setup_nat

    ;;

  "teardown")
    teardown_filter
    teardown_nat

    ;;

  "in")
    if [ -z "${PORT:-}" ]; then
      echo "Please specify PORT..." 1>&2
      exit 1
    fi

    iptables -t nat -A ${nat_instance_chain} \
      --protocol tcp \
      --destination-port "${PORT}" \
      --jump DNAT \
      --to-destination "${network_container_ip}"

    ;;

  "out")
    if [ -z "${NETWORK:-}" ] && [ -z "${PORT:-}" ]; then
      echo "Please specify NETWORK and/or PORT..." 1>&2
      exit 1
    fi

    opts=""

    if [ -n "${NETWORK:-}" ]; then
      opts="${opts} --destination ${NETWORK}"
    fi

    # Restrict protocol to tcp when port is specified
    if [ -n "${PORT:-}" ]; then
      opts="${opts} --protocol tcp"
      opts="${opts} --destination-port ${PORT}"
    fi

    iptables -I ${filter_instance_chain} 1 ${opts} --jump RETURN

    ;;

  *)
    echo "Unknown command: ${1}" 1>&2
    exit 1

    ;;
esac
