defmodule EV3.Motors do
  require Logger
  alias EV3.StateAgent

  @moduledoc """
  This module provides functions for getting the path and type of a motor from
  its port. Scanning of connected motors will be done in a reactive manner so
  there is no other function which needs to be called beforehand. You will
  however have problems if motors are disconnected and reconnected after the
  first scanning has occured.

  ## API

      get(port) :: {port, path, type}

  """

  @type type :: :tacho | :dc

  @tacho_motors_dir "/sys/class/tacho-motor/"
  @dc_motors_dir "/sys/class/dc-motor/"

  @reference_tacho "http://www.ev3dev.org/docs/drivers/tacho-motor-class/"
  @reference_dc "http://www.ev3dev.org/docs/drivers/dc-motor-class/"

  @state_agent :motors_state

  def get(port), do: get(port, false)
  defp get(port, is_retry) do
    case access_state(fn infos -> List.keyfind(infos, port, 0) end) do
      {^port, _path, _type} = info  ->
        info
      nil ->
        case is_retry do
          true ->
            raise "No motor at port #{port}"
          false ->
            update_state()
            get(port, true)
        end
    end
  end

  def get_all() do
    access_state(fn infos -> infos end)
  end

  @spec scan() :: [{EV3.out_port, path::binary, type::type}]
  def scan() do
    scan(:tacho, @tacho_motors_dir) ++ scan(:dc, @dc_motors_dir)
  end

  @spec scan(type, dir::binary)
        :: [{EV3.out_port, path::binary, type::type}]
  defp scan(type, dir) do
    File.ls!(dir)
    |> Enum.map(
        fn(motor) ->
          id = String.split(motor, "motor") |> List.last()
          port = EV3.Util.read!(dir <> motor <> "/port_name")
          Logger.info("Motor of type #{type}" <>
                      " with ID #{id}" <>
                      " found at port #{port}")
          {String.to_atom(port), Path.join([dir, motor]), type}
        end)
  end

  #
  # Functions for handling the state agent so we don't need to scan the file
  # system at every request of a motor
  #

  defp access_state(fun) do
    case StateAgent.exists?(@state_agent) do
      true ->
        StateAgent.get(@state_agent, fun)
      false ->
        StateAgent.spawn(@state_agent, scan())
        access_state(fun)
    end
  end

  defp update_state() do
    StateAgent.update(@state_agent, scan())
  end

end
