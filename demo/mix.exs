defmodule Demo.MixProject do
  use Mix.Project

  System.put_env(%{
    "TARGET_ARCH" => "riscv64",
    "TARGET_CPU" => "baseline_rv64",
    "TARGET_OS" => "linux",
    "TARGET_ABI" => "gnu"
  })

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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Demo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exqlite, "~> 0.40"}
    ]
  end

  defp releases do
    [
      demo: [
        include_erts: false,
        steps: [:assemble, &create_rootfs/1]
      ]
    ]
  end

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
end
