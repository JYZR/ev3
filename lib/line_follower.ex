defmodule LineFollower do

  @left_motor :outB
  @right_motor :outC

  @forward_speed 50
  @slight_turn_factor 0.8

  @full_turn_speed 25

  # The default number of times a color needs to be observed before we are
  # certain of the color
  @color_observation_threshold 3

  # The time in ms between each color observation
  @color_observation_interval 10

  @doc """
  Start the LineFollower by spawning a controller
  """
  def start color \\ :white do
      EV3.ColorSensor.set_mode :col_color
      pid = spawn fn -> controller color end
      Process.register pid, :line_follower_pid
  end

  @doc """
  Stop the LineFollower by killing the controller and stopping the motors
  """
  def stop do
    case Process.whereis(:line_follower_pid) do
      nil -> :ok
      pid ->
        Process.exit pid, :shutdown
        Process.unregister :line_follower_pid
    end
    LineFollower.stop_motors
  end

  #
  # States
  #

  def controller color do
    find_line color
    follow_line color
  end

  def find_line color do
    forward
    stop_at_color color
    straighten_up color
  end

  @doc """
  This will line up the robot with the left edge of the line
  where the color sensor is just to the left of the line
  """
  def straighten_up color do
    turn_left
    stop_at_other_color color
  end

  def follow_line color do
    # We should now be on the left side of the left edge, i.e. outside the line
    forward_slight_right
    observe_until_color color
    # We should now be on the right side of the left edge, i.e. on the line
    forward_slight_left
    observe_until_other_color color
    # On the left side again...
    follow_line color
  end

  #
  # Helper states
  #

  def stop_at_color color do
    observe_until_color color
    stop_motors
  end

  def stop_at_other_color color do
    observe_until_other_color color
    stop_motors
  end

  @doc """
  This state will continue receiving messages with colors until the specified
  color has been seen `n` consecutive times
  """
  def observe_until_color color, n \\ @color_observation_threshold do
    observe_until_color color, n, n
  end
  def observe_until_color _color, 0, _n do
    :ok
  end
  def observe_until_color color, count, n do
    :timer.sleep @color_observation_interval
    case EV3.ColorSensor.value do
      ^color ->
        observe_until_color color, count-1, n
      _ ->
        observe_until_color color, n
    end
  end

  @doc """
  This state will continue receiving messages with colors until another color
  than the specified has been seen `n` consecutive times
  """
  def observe_until_other_color color, n \\ @color_observation_threshold do
    observe_until_other_color color, n, n
  end
  def observe_until_other_color _color, 0, _n do
    :ok
  end
  def observe_until_other_color color, count, n do
    :timer.sleep @color_observation_interval
    case EV3.ColorSensor.value do
      ^color ->
        observe_until_other_color color, n
      _ ->
        observe_until_other_color color, count-1, n
    end
  end

  #
  # Motor functions
  #

  def forward speed \\ @forward_speed do
    EV3.Motor.forward @left_motor, speed
    EV3.Motor.forward @right_motor, speed
  end

  def forward_slight_right do
    EV3.Motor.forward @left_motor, @forward_speed
    EV3.Motor.forward @right_motor, round @forward_speed * @slight_turn_factor
  end

  def forward_slight_left do
    EV3.Motor.forward @left_motor, round @forward_speed * @slight_turn_factor
    EV3.Motor.forward @right_motor, @forward_speed
  end

  def stop_motors do
    EV3.Motor.stop @left_motor
    EV3.Motor.stop @right_motor
  end

  def turn_left do
    EV3.Motor.forward @right_motor, @full_turn_speed
  end

  def turn_right do
    EV3.Motor.forward @left_motor, @full_turn_speed
  end

end
