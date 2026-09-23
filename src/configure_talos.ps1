param(
    [Parameter(Mandatory=$true)][string]$CONTROL_PLANE_IP,
    [Parameter(Mandatory=$false)][string]$CLUSTER_NAME,
    [Parameter(Mandatory=$false)][string]$DISK_NAME,
    [Parameter(Mandatory=$false)][string[]]$WORKER_IP
)

if (-not (Get-Command talosctl -ErrorAction SilentlyContinue)) {
    Write-Error "talosctl is not installed or not available in the PATH."
    exit 1
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed or not available in the PATH."
    exit 1
}

# Prompt for for $ClUSTER_NAME and $DISK_NAME if they are not provided
if (-not $CLUSTER_NAME) {
    $CLUSTER_NAME = Read-Host "Enter the cluster name"
}

if (-not $DISK_NAME) {
    $DISK_NAME = Read-Host "Enter the disk name (e.g., sda)"
}

if (-not $WORKER_IP) {
    $worker_ips = Read-Host "Enter the worker IPs (comma-separated). Press enter to skip"
    $WORKER_IP = $worker_ips -split ","
}

# Print out provided input and ask for confirmation to configure cluster
Write-Host "Cluster Name: $CLUSTER_NAME"
Write-Host "Control Plane IP: $CONTROL_PLANE_IP"
Write-Host "Disk Name: $DISK_NAME"
Write-Host "Worker IPs: $($WORKER_IP -join ', ')"

$confirmation = Read-Host "Proceed with the above configuration? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Configuration aborted."
    exit 1
}

Write-Host "Configuring Talos for cluster $CLUSTER_NAME on control plane $CONTROL_PLANE_IP with disk $DISK_NAME..."
talosctl gen config $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443 --install-disk /dev/$DISK_NAME

Write-Host "Applying configuration to control plane node $CONTROL_PLANE_IP..."
talosctl apply-config --insecure --nodes $CONTROL_PLANE_IP --file controlplane.yaml

if (-not $WORKER_IP) {
    Write-Host "No worker IPs provided. Skipping worker node configuration."
} else {
    foreach ($ip in $WORKER_IP) {
        Write-Host "Applying config to worker node: $ip"
        talosctl apply-config --insecure --nodes "$ip" --file worker.yaml
    }
}

talosctl --talosconfig=./talosconfig config endpoints $CONTROL_PLANE_IP

talosctl bootstrap --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig

talosctl kubeconfig --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig

talosctl --nodes $CONTROL_PLANE_IP --talosconfig=./talosconfig health

kubectl get nodes