defmodule Yatzy.DataCase do
  @moduledoc """
  Test case for tests that touch the database via `Yatzy.Repo`.

  Wraps each test in an `Ecto.Adapters.SQL.Sandbox` transaction so changes
  are rolled back on exit.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Yatzy.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Yatzy.DataCase
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Yatzy.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc "Render changeset errors into a `%{field => [messages]}` map."
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
