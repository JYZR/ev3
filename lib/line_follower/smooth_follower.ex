defmodule EE.SmoothFollower do
  use EV3.Util.GenFSM

  alias EV3.Util.GenFSM
  alias EE.BumperEvents
  alias EE.ReflectEvents

  require Logger

  @moduledoc """
  The smooth follower is able to follow a black and not thin line on a white
  paper. It uses the reflection value of the color sensor which not only gives
  different values for black and white but also values which lays between when
  the sensor is above the edge of the line. It can use this to achieve
  progressive steering that results in a much smoother experience.
  """

  #
  # Module attributes
  #

  @left_motor :outB
  @right_motor :outC
  @tail_motor :outD

  @smooth_name :smooth_p
  @bumper_name :bumper_p
  @reflect_name :reflect_p

  #
  # User API
  #

  def start() do
    GenFSM.start_link(__MODULE__, [], [name: @smooth_name])
  end

  def stop() do
    case Process.whereis(@smooth_name) do
      nil -> :ok
      _pid ->
        stop_smooth()
    end
    stop_motors()
  end

  def stop_smooth() do
    GenFSM.send_all_state_event(@smooth_name, :stop)
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
    {:ok, :smooth, state_data}
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

  def smooth(event, state_data) do
    case event do
      {:reflect, reflect} ->
        min_reflect = 4
        max_reflect = 75
        # Normalize to a number in the range 0..100
        norm_reflect = normalize(reflect, min_reflect, max_reflect)
        # Offset to a number in the range -50..50
        pos_or_neg_reflect = norm_reflect - 50
        # Set left speed to a number in the range -25..55
        left_speed = round(15 + pos_or_neg_reflect / 50 * 40)
        # Set right speed to a number in the range -25..55
        right_speed = round(15 - pos_or_neg_reflect / 50 * 40)
        # Stating the obvious: The sum of both speeds will always be 30
        EV3.Motor.forward(@left_motor, left_speed)
        EV3.Motor.forward(@right_motor, right_speed)
        {:next_state, :smooth, state_data}
      _ ->
        Logger.warning("Received unexpected event #{event}")
        {:next_state, :smooth, state_data}
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

  def normalize(reflect, min, max) do
    cond do
      reflect < min ->
        0
      reflect > max ->
        100
      true ->
        interval = max - min
        diff = reflect - min
        round(diff / interval * 100)
    end
  end

  #
  # Motor functions
  #

  def stop_motors() do
    EV3.Motor.stop(@left_motor)
    EV3.Motor.stop(@right_motor)
  end

end
