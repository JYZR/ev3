defmodule EV3.Sensor.DSL do

  @ports [:in1, :in2, :in3, :in4]

  @doc """
  This macro defines a set of functions for setting and getting the mode and
  also retrieving the values of a sensor.

  ## Defined public functions

      set_mode(port \\\\ :any, mode)
      get_mode(port \\\\ :any)

      get_value(port \\\\ :any, index)
      get_value0(port \\\\ :any), get_value1(port \\\\ :any) ...
      get_values(port \\\\ :any)

  ## Defined private functions

      get_string(mode::atom)
      get_atom(mode::string)
      get_num_values(mode::atom)
      convert_values_list(values::list)

  ## Example

      def_sensor_modes [[string: "COL-COLOR", atom: :col_color, num_values: 1],
                        [string: "RGB-RAW",   atom: :rgb_raw,   num_values: 3]]

  """
  defmacro def_sensor_modes(mode_specs) do

    # Check input
    for mode_spec <- mode_specs do
      string = mode_spec[:string]
      atom = mode_spec[:atom]
      num_values = mode_spec[:num_values]

      unless is_binary(string) do
        raise("Mode specification must contain :string")
      end

      unless is_atom(atom) and atom != nil do
        raise("Mode specification must contain :atom")
      end

      unless is_integer(num_values) do
        raise("Mode specification must contain :num_values")
      end
    end

    # Build data structures that will be unquoted in the functions
    mode_atoms = for ms <- mode_specs, do: ms[:atom]

    mode_tuples = quote do
      for ms <- unquote(mode_specs) do
        {ms[:atom], ms[:string], ms[:num_values]}
      end
    end

    # Create port check here since it will be used in both set and get funs
    port_check = quote do
      if not Enum.member?([:any | unquote(@ports)], port) do
        raise "Invalid port"
      end
    end

    # Create get_value0, get_value1 ... funs outside of quote since they will be
    # of arbitrarily quantity. Then unquote them in the returned quote.
    max_num_values = Enum.max(for ms <- mode_specs, do: ms[:num_values])

    get_value0_funs = for index <- 0..(max_num_values-1) do
      quote do
        def unquote(String.to_atom("get_value#{index}"))(port \\ :any) do
          get_value(port, unquote(index))
        end
      end
    end

    # Create the quote that will be returned
    quote do

      #
      # set_mode/{1,2}
      #

      def set_mode(port \\ :any, mode) do
        if not Enum.member?(unquote(mode_atoms), mode) do
          raise("Invalid mode")
        end
        unquote(port_check)
        EV3.Sensors.get(@device_name, port)
        |> Path.join("mode")
        |> EV3.Util.write! get_string(mode)
      end

      #
      # get_mode/{0,1}
      #

      def get_mode(port \\ :any) do
        unquote(port_check)
        EV3.Sensors.get(@device_name, port)
        |> Path.join("mode")
        |> EV3.Util.read!
        |> get_atom
      end

      #
      # get_value/{1,2}, get_value0../{0,1}, get_values/{0,1}
      #

      def get_value(port \\ :any, index) do
        EV3.Sensors.get(@device_name, port)
        |> Path.join("value#{index}")
        |> EV3.Util.read!
        |> String.to_integer
      end

      unquote(get_value0_funs)

      def get_values(port \\ :any) do
        mode = get_mode(port)
        num_values = get_num_values(mode)
        for index <- 0..(num_values-1) do
          get_value(port, index)
        end
        |> convert_values_list
      end

      #
      # Private help functions
      #

      @mode_tuples unquote(mode_tuples)

      defp get_string(atom) do
        List.keyfind(@mode_tuples, atom, 0) |> elem(1)
      end

      defp get_atom(string) do
        List.keyfind(@mode_tuples, string, 1) |> elem(0)
      end

      defp get_num_values(atom) do
        List.keyfind(@mode_tuples, atom, 0) |> elem(2)
      end

      defp convert_values_list(values) do
        case length(values) do
          1 ->
            hd(values)
          _ ->
            List.to_tuple(values)
        end
      end

    end
  end

end
