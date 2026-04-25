defmodule Mix.Tasks.Yatzy.ChangePassword do
  @moduledoc """
  Change a Yatzy user's password from the command line.

      mix yatzy.change_password <username>

  Prompts twice for the new password (input hidden).
  """
  @shortdoc "Change a Yatzy user's password"

  use Mix.Task

  alias Yatzy.Accounts
  alias Yatzy.Accounts.User
  alias Yatzy.Repo

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    username =
      case args do
        [u | _] -> u
        [] -> Mix.shell().prompt("Username: ") |> String.trim()
      end

    user =
      Accounts.get_user_by_username(username) ||
        Mix.raise(~s|No user "#{username}".|)

    password = read_password_twice()

    changeset =
      User.password_changeset(user, %{
        "password" => password,
        "password_confirmation" => password
      })

    case Repo.update(changeset) do
      {:ok, _} ->
        Mix.shell().info(~s|Password updated for "#{user.username}".|)

      {:error, changeset} ->
        Mix.raise("Failed to change password: " <> format_errors(changeset))
    end
  end

  defp read_password_twice do
    pw1 = read_password("New password: ")
    pw2 = read_password("Confirm new password: ")

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
