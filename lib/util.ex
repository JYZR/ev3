defmodule EV3.Util do

  def read! path do
    File.read!(path) |> String.strip
  end

  def write! path, content do
    File.write! path, content
  end

end
