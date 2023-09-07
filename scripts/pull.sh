raw=$1
raw2="${raw/:/ --version }"
raw3="${raw2/docker pull ghcr.io/helm pull oci://ghcr.io}"
echo $raw3
$($raw3)
