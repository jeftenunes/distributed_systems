defmodule Broadcaster.Store do
  use Agent

  @default_name ResolverHitsStore

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @default_name)
    Agent.start_link(fn -> [] end, opts)
  end

  def get_clients(agent \\ @default_name) do
    Agent.get(agent, & &1)
  end

  def add_clients(agent \\ @default_name, client) do
    Agent.update(agent, &[client | &1])
  end

  def remove_client(agent \\ @default_name, client) do
    IO.inspect(client)
    Agent.update(agent, &List.delete(&1, client))
  end
end
