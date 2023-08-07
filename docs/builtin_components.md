## Rampart Built-in Components
This section provides reference to Rampart built-in components such as Batch Uploader, Batch Executor, Generic Service, JupyterLab, Tensorboard, Ray Cluster, and Ray Job.
### Batch Uploader
Batch Uploader is a Rampart Component that provides a RESTful endpoint for generic batch file uploading.
#### Component specification
```yaml
inputs: []
outputs:
  - name: "*"
    type: volume
```
Batch Uploader takes no input but can be configured to have arbitrary many outputs, and each output can only be connected to a volume flow.

#### Usages

All its APIs are designed to support a specific use case: uploading a named batch of files and saving them to a specified edge (the output name). Deleting an existing batch is also supported but it is not considered a typical use case and it is assumed to be only useful for clearing up disk space. Thus, most of them expect the following two arguments:
- **batch_name**: name of the batch
- **edge_name**: edge/output you want to save the batch to

##### Multipart form upload

**/multipart/upload-batch-atomic/**

Create, upload, and mark the batch ready in one request. Concurrent calls to upload the same batch to the same edge are not supported and should be avoided. If one must do that, they need to understand that a request who finishes transmitting data first will always be handled first causing the other requests (even initiated earlier) to fail. It takes one additional argument besides batch_name and edge_name:
- **files[]**: binary content of the file and its metadata
Example request:
```bash
curl -X 'POST' \
  'http://example.com/<gateway_route>/multipart/upload-batch-atomic/' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'files[]=@/path/to/somefile.yaml;type=application/x-yaml;filename=renamefile.yaml' \
  -F 'batch-name=batch-1' \
  -F 'edge-name=edge-1'
```
##### Delete a batch
**/delete-batch**

Example request:
```bash
curl -X 'POST' \
  '' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'batch-name=batch-1&edge-name=edge-1'
```
#### Configuration
- **ingress**: Use pathPrefix to configure the path prefix to batch-uploader's endpoint URL. The default value is suggested by rampart controller and is currently `<graph_namespace>/<graph_name>/<component_name>/`

- **imagePullSecrets**: A list of secrets used for pulling the job image, in the format `{"name": <secret_name>}`.
### Batch Executor

