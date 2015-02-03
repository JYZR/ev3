defmodule EE.BumperEvents do
  use GenServer
  alias EE.LineFollower
  require Logger

  @moduledoc """
  A process which sends an event if the bumper hits anything
  """

  # Time in ms between each observation
  @interval 100

  defmodule State do
    defstruct controller: nil
  end

  #
  # API
  #

  def start_link(options \\ []) do
    {:ok, pid} = GenServer.start_link(__MODULE__,
                                      [controller: self()],
                                      options)
    :timer.send_after(@interval, pid, :check)
    {:ok, pid}
  end

  def stop(name) do
    GenServer.cast(name, :stop)
  end

  #
  # GenServer callbacks
  #

  def init(args) do
    Logger.info("Starting bumper events generator")
    {:ok, %State{controller: args[:controller]}}
  end

  def handle_cast(:stop, state) do
    Logger.info("Starting bumper events generator")
    {:stop, :normal, state}
  end

  def handle_info(:check, state) do
    if EV3.TouchSensor.value == :pressed do
      LineFollower.notify(state.controller, :bumper_hit)
    end
    :timer.send_after(@interval, :check)
    {:noreply, state}
  end

end
