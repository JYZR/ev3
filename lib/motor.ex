defmodule EV3.Motor do
  import EV3.MotorDSL

  @moduledoc """
  Provides functions for controlling an EV3 motor of type Tacho or DC

  ## Example

      iex> EV3.Motors.run :outB, 100
      :ok
      iex> EV3.Motors.stop :outB
      :ok

  """

  @reference_tacho "http://www.ev3dev.org/docs/drivers/tacho-motor-class/"
  @reference_dc "http://www.ev3dev.org/docs/drivers/dc-motor-class/"

  motor_property "run",                   writable: true, min: 0, max: 1
  motor_property "duty_cycle",            writable: false
  motor_property "duty_cycle_sp",         writable: true, min: -100, max: 100
  motor_property "pulses_per_second",     writable: false
  motor_property "pulses_per_second_sp",  writable: true
  motor_property "position",              writable: true
  # stop_mode -> :idle
  # set_stop_mode -> :coast :brake :hold

  # switch_polarity

  def run(port) do
    set_run port, 1
  end

  def run(port, speed) do
    change_speed port, speed
    run port
  end

  def forward(port, speed \\ 100) do
    run port, speed
  end

  def backward(port, speed \\ 100) do
    run port, -speed
  end

  def change_speed(port, speed) do
    set_duty_cycle_sp port, speed
  end

  def stop(port) do
    set_run port, 0
  end

  def stop_all() do
    EV3.Motors.get_all()
    |> Enum.each fn {port, _path, _type} -> stop port end
  end

end
