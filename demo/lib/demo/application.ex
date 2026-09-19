defmodule Demo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

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
end
