defmodule EV3.TouchSensor do
  import EV3.Sensor.DSL
  import EV3.Util

  @device_name "lego-ev3-touch"

  @moduledoc """
  Provides functions for accessing an EV3 touch sensor

  ## Example

      iex> EV3.TouchSensor.value
      :released

  """

  @reference "http://www.ev3dev.org/docs/sensors/lego-ev3-touch-sensor/"

  def_sensor_modes [[string: "TOUCH", atom: :touch, num_values: 1]]

  @values %{0 => :released,
            1 => :pressed}

  def value(port) when is_atom(port), do: value(port: port)

  def_as_opts value(port \\ :any) do
    get_value0(port) |> value_from_integer
  end

  def is_released?(port) when is_atom(port), do: is_released?(port: port)

  def_as_opts is_released?(port \\ :any) do
    value(port) == :released
  end

  def is_pressed?(port) when is_atom(port), do: is_pressed?(port: port)

  def_as_opts is_pressed?(port \\ :any) do
    value(port) == :pressed
  end

  #
  # Helper functions
  #

  defp value_from_integer(s) do
    @values[s]
  end

end
