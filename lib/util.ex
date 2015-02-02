defmodule EV3.Util do

  def read! path do
    File.read!(path) |> String.strip
  end

  def write! path, content do
    File.write! path, content
  end

  def string_to_integer_or_atom s do
  	try do
  		String.to_integer s
  	rescue _ ->
  		String.to_atom s
  	end
  end

  @doc """
  This macro takes a function where all parameters have default values and turns
  it into a function that instead takes a keyword list as argument.

  ## Note

  Every parameters must have a default value.

  ## Example

  A definition like this:

      def_as_opts get_color(port \\ :any, set_mode \\ true) do
          if set_mode == true do
            set_mode(port, :col_color)
          end
          get_values(port) |> color_from_integer
        end

  will have a signature like this:

      def get_color(opts \\ [port: :any, set_mode: true])

  """
  defmacro def_as_opts(function_header, do: block) do
    # Function header consists of three parts
    {name, metadata, args} = function_header
    # IO.puts "metadata: #{metadata}"
    # IO.puts "args: #{args}"
    # Create keyword list from the default values
    defaults = for {:\\, _, [{key, _, nil}, value]} <- args, do: {key, value}
    # Use the first argument's meta for the opts arg
    {_, arg_meta, _} = hd(args)
    # Compose the new list of arguments which consists only of one element
    # The argument will be named `opts` but has the context of __MODULE__ so it
    # will not be visible in the context where the macro will be expanded
    new_args = [{:\\, arg_meta, [{:opts, arg_meta, __MODULE__}, defaults]}]
    # The following generated code blocks will set the user variables to their
    # corresponding value in the options
    user_var_assignments = for {key, _value} <- defaults do
      user_var = Macro.var(key, nil)
      quote do
         unquote(user_var) = options[unquote(key)]
      end
    end

    quote do
      def unquote({name, metadata, new_args}) do
          options = Keyword.merge(unquote(defaults),
                                  unquote(Macro.var(:opts, __MODULE__)))
          unquote(user_var_assignments)
          unquote(block)
      end
      # define the function as it was given but without defaults
      # def unquote(function_header), do: unquote(block)
    end
  end

end
