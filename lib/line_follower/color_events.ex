defmodule EE.ColorEvents do
  use GenServer
  alias EE.LineFollower
  require Logger

  # Time in ms between each observation
  @interval 10

  # The default number of times a color needs to be observed before we are
  # certain of the color
  @threshold 5

  defmodule State do
    defstruct controller: nil, history: [], cur_col: nil
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
    Logger.info("Starting color events generator")
    EV3.ColorSensor.set_mode(:col_color)
    {:ok, %State{controller: args[:controller]}}
  end

  def handle_cast(:stop, state) do
    Logger.info("Stopping color events generator")
    {:stop, :normal, state}
  end

  def handle_info(:check, state) do
    color = EV3.ColorSensor.get_color(set_mode: false)
    new_history = Enum.take([color | state.history], @threshold)
    all_same = Enum.all?(new_history, fn c -> c == color end)
    new_state = case all_same and color != state.cur_col do
      true ->
        LineFollower.notify(state.controller, {:color, color})
        %{state | history: new_history, cur_col: color}
      false ->
        %{state | history: new_history}
    end
    :timer.send_after(@interval, :check)
    {:noreply, new_state}
  end

end
