defmodule EV3.Motor.DSL do

  @ports [:outA, :outB, :outC, :outD]

  @doc """
  Defines get function and optionally set function for the given property

  ## Examples

      def_motor_property "run",        writable: true, min: 0, max: 1
      def_motor_property "duty_cycle", writable: false
      def_motor_property "stop_mode",  writable: true,
                                       modes: [:coast, :brake, :hold]

  """
  defmacro def_motor_property(property, options \\ []) do

    get_function_name = String.to_atom("get_" <> property)
    set_function_name = String.to_atom("set_" <> property)

    port_check = quote do
      if not Enum.member? unquote(@ports), port do
        raise "Invalid port"
      end
    end

    # define get function
    getter = quote do
      def unquote(get_function_name)(port) do
        unquote(port_check)
        EV3.Motors.get(port)
        |> elem(1)
        |> Path.join(unquote(property))
        |> EV3.Util.read!
        |> EV3.Util.string_to_integer_or_atom
      end
    end

    # define get all function
    getter_all = quote do
      def unquote(get_function_name)(:all) do
        for {port, _path, _type} <- EV3.Motors.get_all() do
          unquote(get_function_name)(port)
        end
      end
    end

    getters = [getter_all, getter]

    maybe_setters = if options[:writable] == true do

      maybe_min_check = if options[:min] != nil do
        min = options[:min]
        quote do
          if value < unquote(min) do
            raise "Value is below minimum"
          end
        end
      end

      maybe_max_check = if options[:max] != nil do
        max = options[:max]
        quote do
          if value > unquote(max) do
            raise "Value is above maximum"
          end
        end
      end

      maybe_modes_check = if options[:modes] != nil do
        modes = options[:modes]
        quote do
          if not Enum.member? unquote(modes), value do
            raise "Unknown mode"
          end
        end
      end

      # define set function
      setter = quote do
        def unquote(set_function_name)(port, value) do
          unquote(port_check)
          unquote(maybe_min_check)
          unquote(maybe_max_check)
          unquote(maybe_modes_check)

          EV3.Motors.get(port)
          |> elem(1)
          |> Path.join(unquote(property))
          |> EV3.Util.write! to_string value
        end
      end

      # define set all function
      setter_all = quote do
        def unquote(set_function_name)(:all, value) do
          for {port, _path, _type} <- EV3.Motors.get_all() do
            unquote(set_function_name)(port, value)
          end
        end
      end

      [setter_all, setter]

    end

    [getters, maybe_setters]

  end


  @doc """
  Overloads the function with another clause that matches `:all` as port and
  calls the given function for each port that has a connected motor.

  ## Note

  This macro requires that the first argument is exactly the variable `port`

  ## Example

  This:

      defall forward(port, speed) do
        run port, speed
      end

  expands to:

      def forward(:all, speed) do
        for {port, _path, _type} <- EV3.Motors.get_all() do
          forward(port, speed)
        end
      end

      def forward(port, speed) do
        run port, speed
      end

  """
  defmacro defall(function_header, do: block) do
    {name, metadata, [{:port, _, nil} | rest_args]} = function_header
    function_header_all = {name, metadata, [:all | rest_args]}

    quote do
      # define a function with `:all` as port
      def unquote(function_header_all) do
        for {port, _path, _type} <- EV3.Motors.get_all() do
          unquote({name, metadata, [Macro.var(:port, __MODULE__) | rest_args]})
        end
      end
      # define the actual funcation as it was given
      def unquote(function_header), do: unquote(block)
    end
  end

end

