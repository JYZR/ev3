defmodule EE.LineFollower do
  use EV3.Util.GenFSM
  alias EV3.Util.GenFSM
  alias EE.BumperEvents
  alias EE.ColorEvents
  require Logger

  @left_motor :outB
  @right_motor :outC
  @tail_motor :outD

  @forward_speed 50
  @slight_turn_factor 0.5

  @full_turn_speed 25

  # Time in ms before the robot would say it is lost
  @lost_timeout 5000

  @lf_name :lf_p
  @bumper_name :bumper_p
  @color_name :color_p

  defmodule State do
    defstruct target_c: nil
  end

  #
  # User API
  #

  @defaults [color: :white,
             forward_speed: 50,
             slight_turn_factor: 0.5,
             full_turn_speed: 25,
             lost_timeout: 5000]

  def start(opts \\ @defaults) do
    parameters = Keyword.merge(@defaults, opts)
    GenFSM.start_link(__MODULE__, parameters, [name: @lf_name])
  end

  def stop() do
    case Process.whereis(@lf_name) do
      nil -> :ok
      _pid ->
        stop_lf()
    end
    stop_motors()
  end

  def stop_lf() do
    GenFSM.send_all_state_event(@lf_name, :stop)
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

  def init(args) do
    EV3.Motor.reset(:all)
    Logger.info("Motors have been reset")
    BumperEvents.start_link(name: @bumper_name)
    Logger.info("Started bumper events generator")
    ColorEvents.start_link(name: @color_name)
    Logger.info("Started color events generator")
    forward()
    {:ok, :find_line_forward_fast, %State{target_c: args[:color]}}
  end

  def handle_event(event, state_name, state_data) do
    Logger.info("Received all states event '#{event}' when in state '#{state_name}'")
    case event do
      :bumper_stop ->
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

  def find_line_forward_fast(event, %State{target_c: target} = state_data) do
    Logger.info("Received event '#{event}' when in state '#{:find_line_forward_fast}'")
    case event do
      {:color, ^target} ->
        backward(25)
        {:next_state, :find_line_backward, state_data}
      _ ->
        {:next_state, :find_line_forward_fast, state_data}
    end
  end

  def find_line_backward(event, %State{target_c: target} = state_data) do
    Logger.info("Received event '#{event}' when in state '#{:find_line_backward}'")
    case event do
      {:color, color} when color != target  ->
        EV3.Motor.set_stop_mode(@left_motor, :brake)
        EV3.Motor.set_stop_mode(@right_motor, :brake)
        forward(10)
        {:next_state, :find_line_foward_slow, state_data}
      _ ->
        {:next_state, :find_line_backward, state_data}
    end

  end

  def find_line_foward_slow(event, %State{target_c: target} = state_data) do
    Logger.info("Received event '#{event}' when in state '#{:find_line_foward_slow}'")
    case event do
      {:color, ^target} ->
        stop_motors()
        turn_left()
        {:next_state, :straighten_up, state_data}
      _ ->
        {:next_state, :find_line_foward_slow, state_data}
    end
  end

  def straighten_up(event, %State{target_c: target} = state_data) do
    Logger.info("Received event '#{event}' when in state '#{:straighten_up}'")
    case event do
      {:color, color} when color != target ->
        # We should now be on the left side of the left edge, i.e. outside the line
        stop_motors()
        forward_slight_right()
        {:next_state, :on_left_side, state_data}
      _ ->
        {:next_state, :straighten_up, state_data}
    end
  end

  def on_left_side(event, %State{target_c: target} = state_data) do
    Logger.info("Received event '#{event}' when in state '#{:on_left_side}'")
    case event do
      {:color, ^target} ->
        # We should now be on the right side of the left edge, i.e. on the line
        forward_slight_left
        {:next_state, :on_right_side, state_data, @lost_timeout}
      :timeout ->
        stop_when_lost()
        {:stop, :normal, state_data}
      _ ->
        {:next_state, :on_left_side, state_data, @lost_timeout}
    end
  end

  def on_right_side(event, %State{target_c: target} = state_data) do
    Logger.info("Received event '#{event}' when in state '#{:on_right_side}'")
    case event do
      {:color, color} when color != target ->
        # On the left side again...
        forward_slight_right()
        {:next_state, :on_left_side, state_data, @lost_timeout}
      :timeout ->
        stop_when_lost()
        {:stop, :normal, state_data}
      _ ->
        {:next_state, :on_right_side, state_data, @lost_timeout}
    end
  end


  #
  # Helper functions
  #

  def stop_motors_and_event_generators() do
    Logger.info("Stopping everything")
    stop_motors()
    BumperEvents.stop(@bumper_name)
    ColorEvents.stop(@color_name)
  end

  def stop_when_lost() do
    Logger.info("Sorry I'm lost")
    stop_motors_and_event_generators()
    wag_tail()
  end

  #
  # Motor functions
  #

  def forward(speed \\ @forward_speed) do
    EV3.Motor.forward(@left_motor, speed)
    EV3.Motor.forward(@right_motor, speed)
  end

  def backward(speed) do
    EV3.Motor.backward(@left_motor, speed)
    EV3.Motor.backward(@right_motor, speed)
  end

  def forward_slight_right() do
    EV3.Motor.forward(@left_motor, @forward_speed)
    EV3.Motor.forward(@right_motor, round(@forward_speed * @slight_turn_factor))
  end

  def forward_slight_left() do
    EV3.Motor.forward(@left_motor, round(@forward_speed * @slight_turn_factor))
    EV3.Motor.forward(@right_motor, @forward_speed)
  end

  def stop_motors() do
    EV3.Motor.stop(@left_motor)
    EV3.Motor.stop(@right_motor)
  end

  def turn_left() do
    EV3.Motor.backward(@left_motor, @full_turn_speed)
    EV3.Motor.forward(@right_motor, @full_turn_speed)
  end

  def turn_right() do
    EV3.Motor.forward(@left_motor, @full_turn_speed)
    EV3.Motor.backward(@right_motor, @full_turn_speed)
  end

  def wag_tail() do
    EV3.Motor.run(@tail_motor, 100)
    spawn fn -> :timer.sleep 5000; EV3.Motor.stop(@tail_motor) end
  end

end
