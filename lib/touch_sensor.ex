defmodule EV3.TouchSensor do

  @device_name "lego-ev3-touch"

  @moduledoc """
  Provides functions for accessing an EV3 touch sensor

  ## Example

      iex> EV3.TouchSensor.value
      :released

  """

  @reference "http://www.ev3dev.org/docs/sensors/lego-ev3-touch-sensor/"

  @values %{"0" => :released,
            "1" => :pressed}

  def value() do
    EV3.Sensors.get(@device_name)
    |> Path.join("value0")
    |> EV3.Util.read!
    |> value_from_string
  end

  #
  # Helper functions
  #

  defp value_from_string(s) do
    @values[s]
  end

end
