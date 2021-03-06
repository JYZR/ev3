defmodule EV3.ColorSensor do
  import EV3.Sensor.DSL
  import EV3.Util

  @device_name "ev3-uart-29"

  @moduledoc """
  Provides functions for accessing an EV3 color sensor

  ## Example

      iex> EV3.ColorSensor.set_mode :col_color
      :ok
      iex> EV3.ColorSensor.value
      :white

  """

  @reference "http://www.ev3dev.org/docs/sensors/lego-ev3-color-sensor/"

  # Mode          Description
  # ------------- --------------------------------------------------------------
  # :col_reflect  Reflected light intensity (0 to 100)
  # :col_ambient  Ambient light intensity (0 to 100)
  # :col_color    Detected color, see @colors
  # :ref_raw      Reflected light, raw values {integer, integer}
  # :rgb_raw      Raw color {red::0..255, green::0..255, blue::0..255}

  # The macro `def_sensor_modes` defines the basic functions which are needed to
  # get values out from a sensor, have a look in sensor_dsl.ex to find out more.

  def_sensor_modes [[string: "COL-REFLECT", atom: :col_reflect, num_values: 1],
                    [string: "COL-AMBIENT", atom: :col_ambient, num_values: 1],
                    [string: "COL-COLOR",   atom: :col_color,   num_values: 1],
                    [string: "REF-RAW",     atom: :ref_raw,     num_values: 2],
                    [string: "RGB-RAW",     atom: :rgb_raw,     num_values: 3]]

  # Values for mode :col_color
  @colors %{0 => :nothing,
            1 => :black,
            2 => :blue,
            3 => :green,
            4 => :yellow,
            5 => :red,
            6 => :white,
            7 => :brown}

  def_as_opts get_reflect(port \\ :any, set_mode \\ true) do
    if set_mode == true do
      set_mode(port, :col_reflect)
    end
    get_values(port)
  end

  def get_reflect(port, set_mode) do
    get_reflect(port: port, set_mode: set_mode)
  end

  def_as_opts get_ambient(port \\ :any, set_mode \\ true) do
    if set_mode == true do
      set_mode(port, :col_ambient)
    end
    get_values(port)
  end

  def get_ambient(port, set_mode) do
    get_ambient(port: port, set_mode: set_mode)
  end

  def_as_opts get_color(port \\ :any, set_mode \\ true) do
    if set_mode == true do
      set_mode(port, :col_color)
    end
    get_values(port) |> color_from_integer
  end

  def get_color(port, set_mode) do
    get_color(port: port, set_mode: set_mode)
  end

  #
  # Helper functions
  #

  defp color_from_integer(s) do
    @colors[s]
  end

end
