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

end
