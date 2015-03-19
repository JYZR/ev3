defmodule EE.LineFollower do
  use EV3.Util.GenFSM

  alias EV3.Util.GenFSM
  alias EE.BumperEvents
  alias EE.ReflectEvents

  require Logger

  #
  # Module attributes
  #

  @left_motor :outB
  @right_motor :outC
  @tail_motor :outD

  @line_follower_name :line_follower_p
  @bumper_name :bumper_p
  @reflect_name :reflect_p

  #
  # User API
  #

  def start() do
    GenFSM.start_link(__MODULE__, [], [name: @line_follower_name])
  end

  def stop() do
    case Process.whereis(@line_follower_name) do
      nil -> :ok
      _pid ->
        stop_line_follower()
    end
    stop_motors()
  end

  def stop_line_follower() do
    GenFSM.send_all_state_event(@line_follower_name, :stop)
  end

  #
  # API for Event Generators
  #

  def notify(fsm_ref, event) do
    case Enum.member?([:bumper_hit], event) do
      true ->
        GenFSM.send_all_state_event(fsm_ref, event)
      false ->
        GenFSM.send_event(fsm_ref, event)
    end
  end

  #
  # GenFSM callbacks
  #

  def init(_args) do
    EV3.Motor.reset(:all)
    Logger.info("Motors have been reset")
    BumperEvents.start_link(name: @bumper_name)
    Logger.info("Started bumper events generator")
    ReflectEvents.start_link(name: @reflect_name)
    Logger.info("Started reflect events generator")
    state_data = nil
    {:ok, :my_state, state_data}
  end

  def handle_event(event, state_name, state_data) do
    Logger.info("Received all states event '#{event}'" <>
                " when in state '#{state_name}'")
    case event do
      :bumper_hit ->
        stop_motors_and_event_generators()
        {:stop, :normal, state_data}
      :stop ->
        stop_motors_and_event_generators()
        {:stop, :normal, state_data}
    end
  end

  #
  # States
  #

  def my_state(event, state_data) do
    Logger.info("Received event '#{event}'" <>
                " when in state 'my_state'")
    case event do
      {:reflect, reflect} ->
        # # # # # # # # # # # # # #
        # Act upon reflect value  #
        # # # # # # # # # # # # # #
        {:next_state, :my_state, state_data}
      _ ->
        Logger.warning("Received unexpected event #{event}")
        {:next_state, :my_state, state_data}
    end
  end

  #
  # Helper functions
  #

  def stop_motors_and_event_generators() do
    Logger.info("Stopping everything")
    stop_motors()
    BumperEvents.stop(@bumper_name)
    ReflectEvents.stop(@reflect_name)
  end
  #
  # Motor functions
  #

  def stop_motors() do
    EV3.Motor.stop(@left_motor)
    EV3.Motor.stop(@right_motor)
  end

end
