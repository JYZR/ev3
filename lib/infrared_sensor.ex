defmodule EV3.InfraredSensor do
  import EV3.Sensor.DSL

  @device_name "ev3-uart-33"

  @moduledoc """
  Provides functions for accessing an EV3 infrared sensor.

  ## Exported functions

  * `set_mode(port \\ :any, mode)`

  * `get_mode(port \\ :any)`

  * `proximity(opts \\ [port: :any, set_mode: true])`
  * `proximity(port, set_mode)`

  * `seek(opts \\ [port: :any, channel: 1, set_mode: true])`
  * `seek(port, channel, set_mode)`

  * `remote_simple(opts \\ [port: :any, channel: 1, set_mode: true])`
  * `remote_simple(port, channel, set_mode)`

  * `remote_adv(opts \\ [port: :any, set_mode: true]) `
  * `remote_adv(port, set_mode)`

  ## Modes

  * `:proximity`     - Distance [0..100] (100 is approximately 80 cm and beyond)
  * `:seek`          - Heading [-25..25] and distance [0..100] × 4 channels
  * `:remote_simple` - Simple way to read button presses on the remote
  * `:remote_adv`    - Advanced way to read button presses on the remote

  ## Examples

      iex> EV3.InfraredSensor.proximity
      79

      iex> EV3.InfraredSensor.seek
      %{distance: 56, heading: -3}

      iex> EV3.InfraredSensor.remote_simple
      :red_up

      iex> EV3.InfraredSensor.remote_adv
      %{blue_down: false, blue_up: true, red_down: false, red_up: true}

      iex> EV3.InfraredSensor.set_mode(:in3, :seek)
      :ok
      iex> EV3.InfraredSensor.seek port: :in3, channel: 2, set_mode: false
      %{distance: 56, heading: -3}
      iex> EV3.InfraredSensor.seek port: :in3, channel: 2, set_mode: false
      %{distance: 49, heading: -5}

  ## Options

  Use the option `set_mode: false` when performing repetitive readings for
  the same mode from a sensor.

  Use the option `port` when there may be several infrared sensors.

  Use the option `channel` if it is desirable to use several remotes.

  """

  @reference "http://www.ev3dev.org/docs/sensors/lego-ev3-infrared-sensor/"

  # The macro `def_sensor_modes` defines the basic functions which are needed to
  # get values out from a sensor, have a look in sensor_dsl.ex to find out more.

  def_sensor_modes [[string: "IR-PROX",   atom: :proximity,     num_values: 1],
                    [string: "IR-SEEK",   atom: :seek,          num_values: 8],
                    [string: "IR-REMOTE", atom: :remote_simple, num_values: 4],
                    [string: "IR-REM-A",  atom: :remote_adv,    num_values: 1]]

  @type values_remote_simple_type :: :none
                                   | :red_up
                                   | :red_down
                                   | :blue_up
                                   | :blue_down
                                   | :red_up_and_blue_up
                                   | :red_up_and_blue_down
                                   | :red_down_and_blue_up
                                   | :red_down_and_blue_down
                                   | :beacon_mode_on
                                   | :red_up_and_red_down
                                   | :blue_up_and_blue_down

  @values_map_remote_simple %{ 0 => :none,
                               1 => :red_up,
                               2 => :red_down,
                               3 => :blue_up,
                               4 => :blue_down,
                               5 => :red_up_and_blue_up,
                               6 => :red_up_and_blue_down,
                               7 => :red_down_and_blue_up,
                               8 => :red_down_and_blue_down,
                               9 => :beacon_mode_on,
                              10 => :red_up_and_red_down,
                              11 => :blue_up_and_blue_down}

  @type keys_remote_adv_type :: :red_up
                              | :red_down
                              | :blue_up
                              | :blue_down

  # Pressing more than 2 buttons at a time is not supported in simple mode.
  # Use advanced mode if that is needed. On the remote, pressing a button
  # while beacon mode is activated will turn off beacon mode.

  #=============================================================================
  # Function definitions
  #=============================================================================

  #-----------------------------------------------------------------------------
  # proximity
  #-----------------------------------------------------------------------------

  @doc """
  Returns the proximity of objects in front of the sensor, the values goes from
  0 to 100 where 100 is approximately 80 cm and beyond.

  ## Values

  * `0..100`

  ## Options

  Two options can be given:

  * `:port` - The port to which the sensor is attached, defaults to `:any`
  * `:set_mode` - Whether to write mode before reading values, default to `true`

  """
  @proximity_defaults [port: :any, set_mode: true]

  @spec proximity(Keyword.t) :: 0..100

  def proximity(opts \\ @proximity_defaults) when is_list(opts) do
    options = Keyword.merge(@proximity_defaults, opts)

    if options[:set_mode] == true do
      set_mode(options[:port], :proximity)
    end

    get_value0(options[:port])
  end

  def proximity(port, set_mode) do
    proximity(port: port, set_mode: set_mode)
  end

  #-----------------------------------------------------------------------------
  # seek
  #-----------------------------------------------------------------------------

  @doc """
  Returns the heading and distance to a remote which is set to beacon mode.
  A positive heading indicates that the remote is to the right while negative
  heading indicates left. For the distance, the values goes from 0 to 100 where
  100 is approximately 3 meters.

  ## Values

  * `%{heading: -25..25, distance: 0..100}`
  * `:out_of_range`

  ## Options

  Two options can be given:

  * `:port` - The port to which the sensor is attached, defaults to `:any`
  * `:channel` - The channel of the remote, defaults to `1`
  * `:set_mode` - Whether to write mode before reading values, default to `true`

  """
  @seek_defaults [port: :any, channel: 1, set_mode: true]

  @spec seek(Keyword.t)
        :: %{heading: -25..25, distance: 0..100} | :out_of_range

  def seek(opts \\ @seek_defaults) when is_list(opts) do
    options = Keyword.merge(@seek_defaults, opts)
    channel = options[:channel]; port = options[:port]

    unless channel >= 1 and channel <= 4 do
      raise("Invalid channel, should be 1, 2, 3 or 4")
    end

    if options[:set_mode] == true do
      set_mode(port, :seek)
    end

    index_offset = (channel-1) * 2
    heading = get_value(port, 0 + index_offset)
    distance = get_value(port, 1 + index_offset)
    case distance do
      -128 ->
        :out_of_range
      _ ->
        %{heading: heading, distance: distance}
    end
  end

  def seek(port, channel, set_mode) do
    seek(port: port, channel: channel, set_mode: set_mode)
  end

  #-----------------------------------------------------------------------------
  # remote_simple
  #-----------------------------------------------------------------------------

  @doc """
  Reads the signal of a remote control

  ## Values

  * `:none`
  * `:red_up`
  * `:red_down`
  * `:blue_up`
  * `:blue_down`
  * `:red_up_and_blue_up`
  * `:red_up_and_blue_down`
  * `:red_down_and_blue_up`
  * `:red_down_and_blue_down`
  * `:beacon_mode_on`
  * `:red_up_and_red_down`
  * `:blue_up_and_blue_down`

  ## Options

  Three options can be given:

  * `:port` - The port to which the sensor is attached, defaults to `:any`
  * `:channel` - The channel of the remote, defaults to `1`
  * `:set_mode` - Whether to write mode before reading values, default to `true`

  """
  @simple_defaults [port: :any, channel: 1, set_mode: true]

  @spec remote_simple(Keyword.t) :: values_remote_simple_type

  def remote_simple(opts \\ @simple_defaults) when is_list(opts) do
    options = Keyword.merge(@simple_defaults, opts)
    channel = options[:channel]; port = options[:port];

    unless channel >= 1 and channel <= 4 do
      raise("Invalid channel, should be 1, 2, 3 or 4")
    end

    if options[:set_mode] do
      set_mode(port, :remote_simple)
    end

    int_value = get_value(port, channel-1)
    @values_map_remote_simple[int_value]
  end

  def remote_simple(port, channel, set_mode) do
    remote_simple(port: port, channel: channel, set_mode: set_mode)
  end

  #-----------------------------------------------------------------------------
  # remote_adv
  #-----------------------------------------------------------------------------

  @doc """
  Returns a map that indicates which buttons that are pressed.

  Note that this mode _only_ works with channel 1.

  ## Values

  * `%{red_up, red_down, blue_up, blue_down}` - All values are booleans
  * `:none`
  * `:beacon_mode_on`

  ## Options

  Two options can be given:

  * `:port` - The port to which the sensor is attached, defaults to `:any`
  * `:set_mode` - Whether to write mode before reading values, default to `true`

  """
  @adv_defaults [port: :any, set_mode: true]

  @spec remote_adv(Keyword.t)
        :: %{keys_remote_adv_type => boolean} | :none | :beacon_mode_on

  def remote_adv(opts \\ @adv_defaults) when is_list(opts) do
    options = Keyword.merge(@adv_defaults, opts)

    unless options[:channel] == nil do
      raise("Only channel 1 can be used")
    end

    if options[:set_mode] == true do
      set_mode(options[:port], :remote_adv)
    end

    case get_value0(options[:port]) do
      384 -> :none
      262 -> :beacon_mode_on
      int ->
        <<blue_down::1, blue_up::1, red_down::1, red_up::1, _::4>> = <<int::8>>

        is_red_up  = red_up  == 1; is_red_down  = red_down  == 1
        is_blue_up = blue_up == 1; is_blue_down = blue_down == 1

        %{red_up:    is_red_up,
          red_down:  is_red_down,
          blue_up:   is_blue_up,
          blue_down: is_blue_down}
    end
  end

  def remote_adv(port, set_mode) do
    remote_adv(port: port, set_mode: set_mode)
  end

end
