# Nerves by Hand[^1]

This is a demo of the essence of the Nerves tooling. It leaves out details to
give the gist of how Nerves extends Elixir's mix tooling to support deployment
targets for embedded systems.

The goal is to build an Elixir project so that it can be run on an embedded
device like a Raspberry Pi. In reality, there are many devices that could be
targeted, but Raspberry Pis are well known. This demo runs on an emulated 64-bit
RISC-V processor using QEMU so there's no need to buy hardware. While running
on QEMU leaves out some important details, you'll likely have an idea of how
they might be added by the end of this tutorial.

## Prerequisites

You'll need to install Erlang, Elixir, QEMU, GNU tar, and the SquashFS
tools. Install Erlang and Elixir using [asdf](https://asdf-vm.com/) or mise so
that you get the right versions.

On macOS with Homebrew, install QEMU, GNU tar, and the SquashFS tools via:

```sh
brew install gnu-tar squashfs qemu
```

In order to build the embedded Linux parts, you'll need Docker. If you don't
want to do this, that step has instructions for downloading the build products.

## Terminology

Mix Release - This is the result of running `mix release` on an Elixir project.
It's the directory containing all of the build products needed to run the Elixir
and Erlang parts of your project.

Rootfs - This is the root filesystem that contains all of the programs,
libraries, and data files that are needed. For this demo, it will look like a
small Linux system. With Nerves, the rootfs is even smaller.

EXT4 - This is a common writable filesystem used on Linux.

SquashFS - This is a compressed read-only filesystem. The tooling for creating
SquashFS filesystems is friendlier than EXT4, so we'll eventually use it instead
of EXT4.

## Step 1 - Elixir project

The first step is to create a mix project with an Application supervisor to run
code when the project is started. The following commandline will do this:

```sh
mix new demo --sup
```

If you're running out of this repository, don't actually run `mix new demo
--sup`. you can use `git` to check out the code base and compare your changes to
the ones that worked for me. Run:

```sh
git checkout step1
```

Then update `application.ex` to log repeatedly. That's how we'll see that our
project is running in this demo.

```elixir
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Task, &repeat/0}
    ]

    opts = [strategy: :one_for_one, name: Hello.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repeat(count \\ 0) do
    Logger.info("Hello number #{count}")
    Process.sleep(2000)
    repeat(count + 1)
  end
```

Try it out:

```sh
mix run --no-halt
```

## Step 2 - Mix release

(If following using `git`, run `git checkout step2`)

Next, we're going to configure the project to create a mix release. This lets us
get all of the compiled code into one directory.

```sh
mix release.init
```

Then we'll need to configure the release settings in `mix.exs`. It's idiomatic
to add a `releases/0` function to hold the config.

```sh
  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end
...

  defp releases do
    [
      demo: [
        include_erts: false
      ]
    ]
  end
```

This tells the release builder to not include the Erlang runtime in the release
directory. Nerves actually does include the runtime, but for this walkthrough,
it's much easier to use the system version of Erlang. The disadvantage to using
the system Erlang is that all of the built-in Erlang libraries are installed
rather than only the required set. For Erlang, that's actually a lot, but we're
not optimizing the firmware size.

Now create the release:

```sh
mix release
```

Check out the files included in the release by looking at the
`_build/dev/rel/demo/` directory. Then run the release:

```sh
_build/dev/rel/demo/bin/demo start
```

Ctrl+C to exit.

## Step 3 - Create a base Linux system

The goal of this step is to build the Linux kernel and make a simple embedded
Linux rootfs. There's nothing specific to Elixir or Erlang in this step. If
you've used Raspberry Pi OS or Debian on an embedded Linux board like a
Raspberry Pi, this is like a very stripped down version where all of the
programs are fixed. If you use Linux, this should look familiar.

Note: Don't get hung up about Linux or Buildroot. While Nerves uses them both,
their usage in this demo is more for convenience and familiarity. The key parts
here are a kernel and a rootfs that can be assembled and modified off the
device.

The code for this section is all in the `base_image` directory. It uses the
[Buildroot](https://buildroot.org/) project to build the Linux kernel and
rootfs.

It takes some time to build. If you'd like to skip the build, download
`prebuilt_base_image.tgz` from [this project's release
products](https://github.com/fhunleth/nerves-by-hand/releases), untar, and skip
this next step.

```sh
cd base_image
make
```

When complete, the following files are produced:

- `output/images/Image` - the Linux kernel for a generic 64-bit RISC-V processor
- `output/images/rootfs.ext4` - the rootfs as an EXT4-formatted image file
- `output/images/rootfs.tar` - all of the files in the rootfs
- `output/images/fw_jump.bin` - OpenSBI firmware for the RISC-V processor

The `rootfs.tar` can be interesting to peruse. Look at it by running:

```
tar tf output/images/rootfs.tar | less
```

You'll see Linux utilities like `ls` and `cat`, configuration files under
`/etc`, shared libraries, and Erlang. You can imagine stripping out a lot
especially when looking at the Erlang libraries, but all of the files only add
up to about the size of the tar file. While the EXT4 image is quite a bit
larger, that's due to the Buildroot config setting the entire EXT4 filesystem
to be 128 MB. The EXT4 filesystem contains the exact same files.

This is a basic Buildroot configuration for creating a small embedded Linux
image for QEMU with the addition of Erlang, the Dropbear SSH server and a
startup script that will be used later.

## Step 4 - Run the base Linux system in QEMU

From the repository's root directory, run:

```sh
./run_base_image.sh
```

You should see:

```text
Starting crond: OK
Starting dropbear sshd: OK

Welcome to Buildroot
buildroot login:
```

The login user is `root` with password `root`.

Next check that `ssh` works by opening another terminal on your machine and
running:

```sh
ssh -p 2222 root@localhost
```

Look around. Logs are at `/var/log/messages`.

Run `poweroff` to exit QEMU nicely or from outside QEMU, run `killall
qemu-system-riscv64`.

Your experience with this Linux system in QEMU is very similar to what you'd
have on a Raspberry Pi or another Linux-capable board.

## Step 5 - Run the demo Elixir project under QEMU

(If following using `git`, run `git checkout step5`)

Now it's time to get back to our Elixir demo project to deploy it to the
emulated Linux device. If QEMU isn't running, run the `./run_base_image.sh` script
to start it up again. Then in another window go back to the `demo` directory and
copy the release over.

For this image, we're going to copy the demo release to `/opt`. It doesn't
matter where, but this image has an init script to run the first mix release it
finds in `/opt` on boot.

```sh
cd demo
rsync -av -e "ssh -p 2222" _build/dev/rel/demo root@localhost:/opt
```

Then switch to the console running QEMU and log in to get to a shell prompt. You
can test running the release in the foreground by running:

```sh
/opt/demo/bin/demo start
```

Press Ctrl+C when you're satisfied.

The `/etc/init.d/S99erlang` startup script will start the demo release in daemon
mode on boot now. If you're used to Systemd, this is the old way that Linux
systems used to be initialized. Since the demo release will be started as a
daemon, it logs the console output to a file. When our simulated Linux is
rebooted, you can find the logs in `/tmp/log/erlang.log.1`.

In the QEMU console, restart Linux by running:

```sh
reboot
```

Check the logs:

```sh
cat /tmp/log/erlang.log.1
```

You now have a simulated embedded device that automatically runs your Elixir
application!

## Step 6 - Making the rootfs as part of the build

Upgrading an image using `rsync` is fine for some use cases, but Nerves produces
the final image during the build step. Additionally, the Nerves image is
read-only to protect against corruption.

To do this, we're going to switch the final rootfs filesystem to SquashFS. It's
possible to continue to use EXT4, but the tools available for SquashFS are
easier to use. SquashFS is read-only and compressed by design so the final
image will be much smaller even though it has the same files.

There's a gotcha to creating any Linux root filesystem which is that root
filesystems have special types of files and permissions. The way to get around
this is to manipulate files via tar archives rather than extracting to a
directory and then making the filesystem out of that directory.

SquashFS tools have a command called
[`sqfstar`](https://github.com/plougher/squashfs-tools/blob/master/Documentation/4.7.6/USAGE-SQFSTAR.md)
that turns tar files into SquashFS filesystems. We'll first make a tar file
that combines the files from the original EXT4 image (conveniently also
in a tar file) with the files in the release. This can all be done as a mix
[release step](https://mix.hexdocs.pm/Mix.Tasks.Release.html#module-steps).

Add release step configuration to your `mix.exs` and add a function to run after
release assembly:

```elixir
  defp releases do
    [
      demo: [
        include_erts: false,
        steps: [:assemble, &create_rootfs/1]
      ]
    ]
  end
```

While the gist of combining the tar file and release files and creating a
SquashFS filesystem is straightforward, there's a subtlety with tar. If you're
on macOS or BSD, you'll need GNU tar to move the release files under
`/opt` in the generated filesystem. GNU tar is available on macOS via Homebrew
and is called `gtar`.

Here's the implementation for `create_rootfs/1` that should be put at the end of
the `mix.exs`:

```elixir
  defp create_rootfs(release) do
    base_tar = Path.expand("../base_image/output/images/rootfs.tar", __DIR__)

    name = release.name
    output = Path.dirname(release.path)
    combined = Path.join(output, "#{name}.tar")
    rootfs_path = Path.join(output, "#{name}.squashfs")

    File.cp!(base_tar, combined)
    shell!(output, "#{tar()} -r -f  #{combined} --transform=s,^#{name},opt/#{name}, #{name}")
    shell!(output, "sqfstar -force #{rootfs_path} < #{combined}")

    release
  end

  defp tar() do
    case :os.type() do
      {:unix, :darwin} -> "gtar"
      _ -> "tar"
    end
  end

  defp shell!(dir, cmd) do
    IO.puts(cmd)
    {_, 0} = System.shell(cmd, cd: dir, stderr_to_stdout: true)
  end
```

Don't worry about understanding it. When you run it, it will print out the `tar`
and `sqfstar` command lines, which are much easier to read.

```sh
mix release
```

Now you have a Linux kernel and rootfs that will run the demo Elixir
application! If this were a Raspberry Pi, you'd copy the kernel and rootfs to a
microSD card, plug it in, and it would boot to your app. (I've left details out,
but it's close.)

The SquashFS filesystem image and the combined tar file are in `_build/dev/rel`.
Notice that the filesystem is smaller. Use `unsquashfs -ll` to view the files in
the `demo.squashfs` file if you'd like.

Use the `run_demo_image.sh` script to start QEMU with your new release:

```sh
../run_demo_image.sh
```

Again, run `cat /tmp/log/erlang.log.1` to see the log messages and browse `/opt`
to see the release. Run `poweroff` to quit.

## Step 7 - Native code

(If following using `git`, run `git checkout step7`)

The Elixir application code we've used up to this point has been
platform-independent BEAM code. Native code is different: code compiled for one
operating system and processor architecture won't run on another.

To set this up, add a library with a NIF to the demo's `mix.exs`:

```elixir
  defp deps do
    [
      {:exqlite, "~> 0.40"}
    ]
  end
```

Run `mix deps.get`. If you run `mix run --no-halt`, you won't see anything.
Behind the scenes, the BEAM loads `exqlite`'s shared library automatically.

Now build and run on the emulated RISC-V:

```sh
mix release
../run_demo_image.sh
```

Log in and run `cat /tmp/log/erlang.log.1`. You'll see a crash report that
starts with this:

```text
=CRASH REPORT==== 21-Sep-2026::01:30:03.036662 ===
  crasher:
    initial call: kernel:init/1
    pid: <0.679.0>
    registered_name: []
    exception exit: {on_load_function_failed,'Elixir.Exqlite.Sqlite3NIF',
                        {error,
                            {load_failed,
                                "Failed to load NIF library: '/opt/demo/lib/exqlite-0.40.0/priv/sqlite3_nif.so: invalid ELF header'"}}}
```

One way to fix this is to build the demo code on a 64-bit RISC-V Linux machine.
You can find a cloud provider for them if you don't have one. However, Nerves
solves this problem by using cross-compilers on your local machine to build
compatible native code. Besides convenience, this allows Nerves to build native
code with the exact compiler options for running on the device which can be
really important due to the variety of embedded processors. It turns out that
to do this you just need the cross-compilers and to set environment variables.
Even though there's no official standard for environment variable naming to do
this, established conventions make this work most of the time. See
[Nerves-provided environment variables](https://nerves.hexdocs.pm/environment-variables.html#nerves-provided-environment-variables).

Since `exqlite` uses `elixir_make` and can download precompiled binaries, its
build is affected by the `TARGET_*` variables. The Nerves documentation
describes these variables. To make sure they're set before the `:exqlite`
dependency is compiled, set them at the top of `mix.exs`:

```elixir
defmodule Demo.MixProject do
  use Mix.Project

  System.put_env(%{
    "TARGET_ARCH" => "riscv64",
    "TARGET_CPU" => "baseline_rv64",
    "TARGET_OS" => "linux",
    "TARGET_ABI" => "gnu"
  })
  ...
```

Rebuild everything and run:

```sh
rm -fr _build
mix release
```

You can inspect the shared library directly after this step by running:

```sh
$ file _build/dev/lib/exqlite/priv/sqlite3_nif.so
_build/dev/lib/exqlite/priv/sqlite3_nif.so: ELF 64-bit LSB shared object, UCB RISC-V, RVC, double-float ABI, version 1 (SYSV), dynamically linked, BuildID[sha1]=3c145da70cadb9bb372a597ce04d22f8a72d858b, not stripped
```

Then run the demo image like before and see that the crash has been resolved
by looking at the logs:

```sh
../run_demo_image.sh
```

(If following using `git`, run `git checkout main` for these updates.)

## Review

This demo shows how to create a complete image that automatically starts your
Elixir application using Mix. The keys are to use the Mix release feature and
to set environment variables appropriately to cause native code to build
correctly. Therefore, when you run `mix release`, the following happens:

1. Environment variables are set for native code cross-compilation
2. Mix builds all dependencies and your code
3. Mix release assembles the build products into a directory (`:assemble` step)
4. A custom mix release step overlays the release directory onto a barebones
   Linux rootfs

For this demo, we used QEMU to emulate a 64-bit RISC-V processor and passed it a
prebuilt Linux kernel and the rootfs created by `mix release`.

With Nerves, [NervesBootstrap](https://hex.pm/packages/nerves_bootstrap) allows
the Nerves tooling to inject the environment variables before code gets built.
Nerves also uses Mix releases as you can tell by looking at the release
configuration of any Nerves project.

Nerves does do a few more things that are worth pointing out:

1. Uses [Mix targets](https://mix.hexdocs.pm/Mix.html#module-targets) to turn on
   and off the integration and also to allow targeting different hardware
   platforms.
2. Downloads cross-compilers, libraries, and header files at the very beginning.
   These are usually referenced by the environment variables directing native
   code compilation, so they need to be downloaded at the same time.
3. Combines the rootfs, kernel, and supporting files into a firmware file that
   can be used for over-the-air software updates or flashed to a microSD card.
4. Trims the base Linux rootfs down and uses
   [erlinit](https://github.com/nerves-project/erlinit) to immediately start the
   BEAM. Nerves doesn't actually require this, but it's pretty universal.

Of course, once you start booting to the BEAM on an embedded device, you find
that you'll want to have Elixir ways to set up networking, work with hardware
interfaces, and manage devices. Nerves libraries help fill these gaps.

Fundamentally, the Nerves tooling addresses the desire to support embedded
deployment targets to Elixir's Mix build tool. Hopefully this demo showed you
that at a high level, this isn't all that complicated. Nerves helps with the
details.

[^1]: This README.md was also written by hand in 2026.
