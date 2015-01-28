defmodule EV3 do
  require Logger

  @type in_port :: :in1 | :in2 | :in3 | :in4
  @type out_port :: :outA | :outB | :outC | :outD

  def reload_modules do
    for {name,_} <- :code.all_loaded,
                    Regex.match?(~r/^Elixir.EV3/, to_string(name)) do
      :code.purge(name)
      :code.load_file(name)
    end
  end

end

