defmodule EV3.Util.GenFSM do

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour :gen_fsm

      @doc false
      def init(args) do
        {:ok, args[:init_state_name], args[:init_state]}
      end

      @doc false
      def handle_event(event, _state_name, state_data) do
        {:stop, {:bad_event, event}, state_data}
      end

      @doc false
      def handle_sync_event(event, _from, _state_name, state_data) do
        {:stop, {:bad_sync_event, event}, state_data}
      end

      @doc false
      def handle_info(_msg, state_name, state_data) do
        {:next_state, state_name, state_data}
      end

      @doc false
      def terminate(_reason, _state_name, _state_data) do
        :ok
      end

      @doc false
      def code_change(_old, state_name, state_data, _extra) do
        {:ok, state_name, state_data}
      end

      defoverridable [init: 1,
                      handle_event: 3,
                      handle_sync_event: 4,
                      handle_info: 3,
                      terminate: 3,
                      code_change: 4]
    end
  end

  def start_link(module, args, options \\ []) when is_atom(module) and is_list(options) do
    do_start(:link, module, args, options)
  end

  def start(module, args, options \\ []) when is_atom(module) and is_list(options) do
    do_start(:nolink, module, args, options)
  end

  defp do_start(link, module, args, options) do
    case Keyword.pop(options, :name) do
      {nil, opts} ->
        :gen.start(:gen_fsm, link, module, args, opts)
      {atom, opts} when is_atom(atom) ->
        :gen.start(:gen_fsm, link, {:local, atom}, module, args, opts)
      {other, opts} when is_tuple(other) ->
        :gen.start(:gen_fsm, link, other, module, args, opts)
    end
  end

  def send_event(fsm_ref, event) do
    :gen_fsm.send_event(fsm_ref, event)
  end

  def send_all_state_event(fsm_ref, event) do
    :gen_fsm.send_all_state_event(fsm_ref, event)
  end

end
