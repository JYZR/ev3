defmodule EV3.StateAgent do
  @moduledoc """
  This module contains helpers for handling the states of EV3.Motors and
  EV3.Sensors.
  """

  def exists?(agent) do
    case Process.whereis(agent) do
      nil -> false
      _pid -> true
    end
  end

  def spawn(agent, state) do
    {:ok, pid} = Agent.start_link(fn -> state end)
    Process.register(pid, agent)
  end

  def get(agent, fun) do
    Agent.get(agent, fun)
  end

  def update(agent, state) do
    Agent.update(agent, fn _ -> state end)
  end

end
