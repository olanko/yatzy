# AltistYatzy

Phoenix LiveView app for keeping a Finnish Yatzy score sheet across multiple
players, persisting completed games and showing player statistics.

## Features

### Score sheet
- Live editable score sheet (`/`) with the Finnish Yatzy categories
  (Ykköset–Kuutoset, Pari, Kaksi paria, Kolme/Neljä samaa, Pieni/Iso suora,
  Täyskäsi, Sattuma, Yatzy).
- Per-category validation (allowed sums per category, e.g. Iso suora must be 20,
  Täyskäsi must be a valid `3a + 2b` sum); invalid cells get a red border and
  are excluded from totals until corrected.
- Välisumma, Bonus (+50 when upper section ≥ 63) and Summa rows update live.
- Inputs are disabled until a game is started.

### Players
- Left-side panel manages players. Add a registered user from a dropdown or
  add anonymous "vieras" (guest) players. Rename inline; remove with the × that
  appears on hover.

### Games
- **Aloita peli** opens a name + comment form and creates a `games` row plus a
  `game_scores` row for every player (registered users _and_ guests). Every
  score change persists for the whole game.
- **Lopeta peli** computes the winners, shows a celebratory banner with
  champagne 🍾 and fireworks 🎆🎇✨🎉, and clears the in-memory game (the DB
  rows stay).
- The active game is remembered across page reloads via `localStorage`; the
  LiveView reconstructs players + scores from the DB on mount.
- **Pelihistoria** (`/games`) lists ended games newest-first with date, time
  and comment. Each entry links to a static read-only sheet (`/games/:id`) that
  shows player rankings and a **Poista peli** button.

### Users & auth
- SQLite-backed `users` table with Argon2-hashed passwords.
- Login (`/login`), logout, and a registration page (`/users/new`,
  "Lisää käyttäjä" in the nav).
- **Omat asetukset** (`/settings`) lets the signed-in user change username and
  password.

### Statistics
- **Tilastot** (`/leaderboard`) ranks registered users by wins, then average,
  showing games played, wins, average, max score and the date of that max game.
- **User page** (`/users/:id`) shows summary cards, top 10 personal scores
  (linking back to each game) and a head-to-head table with win/loss/tie counts
  and win-% against every opponent the user has played alongside.

### Locale
- All times displayed in `Europe/Helsinki` (handled by `tzdata`).
- Finnish date/time formatting via `Yatzy.Locale` (e.g. `24.4.2026 klo 14:32`).

## Stack

Elixir / Phoenix 1.8 / LiveView, SQLite (`ecto_sqlite3`), Argon2 password
hashing, daisyUI on Tailwind v4, Bandit web server.

## Running locally

Requires Elixir 1.19+ and Erlang/OTP 28.

```sh
mix setup            # fetches deps, creates DB, runs migrations, seeds, builds assets
PORT=4002 mix phx.server
```

Then visit <http://localhost:4002>.

There is no seed user. Register the first account at
<http://localhost:4002/users/new>.

### Useful tasks

| Command                  | Purpose                                            |
|--------------------------|----------------------------------------------------|
| `mix ecto.setup`         | Create DB + run migrations + seed                  |
| `mix ecto.reset`         | Drop and recreate the DB from scratch              |
| `mix ecto.migrate`       | Apply pending migrations                           |
| `mix phx.server`         | Start the dev server (defaults to port 4000)       |
| `PORT=4002 mix phx.server` | Start on port 4002                               |
| `mix test`               | Run the test suite                                 |

The dev DB lives at `yatzy_dev.db` in the project root.

## Layout

```
lib/
  yatzy/
    accounts.ex            # context for users
    accounts/user.ex       # User schema + Argon2 changesets
    games.ex               # context for games + score persistence
    games/game.ex          # Game schema
    games/game_score.ex    # GameScore schema (one row per player per game)
    locale.ex              # Helsinki TZ + Finnish date/time formatting
    score_sheet.ex         # Pure scoring rules (validation, totals, bonus)
    stats.ex               # Leaderboard + per-user stats
  yatzy_web/
    live/                  # LiveViews: score sheet, settings, games list,
                           #            game detail, leaderboard, user stats,
                           #            registration
    user_auth.ex           # session plug + LiveView on_mount hooks
priv/repo/migrations/      # users, games, game_scores
```
