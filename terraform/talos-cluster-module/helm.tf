resource "helm_release" "cilium_cni" {
  depends_on = [data.talos_cluster_kubeconfig.kubeconfig]
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = var.cilium_version

  values = [
    yamlencode(<<EOT
    ipam:
      mode: kubernetes

    kubeProxyReplacement: true

    securityContext:
      capabilities:
        ciliumAgent:
        - CHOWN
        - KILL
        - NET_ADMIN
        - NET_RAW
        - IPC_LOCK
        - SYS_ADMIN
        - SYS_RESOURCE
        - DAC_OVERRIDE
        - FOWNER
        - SETGID
        - SETUID
        cleanCiliumState:
        - NET_ADMIN
        - SYS_ADMIN
        - SYS_RESOURCE

    cgroup:
      autoMount:
        enabled: false
      hostRoot: /sys/fs/cgroup

    k8sServiceHost: localhost
    k8sServicePort: 7445

    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
    EOT
    )
  ]
}

resource "helm_release" "metrics-server" {
  depends_on = [data.talos_cluster_kubeconfig.kubeconfig, helm_release.cilium_cni]
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_version

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}