Batch Executor is a Rampart Component that provides a generic way to execute a customized job (that operates on a batch of data) and such execution is triggered by a simple filesystem-based notification mechanism.
#### Component specification
```yaml
inputs:
  - name: input_*
    type: volume
    mountPath: /input_*
outputs:
  - name: output_*
    type: volume
    mountPath: /output_*
```
Batch Executor takes an arbitrary number of volume-based inputs and outputs.
#### Usages
##### Configure the job specification
Batch Executor expects `jobConfig` to be filled with necessary job specification for it to know how to execute the job.
- **imagePullSecrets**: a list of secrets used for pulling the job image, in the format `{"name": <secret_name>}`.
- **image**
  - **repository**: image repository
  - **tag**: image tag
  - **pullPolicy**: image pull policy, either Always or IfNotPreset
  - **inputMap**: this is an optional configuration to mount the input batch folder to a different path than "mountPath" set on each input of batch-executor.
  - **outputMap**: same as inputMap but for outputs
  - **command**: command used to execute the image
  - **args**: arguments appended to the above command
  - **env**: environment variables and their values
  - **resources**:
    - **requests**: this setting describes the minimum amount of computing resources required. If Requests is omitted for a container, it defaults to Limits if that is explicitly specified, otherwise to an implementation-defined value. More info can be found [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
    - **limits**: this setting describes the maximum amount of computing resources allowed. More info can be found [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).

Example jobConfig:
```yaml
jobConfig:
  image:
    repository: debian
    tag: latest
    pullPolicy: IfNotPresent
  inputMap:
    input_1: /inputs/input_1 # otherwise, input_1 is mounted to /input_1 by default
    input_2: /inputs/input_2
  outputMap:
    output_1: /outputs
  command: ["/bin/sh", "-c", "find /inputs -type f -exec cp \\{\\} --backup=numbered -t /outputs \\;"]
```
##### How to trigger execution
**Multiple inputs**

Number of inputs that Batch Executor takes is equivalent to the number of (top level) data folders that the job needs. For example, if jobConfig is configured to use a docker image that expects two data folders: one for training and the other for validation, then Batch Executor needs to take two inputs as well, and they are called input_1 and input_2 respectively.

**Batch folders**

One folder on Batch Executor’s inputs represents one batch of data and the folder name is the name of the batch. Batch Executor relies on its upstream components to create the folders and populate them with data.

**Readiness files**

To notify Batch Executor that one batch folder is ready, an upstream component would need to create a "readiness" file in the directory containing the batch folders. The name of this file must be in the format of `__<batch_name>__`, while the content of the file does not matter.

**Triggering condition**

A job on batch_1 is triggered if and only if all the following conditions are met:
- All inputs of Batch Executor contain a folder named `batch_1`
- All inputs of Batch Executor contain a readiness file named `__batch_1__`
- All readiness files are created or modified after the last execution (if exists) of `batch_1`
- The batch name "batch_1" was not previously used.

**Multiple outputs**

Like inputs, the number of output that Batch Executor takes is equivalent to the number of output folders the job needs. Batch Executor creates the batch folders on its outputs before job execution and creates readiness files for them after job executes successfully.

### Generic Service
Generic Service component allows user to easily convert an existing model serving image into a Rampart Component.

#### Usages
##### Configuration options
- **image**
  - **repository**: tag is the image URL
  - **ports**: a list of ports you want to expose from this image. Each port is configured as following:
    - **name**: name of this port
    - **port**: port number, must be an integer
    - **ingressPath**: optional path of the endpoint seen from outside of the cluster
    - **ingressHost**: optional host name of the endpoint
  - **command**: a list of strings composing the command used to run the image
  - **args**: a list of strings composing the arguments to be appended to the command
  - **env**: environment variables to be passed into the container, in the format `{"name": <env_name>, "value":  <env_value>}`
- **imagePullSecrets**: A list of secrets used for pulling the job image, in the format `{"name": <secret_name>}`.
- **ingress**
  - **pathPrefix**: use it to prepend a prefix to all the `ingressPath`s defined above. This prevents conflicted paths across different rampart graphs. For example, setting it to server will convert the paths to /server and /server/translate. The default pathPrefix is suggested by Rampart controller and is currently `<graph_namespace>/<graph_name>/<component_name>/`

### JupyterLab
The JupyterLab component hosts a JupyterLab instance on the cluster.

#### Usages
##### Configuration options
- **image**
  - **repository**: the repository for the JupyterLab image. The image needs to be able to launch a JupyterLab instance. It is advised to use `jupyter/datascience-notebook` as the base image in order to have all the dependencies.
  - **tag**: the image version
- **resources**: Specify what computational resources are assigned to the JupyterLab instance.
  - **requests**: The minimum resources the JupyterLab instance will be assigned.
    - **memory**: RAM in bytes. Use the suffixes `Gi` and `Mi` for gigabytes and megabytes
    - **cpu**: CPU cores. Fractional cores are allowed. Use the suffix `m` to request a milli-cpu, or use the decimal point (e.g. 1.234)
  - **limits**: The maximum resources the JupyterLab instance will be assigned.
    - **memory**: RAM in bytes. Use the suffixes `Gi` and `Mi` for gigabytes and megabytes
    - **cpu**: CPU cores. Fractional cores are allowed. Use the suffix `m` to request a milli-cpu, or use the decimal point (e.g. 1.234)
    - **nvidia.com/gpu**: Use if and only if the cluster has nvidia GPU resources enabled. This value must be a whole number. Note that this GPU allocation is a hard requirement rather than a limit: if this number cannot be allocated, the instance will not start.

A running JupyterLab instance will be available at `<IP>:30800/<graph_namespace>/<graph_name>/<component_name>/`. You can then create and run notebooks inside the instance. To have your notebooks persist across graph updates and undeploy/redeploy cycles, place the notebooks inside the `persistent-notebooks` directory.

You can install python dependencies using `conda` or `python3 -m pip install` from the Jupyter terminal, or from within the notebooks using `!` to run the commands from a shell:

```
!python3 -m pip install torch
import torch
```

`conda` and `pip` dependencies will persist through undeploy/deploy cycles.

If GPUs are assigned to the instance, they can be viewed using `nvidia-smi` from the Jupyter terminal. Torch and Tensorflow will be able to access them.

### TensorBoard
TensorBoard component hosts a TensorBoard server that displays TensorBoard logs on its input edge.

This is a component that can be included in a Rampart Graph. Once properly configured, the TensorBoard can be accessed via: `<IP>:30800/<path-prefix>/tensorboard/` or `<DNS>/<path-prefix>/tensorboard/`
#### Usages
##### Configuration options
- **image**
  - **repository**: tensorflow/tensorflow
  - **tag**: the image version
- **ingress**:
  - **urlPrefix**: use it to prepend a prefix to all the path defined for TensorBoard. This prevents conflicted paths across different rampart graphs. For example, setting it to graph1 will convert the paths to `/graph1/tensorboard/`. The recommended value for urlPrefix is `<rampart_graph_name>`. This value can be overwritten by urlPrefix specified by user/admin in the graph definition (yaml file) they supply.

  Sample configuration in Rampart graph:
  ```yaml
  config:
    ingress:
      urlPrefix: customized-prefix # (optional: by setting this value, user can have a customized url path-prefix)
  ```
- **Tensorboard logdir**: if the input to the tensorboard component is not named `tensorboard_data`, then you must set the mount path of the tensorboard input to `/tensorboard_data`. Note that this will be the case if the Tensorboard component is created via the UI.

### Ray Cluster
The Ray Cluster component lets you create a RayCluster on Rampart and use it remotely.

#### Usages
Once deployed successfully in a Rampart graph, the ray dashboard becomes accessible externally at
```
http://<node-ip>:30800/<graph-namespace>/<graph-name>/<component-name>/dashboard/
```
Other services can be accessed within the kubernetes cluster at
```
component-<component-name>.<graph-name>-<component-name>.svc.cluster.local:<port>
```
For example, one can establish a connection with the ray cluster by
```python
ray.init(address="ray://component-ray-cluster.<graph-namespace>-<graph-name>-<component-name>.svc.cluster.local:10001")
```
where `10001` is the default port for the client endpoint.
##### Configuration options
All configurations listed below are optional.
- **image**: docker image used to host the Ray cluster. Sepecify a different image if you wish to change the runtime environment, i.e., Ray version, Python version, etc.
  - **repository**: image repository
  - **tag**: image tag
  - **pullPolicy**: image pull policy, either Always or IfNotPresent
- **head**: head node configurations for the Ray cluster
  - **enableInTreeAutoscaling**: whether to enable auto scaling. Default is false.
  - **resources**:
    - **requests**: this setting describes the minimum amount of computing resources required. If Requests is omitted for a container, it defaults to Limits if that is explicitly specified, otherwise to an implementation-defined value. More info can be found [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
    - **limits**: this setting describes the maximum amount of computing resources allowed. More info can be found [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
  - **ports**: specify ports to be exposed from this image. Change it only if you don't want to use default port values.
  - **initArgs**: a list of arguments to be passed to `ray start` command. It is important to set `num-cpus` and `num-gpus` to match with the resources requested for this node.
- **worker**: worker node configurations for the default worker group
  - **disabled**: set to `true` to disable the default worker group
  - **resources**:
    - **requests**: this setting describes the minimum amount of computing resources required. If Requests is omitted for a container, it defaults to Limits if that is explicitly specified, otherwise to an implementation-defined value. More info can be found [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
    - **limits**: this setting describes the maximum amount of computing resources allowed. More info can be found [here](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
  - **ports**: specify ports to be exposed from this image. Change it only if you don't want to use default port values.
  - **initArgs**: a list of arguments to be passed to `ray start` command. It is important to set `num-cpus` and `num-gpus` to match with the resources requested for this node.
  - **replicas**: number of workers to be created in this worker group
  - **miniReplicas**: minimum number of workers. Ignored if `enableInTreeAutoscaling` is false
  - **maxiReplicas**: maximum number of workers. Ignored if `enableInTreeAutoscaling` is false

### Ray Job
The Ray Job component lets you submit a RayJob either to an existing RayCluster or a new RayCluster created by this component.

:::{note}
Submiting to an existing RayCluster is an experimental feature.
:::

#### Usages
By default, this component will create a new RayCluster and all the cluster related usages are identical to the Ray Cluster component. It shares the same head/worker/image configuration options as the Ray Cluster component. Only RayJob specific configuration options are listed below.
##### Configuration options
- **entrypoint**: complete command to start the job. E.g., `python main.py`
- **runtimeEnv**: base64 string of the runtime json string.
- **jobId**: job ID to specify for the job. If not provided, one will be generated.
- **metadata**: arbitrary user-provided metadata for the job.
- **shutdownAfterJobFinishes**: whether to recycle the cluster after job finishes.
- **ttlSecondsAfterFinished**: TTL to clean up the cluster. This only works if `shutdownAfterJobFinishes` is true.
- **clusterSelector**: (experimental) if provided, selects a running cluster instead of starting a new one.
