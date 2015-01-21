defmodule EV3.ColorSensor do

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

  # Mode            Description
  # ------------- --------------------------------------------------------------
  # :col_reflect  Reflected light intensity (0 to 100)
  # :col_ambient  Ambient light intensity (0 to 100)
  # :col_color    Detected color, see @colors
  # :ref_raw      Reflected light, raw values {integer, integer}
  # :rgb_raw      Raw color {red::0..255, green::0..255, blue::0..255}

  @modes [{"COL-REFLECT", :col_reflect},
          {"COL-AMBIENT", :col_ambient},
          {"COL-COLOR",   :col_color},
          {"REF-RAW",     :ref_raw},
          {"RGB-RAW",     :rgb_raw}]

  # Values for mode :col_color
  @colors %{"0" => :nothing,
            "1" => :black,
            "2" => :blue,
            "3" => :green,
            "4" => :yellow,
            "5" => :red,
            "6" => :white,
            "7" => :brown}

  def mode() do
    EV3.Sensors.get(@device_name)
      |> Path.join("mode")
      |> EV3.Util.read!
      |> mode_from_string
  end

  def set_mode(mode) do
    EV3.Sensors.get(@device_name)
      |> Path.join("mode")
      |> EV3.Util.write! mode_to_string(mode)
  end

  def value() do
    case mode() do
      :col_color ->
        EV3.Sensors.get(@device_name)
          |> Path.join("value0")
          |> EV3.Util.read!
          |> color_from_string
    end
  end

  #
  # Helper functions
  #

  defp mode_from_string(s) do
    List.keyfind(@modes, s, 0) |> elem 1
  end

  defp mode_to_string(m) do
    List.keyfind(@modes, m, 1) |> elem 0
  end

  defp color_from_string(s) do
    @colors[s]
  end


end
