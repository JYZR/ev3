defmodule EV3 do
  require Logger

  @type in_port :: :in1 | :in2 | :in3 | :in4
  @type out_port :: :outA | :outB | :outC | :outD

  def scan_ports do
    set_state :sensors_state, EV3.Sensors.scan
    set_state :motors_state, EV3.Motors.scan
  end

  defp set_state(agent, state) do
    case Process.whereis agent do
      nil ->
        {:ok, pid} = Agent.start_link fn -> state end
        Process.register pid, agent
      _pid ->
        Agent.update agent, fn _ -> state end
    end
  end

  def state_agent_get(agent, fun) do
    try do
      Agent.get agent, fun
    catch
      :exit, {:noproc, _} ->
        scan_ports
        Agent.get agent, fun
    end
  end

  #
  # Sensors module
  #

  defmodule Sensors do
    @sensors_dir "/sys/class/msensor/"

    @reference "http://www.ev3dev.org/docs/drivers/lego-sensor-class/"

    def get(name), do: get(name, false)
    defp get(name, is_retry) do
      list = EV3.state_agent_get :sensors_state, fn infos -> infos[name] end
      case list do
        [{_port, path}] ->
          path
        nil ->
          case is_retry do
            true ->
              raise "No sensor with name #{name}"
            false ->
              EV3.scan_ports
              get(name, true)
          end
        list when length(list) > 1 ->
          raise "Several sensors detected, please get/2"
      end
    end

    @spec scan() :: %{device_name::binary => [{EV3.in_port, path::binary}]}
    def scan() do
      File.ls!(@sensors_dir)
        |> List.foldl %{}, fn(sensor, acc) ->
          id = String.split(sensor, "sensor") |> List.last
          name = EV3.Util.read! @sensors_dir <> sensor <> "/name"
          port = EV3.Util.read! @sensors_dir <> sensor <> "/port_name"
          Logger.info "Device with ID #{id}" <>
                      " and name #{name}" <>
                      " found at port #{port}"
          info = {String.to_atom(port), Path.join([@sensors_dir, sensor])}
          Map.update(acc, name, [info],
                     fn infos -> [info | infos] end)
        end
    end
  end

  #
  # Motors module
  #

  defmodule Motors do
    @type type :: :tacho | :dc
    @tacho_motors_dir "/sys/class/tacho-motor/"
    @dc_motors_dir "/sys/class/dc-motor/"

    @reference_tacho "http://www.ev3dev.org/docs/drivers/tacho-motor-class/"
    @reference_dc "http://www.ev3dev.org/docs/drivers/dc-motor-class/"

    def get(port), do: get(port, false)
    defp get(port, is_retry) do
      case EV3.state_agent_get :motors_state,
        fn infos -> List.keyfind infos, port, 0 end do
        {^port, _path, _type} = info  ->
          info
        nil ->
          case is_retry do
            true ->
              raise "No motor at port #{port}"
            false ->
              EV3.scan_ports
              get(port, true)
          end
      end
    end

    def get_all() do
      EV3.state_agent_get :motors_state, fn infos -> infos end
    end

    @spec scan() :: [{EV3.out_port, path::binary, type::type}]
    def scan() do
      scan(:tacho, @tacho_motors_dir) ++ scan(:dc, @dc_motors_dir)
    end

    @spec scan(type, dir::binary) :: [{EV3.out_port, path::binary, type::type}]
    defp scan(type, dir) do
      File.ls!(dir)
        |> Enum.map fn(motor) ->
          id = String.split(motor, "motor") |> List.last
          port = EV3.Util.read! dir <> motor <> "/port_name"
          Logger.info "Motor of type #{type}" <>
                      " with ID #{id}" <>
                      " found at port #{port}"
          {String.to_atom(port),
           Path.join([dir, motor]),
           type}
        end
    end
  end

  def reload_modules do
    for {name,_} <- :code.all_loaded,
                    Regex.match?(~r/^Elixir.EV3/, to_string(name)) do
      :code.purge(name)
      :code.load_file(name)
    end
  end

end

