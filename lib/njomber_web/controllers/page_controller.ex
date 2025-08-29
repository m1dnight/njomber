defmodule NjomberWeb.PageController do
  use NjomberWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
