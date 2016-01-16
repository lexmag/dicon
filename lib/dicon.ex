defmodule Dicon do
  def config(key) do
    Application.fetch_env!(:dicon, key)
  end
end
