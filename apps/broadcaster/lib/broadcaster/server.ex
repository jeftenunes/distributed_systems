defmodule Broadcaster.Server do
  use GenServer
  alias Broadcaster.Store

  require Logger

  defstruct [:supervisor, :client]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      ifaddr: {0, 0, 0, 0},
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      packet: :line,
      buffer: 1024 * 100
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, socket} ->
        Logger.info("Listening on the port: #{port}")

        state = %__MODULE__{
          client: socket,
          supervisor: supervisor
        }

        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Error! Reason: #{reason}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(
        :accept,
        %__MODULE__{client: socket, supervisor: supervisor} = state
      ) do
    case :gen_tcp.accept(socket) do
      {:ok, socket} ->
        Store.add_clients(socket)

        Logger.info("Start accepting connections. Socket #{inspect(socket)}")
        Task.Supervisor.start_child(supervisor, fn -> connect(socket) end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.info("Cannot accept. Reason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp connect(socket) do
    case recv_until_closed(socket, _buffer = "") do
      {:ok, data} ->
        Logger.info("CLOSED | serve | FROM #{inspect(socket)} | #{inspect(data)}")

      {:error, reason} ->
        Logger.error("Error receiving data. #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp recv_until_closed(socket, buffer) do
    IO.inspect(socket)

    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        Logger.info(
          "RECEIVED REQUEST | recv_until_closed | FROM #{inspect(socket)} | #{inspect(data)}"
        )

        broadcast(data)
        recv_until_closed(socket, [buffer, data])

      {:error, :closed} ->
        IO.inspect("CLOSED")
        Store.remove_client(socket)
        {:ok, buffer}

      {:error, reason} ->
        Logger.error("Error receiving data. #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_clients() do
    Store.get_clients()
  end

  defp broadcast(data) do
    sockets = get_clients()

    Logger.info("BROADCASTING | COUNT | #{inspect(sockets |> Enum.count())}")

    sockets
    |> Enum.each(fn socket -> :gen_tcp.send(socket, data) end)
  end
end
