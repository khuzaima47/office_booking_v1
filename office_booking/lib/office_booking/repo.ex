defmodule OfficeBooking.Repo do
  use Ecto.Repo,
    otp_app: :office_booking,
    adapter: Ecto.Adapters.Postgres
end
