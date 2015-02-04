defmodule EE.LineFollower do
  use EV3.Util.GenFSM

  alias EV3.Util.GenFSM
  alias EE.BumperEvents
  alias EE.ColorEvents
  alias Timex.Time

  require Logger

  import EE.LineFollower.Macros # defines the macro 'defstate'

  #
  # Module attributes
  #

  @left_motor :outB
  @right_motor :outC
  @tail_motor :outD

  @lf_name :lf_p
  @bumper_name :bumper_p
  @color_name :color_p

  #
  # State struct
  #

  defmodule State do
    defstruct target_c: nil,
              start_time: nil,
              cal_c: nil,
              rot_time: nil,
              forward_speed: nil,
              slight_turn_factor: nil,
              slow_speed: nil,
              full_turn_speed: nil,
              lost_timeout: nil
  end

  #
  # User API
  #

  @defaults [color: :white,
             forward_speed: 50,
             slight_turn_factor: 0.4,
             slow_speed: 25,
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
    state_data = %State{target_c:            args[:color],
                        forward_speed:       args[:forward_speed],
                        slight_turn_factor:  args[:slight_turn_factor],
                        slow_speed:          args[:slow_speed],
                        full_turn_speed:     args[:full_turn_speed],
                        lost_timeout:        args[:lost_timeout]}
    {:ok, :find_cal_color, state_data}
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

  def handle_info({:timer_event, event}, state_name, state_data) do
    GenFSM.send_event(self(), event)
    {:next_state, state_name, state_data}
  end

  #
  # States and pre-functions
  #

  defstate find_cal_color(state_data) do
    {:color, cal_c} ->
      find_rot_speed(%State{state_data | cal_c: cal_c})
  end

  def find_rot_speed(state_data) do
    start_time = round(Time.now(:msecs))
    turn_left(state_data)
    {:next_state, :find_rot_speed,
     %State{state_data | start_time: start_time}}
  end

  defstate find_rot_speed(%State{start_time: start_time, cal_c: cal_c} = state_data) do
    {:color, ^cal_c} ->
      stop_motors()
      rot_time = round(Time.now(:msecs)) - start_time
      find_line_forward_fast(%State{state_data | rot_time: rot_time})
  end

  def find_line_forward_fast(state_data) do
    forward(state_data)
    {:next_state, :find_line_forward_fast, state_data}
  end

  defstate find_line_forward_fast(%State{target_c: target} = state_data) do
    {:color, ^target} ->
      stop_motors()
      find_line_backward(state_data)
  end

  def find_line_backward(state_data) do
    backward(25)
    {:next_state, :find_line_backward, state_data}
  end

  defstate find_line_backward(%State{target_c: target} = state_data) do
    {:color, color} when color != target  ->
      find_line_forward_slow(state_data)
  end

  def find_line_forward_slow(state_data) do
    # EV3.Motor.set_stop_mode(@left_motor, :brake)
    # EV3.Motor.set_stop_mode(@right_motor, :brake)
    forward_slow(state_data)
    {:next_state, :find_line_forward_slow, state_data}
  end

  defstate find_line_forward_slow(%State{target_c: target} = state_data) do
    {:color, ^target} ->
      stop_motors()
      find_square_angle(state_data)
  end

  def find_square_angle(state_data) do
    turn_left(state_data)
    {:next_state, :find_square_angle_ph_1, state_data}
  end

  # When looking to the left
  defstate find_square_angle_ph_1(%State{target_c: target} = state_data) do
    {:color, color} when color != target ->
      stop_motors()
      start_time = round(Time.now(:msecs))
      turn_right(state_data)
      {:next_state, :find_square_angle_ph_2, %State{state_data | start_time: start_time}}
  end

  # When looking for the line again
  defstate find_square_angle_ph_2(%State{target_c: target} = state_data) do
    {:color, ^target} ->
      {:next_state, :find_square_angle_ph_3, state_data}
  end

  # When looking to the right
  defstate find_square_angle_ph_3(%State{target_c: target, start_time: start_time} = state_data) do
    {:color, color} when color != target ->
      stop_motors()
      turn_time = round(Time.now(:msecs)) - start_time
      turn_left(state_data)
      :timer.send_after(div(turn_time, 2), {:timer_event, :now_square})
      {:next_state, :find_square_angle_ph_4, state_data}
  end

  # When waiting for square angle
  defstate find_square_angle_ph_4(state_data) do
    :now_square ->
      stop_motors()
      align_along_line(state_data)
  end

  # Turn 90 degress left
  def align_along_line(%State{rot_time: rot_time} = state_data) do
    turn_left(state_data)
    :timer.send_after(div(rot_time, 4), {:timer_event, :aligned})
    {:next_state, :align_along_line_ph_1, state_data}
  end

  defstate align_along_line_ph_1(state_data) do
    :aligned ->
      stop_motors()
      on_left_side(state_data)
  end

  def straighten_up(state_data) do
    turn_left(state_data)
    {:next_state, :straighten_up, state_data}
  end

  defstate straighten_up(%State{target_c: target} = state_data) do
    {:color, color} when color != target ->
      stop_motors()
      on_left_side(state_data)
  end

  def on_left_side(%State{lost_timeout: lost_timeout} = state_data) do
    forward_slight_right(state_data)
    {:next_state, :on_left_side, state_data, lost_timeout}
  end

  defstate on_left_side(%State{target_c: target} = state_data) do
    {:color, ^target} ->
      on_right_side(state_data)
    :timeout ->
      stop_when_lost()
      {:stop, :normal, state_data}
  end

  def on_right_side(%State{lost_timeout: lost_timeout} = state_data) do
    forward_slight_left(state_data)
    {:next_state, :on_right_side, state_data, lost_timeout}
  end

  defstate on_right_side(%State{target_c: target} = state_data) do
    {:color, color} when color != target ->
      on_left_side(state_data)
    :timeout ->
      stop_when_lost()
      {:stop, :normal, state_data}
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

  def forward(speed) when is_integer(speed) do
    EV3.Motor.forward(@left_motor, speed)
    EV3.Motor.forward(@right_motor, speed)
  end

  def forward(%State{forward_speed: speed}), do: forward(speed)

  def forward_slow(%State{slow_speed: speed}) do
    EV3.Motor.forward(@left_motor, speed)
    EV3.Motor.forward(@right_motor, speed)
  end

  def backward(speed) when is_integer(speed) do
    EV3.Motor.backward(@left_motor, speed)
    EV3.Motor.backward(@right_motor, speed)
  end

  def forward_slight_right(%State{forward_speed: forward_speed,
                                  slight_turn_factor: slight_turn_factor}) do
    EV3.Motor.forward(@left_motor, forward_speed)
    EV3.Motor.forward(@right_motor, round(forward_speed * slight_turn_factor))
  end

  def forward_slight_left(%State{forward_speed: forward_speed,
                                 slight_turn_factor: slight_turn_factor}) do
    EV3.Motor.forward(@left_motor, round(forward_speed * slight_turn_factor))
    EV3.Motor.forward(@right_motor, forward_speed)
  end

  def stop_motors() do
    EV3.Motor.stop(@left_motor)
    EV3.Motor.stop(@right_motor)
  end

  def turn_left(%State{full_turn_speed: full_turn_speed}) do
    EV3.Motor.backward(@left_motor, full_turn_speed)
    EV3.Motor.forward(@right_motor, full_turn_speed)
  end

  def turn_right(%State{full_turn_speed: full_turn_speed}) do
    EV3.Motor.forward(@left_motor, full_turn_speed)
    EV3.Motor.backward(@right_motor, full_turn_speed)
  end

  def wag_tail() do
    EV3.Motor.run(@tail_motor, 100)
    spawn fn -> :timer.sleep 5000; EV3.Motor.stop(@tail_motor) end
  end

end
