defmodule PingPong.Server do
  use GenServer

  require Logger

  defstruct [:socket, :supervisor]

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
      {:ok, listen_socket} ->
        Logger.info("Started server on port #{port}")

        state = %__MODULE__{
          socket: listen_socket,
          supervisor: supervisor
        }

        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(
        :accept,
        %__MODULE__{socket: socket, supervisor: supervisor} = state
      ) do
    case :gen_tcp.accept(socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(supervisor, fn -> connect(socket) end)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        IO.puts("Cannot accept. Reason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp connect(socket) do
    case recv(socket, _buffer = "") do
      {:ok, data} ->
        :gen_tcp.send(socket, data)

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp recv(socket, buffer) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        IO.puts("RECEIVED REQUEST | FROM #{inspect(socket)} | #{inspect(data)}")
        :gen_tcp.send(socket, "ECHO | #{data}")

        recv(socket, [buffer, data])

      {:error, :closed} ->
        {:ok, buffer}

      {:error, reason} ->
        IO.puts("Error receiving data. #{inspect(reason)}")
        {:error, reason}
    end
  end
end
