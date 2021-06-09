# fork to test bazel remote execution for iOS app

[Original README](README-original.md)

## How to prepare RBE with Bazel remote worker

```bash
git clone https://github.com/bazelbuild/bazel.git
cd bazel
bazel build src/tools/remote:all
bazel-bin/src/tools/remote/worker \
  --work_path=/tmp/test/wp \
  --cas_path=/tmp/test/cas \
  --listen_port=8080
```

## How to prepare RBE with Flare

1. Start Tilt in flare repo

2. Prepare worker directory
   ```bash
   mkdir -p /tmp/worker/worker/{build,cache}
   ```

3. Build buildbarn runner and worker
    ```bash
    git clone https://github.com/buildbarn/bb-remote-execution.git
    cd bb-remote-execution
    bazel build cmd/bb_worker:bb_worker cmd/bb_runner:bb_runner
    ```
    Copy bb_worker and bb_runner binaries to /tmp/worker

4. Create configuration files

    ```
    /tmp/bb-worker$ cat common.libsonnet
    local lbGrpc = {
      address: "localhost:8002",
      addMetadata: [
        {
          header: "x-api-key",
          values: ["local_flare"],
        },
      ],
    };
    {
      browserUrl: "example.com",
      blobstore: {
        contentAddressableStorage: {
          grpc: lbGrpc,
        },
        actionCache: {
          grpc: lbGrpc,
        },
      },
      maximumMessageSizeBytes: 16 * 1024 * 1024,
    }
    ```
    
    ```
    /tmp/bb-worker$ cat runner.jsonnet
    {
      buildDirectoryPath: '/tmp/bb-worker/worker/build',
      grpcServers: [{
        listenPaths: ['/tmp/bb-worker/worker/runner'],
        authenticationPolicy: { allow: {} },
      }],
    }
    ```
    
    ```
    /tmp/bb-worker$ cat worker.jsonnet
    local common = import 'common.libsonnet';
    
    {
      blobstore: common.blobstore,
      maximumMessageSizeBytes: common.maximumMessageSizeBytes,
      scheduler: { address: 'localhost:8012' },
      maximumMemoryCachedDirectories: 1000,
      instanceName: '',
      buildDirectories: [{
        native: {
          buildDirectoryPath: '/tmp/bb-worker/worker/build',
          cacheDirectoryPath: '/tmp/bb-worker/worker/cache',
          maximumCacheFileCount: 10000,
          maximumCacheSizeBytes: 1024 * 1024 * 1024,
          cacheReplacementPolicy: 'LEAST_RECENTLY_USED',
        },
        runners: [{
          endpoint: { address: 'unix:///tmp/bb-worker/worker/runner' },
          concurrency: 16,
          platform: {
            properties: [
              { name: 'OSFamily', value: 'MacOS' },
            ],
          },
          defaultExecutionTimeout: '1800s',
          maximumExecutionTimeout: '3600s',
        }],
      }],
    }
    ```

5. Start runner and worker (in separate shells)
    ```bash
    shell1: /tmp/bb-worker$ ./bb_runner runner.jsonnet
    shell2: /tmp/bb-worker$ ./bb_worker worker.jsonnet 
    ```

## Run build with RBE

This command will build Telegram iOS app with RBE in Tilt

```bash
bazel build Telegram/Telegram \
--override_repository=build_configuration=`pwd`/build-system/example-configuration \
--announce_rc --features=swift.use_global_module_cache \
--features=swift.skip_function_bodies_for_derived_files \
--define=buildNumber=100001 --define=telegramVersion=7.7 \
--features=swift.split_derived_files_generation \
-c opt --apple_generate_dsym --output_groups=+dsyms --features=swift.opt_uses_wmo \
--features=swift.opt_uses_osize --swiftcopt=-num-threads --swiftcopt=0 \
--features=dead_strip --objc_enable_binary_stripping --apple_bitcode=watchos=embedded \
--//Telegram:disableProvisioningProfiles=true \
--verbose_failures --subcommands=pretty_print \
--config=remote \
--remote_executor=grpc://localhost:8002 --remote_header=x-api-key=local_flare
```

To build with Bazel remote worker, change the last line to `--remote_executor=grpc://localhost:8080 --remote_cache=grpc://localhost:8080`

