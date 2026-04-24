alias Yatzy.Accounts

case Accounts.get_user_by_username("olli") do
  nil ->
    {:ok, _user} = Accounts.register_user(%{username: "olli", password: "yatzyolli"})
    IO.puts("Created user 'olli'")

  _user ->
    IO.puts("User 'olli' already exists, skipping")
end
