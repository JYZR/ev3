defmodule EE.ReflectEvents do
  use GenServer
  alias EE.SmoothFollower
  require Logger

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
    Logger.info("Starting reflect events generator")
    EV3.ColorSensor.set_mode(:col_reflect)
    {:ok, %State{controller: args[:controller]}}
  end

  def handle_cast(:stop, state) do
    Logger.info("Stopping reflect events generator")
    {:stop, :normal, state}
  end

  def handle_info(:check, state) do
    reflect = EV3.ColorSensor.get_reflect(set_mode: false)
    SmoothFollower.notify(state.controller, {:reflect, reflect})
    :timer.send_after(@interval, :check)
    {:noreply, state}
  end

end
