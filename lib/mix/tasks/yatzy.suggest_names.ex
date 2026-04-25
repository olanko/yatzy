defmodule Mix.Tasks.Yatzy.SuggestNames do
  @moduledoc """
  Print Haikunator-style Finnish game-name suggestions.

      mix yatzy.suggest_names           # 10 names (default)
      mix yatzy.suggest_names 25        # 25 names
  """
  @shortdoc "Print Finnish game-name suggestions"

  use Mix.Task

  alias Yatzy.NameGenerator

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    count =
      case args do
        [] ->
          10

        [raw | _] ->
          case Integer.parse(raw) do
            {n, ""} when n > 0 -> n
            _ -> Mix.raise("Count must be a positive integer, got: #{inspect(raw)}")
          end
      end

    for _ <- 1..count, do: Mix.shell().info(NameGenerator.generate())
  end
end
