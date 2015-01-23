defmodule EV3.Motor do
  import EV3.Motor.DSL

  @moduledoc """
  Provides functions for controlling an EV3 motor of type Tacho

  ## Example

      iex> EV3.Motor.run :outB, 100
      :ok
      iex> EV3.Motor.stop :outB
      :ok
      iex> EV3.Motor.reset :all
      [:ok, :ok]

  """

  @reference "http://www.ev3dev.org/docs/drivers/tacho-motor-class/"

  # A get function and optionally a set function will be generated for each
  # motor property, the prefixes are `get_` and `set_`
  def_motor_property "run",                   writable: true, min: 0, max: 1
  def_motor_property "run_mode",              writeable: true, modes:
                                              [:forever, :time, :position]
  def_motor_property "duty_cycle",            writable: false
  def_motor_property "duty_cycle_sp",         writable: true, min: -100,
                                                              max:  100
  def_motor_property "pulses_per_second",     writable: false
  def_motor_property "pulses_per_second_sp",  writable: true, min: -2000,
                                                              max:  2000
  def_motor_property "position",              writable: true
  def_motor_property "stop_mode",             writable: true, modes:
                                              [:coast, :brake, :hold]
  def_motor_property "regulation_mode",       writable: true, modes: [:off, :on]
  def_motor_property "polarity_mode",         writable: true, modes:
                                              [:normal, :inverted]
  def_motor_property "estop",                 writable: true
  def_motor_property "position_mode",         writable: true, modes:
                                              [:absolute, :relative]
  # reset is actually write-only
  def_motor_property "reset",                 writable: true, modes: [1]
  def_motor_property "state",                 writable: false

  defall run(port) do
    set_run port, 1
  end

  defall run(port, speed) do
    change_speed port, speed
    run port
  end

  def forward(port), do: forward(port, 100)

  defall forward(port, speed) do
    run port, speed
  end

  def backward(port), do: backward(port, 100)

  defall backward(port, speed) do
    run port, -speed
  end

  defall change_speed(port, speed) do
    case get_regulation_mode port do
      :off ->
        set_duty_cycle_sp port, speed
      :on ->
        set_pulses_per_second_sp port, speed * 20
    end
  end

  defall stop(port) do
    set_run port, 0
  end

  defall estop(port) do
    set_estop port, 1
  end

  defall reset_estop(port) do
    set_estop port, get_estop port
  end

  defall reset(port) do
    set_reset port, 1
  end

  defall switch_polarity(port) do
    case get_polarity_mode port do
      :normal ->
        set_polarity_mode port, :inverted
      :inverted ->
        set_polarity_mode port, :normal
    end
  end

end
