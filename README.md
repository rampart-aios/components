# Helm repository for builtin rampart components 

## How to add/remove helm chart from an OCI registry

### 1. Checkout repop and create a feature branch
```
git clone git@github.com:rampart-aios/components.git
git checkout -b my_feature
```
### 2. Login GitHub OCI registry
```
helm registry login ghcr.io
```
### 3a. Pull the helm charts from OCI registry
- Get Helm URL from GitHub Packages: For example: "docker pull ghcr.io/rampart-aios/rampart-batch-uploader/batch-uploader:0.2.1-1a567c1b"
- Pull Helm Chart with pull script
```
./scripts/pull.sh "docker pull ghcr.io/rampart-aios/rampart-batch-uploader/batch-uploader:0.2.1-1a567c1b"
```
### 3b. Delete unused snapshot from OCI registry
```
rm batch-executor-0.7.0-3f6e9d22.tgz
```

### 4. Update index
```
helm repo index .
```

### 4. Commit your change
```
git add .
git commit -m "Added new chart!"
git push --set-upstream origin my_feature
```

### 5. Submit your MR for review
