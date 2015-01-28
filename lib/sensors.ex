defmodule EV3.Sensors do
  require Logger
  alias EV3.StateAgent

  @moduledoc """
  This module provides functions for getting the path to a sensor based on its
  name and optionally port. It is however required to specify port when there
  are several sensors of the same type connected. Scanning of connected sensors
  will be done in a reactive manner so there is no other function which needs to
  be called beforehand. You will however have problems if sensors are
  disconnected and reconnected after the first scanning has occured.

  ## API

      get(name, port \\ :any) :: path

  """

  @sensors_dir "/sys/class/msensor/"

  @reference "http://www.ev3dev.org/docs/drivers/lego-sensor-class/"

  @state_agent :sensors_state

  @doc """
  Finds the path to a sensor based on its name and optionally port.
  """
  @spec get(binary, EV3.in_port | :any) :: path::binary
  def get(name, port \\ :any), do: get(name, port, false)
  defp get(name, port, is_retry) do
    list = access_state(fn infos -> infos[name] end)
    case {port, list, is_retry} do
      {_, nil, false} ->
        retry_get(name, port)
      {_, nil, true} ->
        raise "No sensor with name #{name} connected"
      {:any, [{_port, path}], _} ->
        path
      {:any, list, _} when length(list) > 1 ->
        raise "Several sensors with name #{name} detected, please specify port"
      {_, list, _} ->
        case List.keyfind(list, port, 0) do
          {^port, path} ->
            path
          nil ->
            case is_retry do
              false ->
                retry_get(name, port)
              true ->
                raise "No sensor with name #{name} at port #{port}"
            end
        end
    end
  end

  defp retry_get(name, port) do
    update_state()
    get(name, port, true)
  end

  @spec scan() :: %{device_name::binary => [{EV3.in_port, path::binary}]}
  def scan() do
    File.ls!(@sensors_dir)
    |> List.foldl(%{},
        fn(sensor, acc) ->
          id = String.split(sensor, "sensor") |> List.last()
          name = EV3.Util.read!(@sensors_dir <> sensor <> "/name")
          port = EV3.Util.read!(@sensors_dir <> sensor <> "/port_name")
          Logger.info("Device with ID #{id}" <>
                      " and name #{name}" <>
                      " found at port #{port}")
          info = {String.to_atom(port), Path.join([@sensors_dir, sensor])}
          Map.update(acc, name, [info],
                     fn infos -> [info | infos] end)
        end)
  end

  #
  # Functions for handling the state agent so we don't need to scan the file
  # system at every request of a sensor
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
