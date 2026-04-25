defmodule Mix.Tasks.Yatzy.AddUser do
  @moduledoc """
  Create a new Yatzy user from the command line.

      mix yatzy.add_user <username>

  Prompts twice for the password (input hidden).
  """
  @shortdoc "Add a Yatzy user"

  use Mix.Task

  alias Yatzy.Accounts

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    username =
      case args do
        [u | _] -> u
        [] -> Mix.shell().prompt("Username: ") |> String.trim()
      end

    if username == "" do
      Mix.raise("Username is required.")
    end

    if Accounts.get_user_by_username(username) do
      Mix.raise(~s|User "#{username}" already exists.|)
    end

    password = read_password_twice()

    case Accounts.register_user(%{username: username, password: password}) do
      {:ok, user} ->
        Mix.shell().info(~s|Created user "#{user.username}" (id #{user.id}).|)

      {:error, changeset} ->
        Mix.raise("Failed to create user: " <> format_errors(changeset))
    end
  end

  defp read_password_twice do
    pw1 = read_password("Password: ")
    pw2 = read_password("Confirm password: ")

    if pw1 != pw2 do
      Mix.raise("Passwords do not match.")
    end

    if String.length(pw1) < 6 do
      Mix.raise("Password must be at least 6 characters.")
    end

    pw1
  end

  defp read_password(prompt) do
    IO.write(prompt)
    pw = :io.get_password() |> to_string() |> String.trim_trailing("\n")
    IO.write("\n")
    pw
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    cs.errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
    |> Enum.join("; ")
  end
end
