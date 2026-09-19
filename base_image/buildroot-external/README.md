# Building Nerves by Hand

Run the build from the repository root:

```sh
make
```

Use `make shell` for an interactive shell in the build container and
`make clean` to remove all build output. Buildroot's working files are kept in
a container volume, and the finished images and configuration are exported to
`output/`.
