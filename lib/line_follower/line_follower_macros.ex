defmodule EE.LineFollower.Macros do

  @doc """
  This:

      defstate state_1(state_data) do
        :my_event ->
          {:next_state, :state_2, state_data}
      end

  expands to:

      def state_1(event, state_data) do
        Logger.info("Received event '#\{event\}' when in state '#\{:state_1\}'")
        case event do
          :my_event ->
            {:next_state, :state_2, state_data}
          _ ->
            {:next_state, :state_1, state_data}
        end
      end

  """
  defmacro defstate(function_header, do: block) do
    {name, metadata, args} = function_header
    user_var_event = Macro.var(:event, nil)
    new_function_header = {name, metadata, [user_var_event | args]}

    case_block =
      {:case, [],
        [{:event, [], nil},
          [do:
            block
            ++
            [{:->, [],
              [[{:_, [], nil}],
                {:{}, [],
                  [:next_state, name, {:state_data, [], nil}]}]}]
          ]
        ]
      }

    quote do
      def unquote(new_function_header) do
        Logger.info("Received event '#{unquote(user_var_event)}'" <>
                    " when in state '#{unquote(name)}'")
        unquote(case_block)
      end
    end
  end
end
