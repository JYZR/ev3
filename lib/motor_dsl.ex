defmodule EV3.MotorDSL do

  @doc """
  Defines get function and optionally set function for the given property

  ## Examples

      motor_property "run",        writable: true, min: 0, max: 1
      motor_property "duty_cycle", writable: false

  """
  defmacro motor_property(property, options \\ []) do
    quote do

      # define get function
      def unquote(String.to_atom("get_" <> property))(port) do
        EV3.Motors.get(port)
        |> elem(1)
        |> Path.join(unquote(property))
        |> EV3.Util.read!
        |> String.to_integer
      end

      # define set function
      if unquote(options)[:writable] == true do
        def unquote(String.to_atom("set_" <> property))(port, value) do
          opts = unquote(options)

          if opts[:min] != nil and value < opts[:min] do
            raise "Value is below minimum"
          end

          if opts[:max] != nil and value > opts[:max] do
            raise "Value is above maximum"
          end

          EV3.Motors.get(port)
          |> elem(1)
          |> Path.join(unquote(property))
          |> EV3.Util.write! to_string value
        end
      end

    end
  end
end

