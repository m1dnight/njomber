defmodule Njomber.Repo do
  use Ecto.Repo,
    otp_app: :njomber,
    adapter: Ecto.Adapters.SQLite3
end
