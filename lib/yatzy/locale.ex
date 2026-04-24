defmodule Yatzy.Locale do
  @moduledoc "Finnish (Helsinki) date/time formatting helpers."

  @tz "Europe/Helsinki"
  @months ~w(tammikuuta helmikuuta maaliskuuta huhtikuuta toukokuuta kesäkuuta
             heinäkuuta elokuuta syyskuuta lokakuuta marraskuuta joulukuuta)

  @doc "Convert a UTC DateTime to Helsinki time. Returns DateTime."
  def to_local(%DateTime{} = dt) do
    case DateTime.shift_zone(dt, @tz) do
      {:ok, local} -> local
      _ -> dt
    end
  end

  @doc ~s|Format a DateTime in Helsinki time as "24.4.2026 klo 11:04".|
  def format_datetime(%DateTime{} = dt) do
    local = to_local(dt)
    "#{format_date(local)} klo #{pad(local.hour)}:#{pad(local.minute)}"
  end

  def format_datetime(nil), do: ""

  @doc ~s|Format as "24.4.2026" — works for Date or DateTime.|
  def format_date(%Date{} = d), do: "#{d.day}.#{d.month}.#{d.year}"
  def format_date(%DateTime{} = dt), do: format_date(DateTime.to_date(to_local(dt)))
  def format_date(nil), do: ""

  @doc ~s|Long form like "24. huhtikuuta 2026 klo 11:04".|
  def format_long(%DateTime{} = dt) do
    local = to_local(dt)
    month = Enum.at(@months, local.month - 1)
    "#{local.day}. #{month} #{local.year} klo #{pad(local.hour)}:#{pad(local.minute)}"
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: Integer.to_string(n)
end
