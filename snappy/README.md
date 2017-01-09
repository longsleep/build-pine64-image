
## Build image

```
UBUNTU_IMAGE_SKIP_COPY_UNVERIFIED_MODEL=1 ubuntu-image -c stable --image-size 2G --extra-snaps gadget/pine64_16.04-3_arm64.snap --extra-snaps kernel/pine64-kernel_3.10.104-2_arm64.snap -o test4.img pine64.model --debug
```
