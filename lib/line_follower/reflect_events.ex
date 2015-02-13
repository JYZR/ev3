defmodule EE.ReflectEvents do
  use GenServer
  alias EE.SmoothFollower
  require Logger

  @port :in2

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
    # EV3.ColorSensor.set_mode(:col_reflect)
    {:ok, _msg_id} = EV3BT.ColorSensor.get_reflect_async(@port)
    {:ok, %State{controller: args[:controller]}}
  end

  def handle_cast(:stop, state) do
    Logger.info("Stopping reflect events generator")
    {:stop, :normal, state}
  end

  def handle_info({:reply, _msg_id, reply}, state) do
    reflect = EV3BT.ColorSensor.decode_async_reply_reflect(reply)
    SmoothFollower.notify(state.controller, {:reflect, reflect})
    {:ok, _msg_id} = EV3BT.ColorSensor.get_reflect_async(@port)
    {:noreply, state}
  end

end
