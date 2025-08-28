defmodule OfficeBooking.BookingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `OfficeBooking.Bookings` context.
  """

  @doc """
  Generate a booking.
  """
  def booking_fixture(attrs \\ %{}) do
    {:ok, booking} =
      attrs
      |> Enum.into(%{
        description: "some description",
        end_datetime: ~U[2025-08-27 09:03:00Z],
        start_datetime: ~U[2025-08-27 09:03:00Z],
        status: "some status",
        title: "some title"
      })
      |> OfficeBooking.Bookings.create_booking()

    booking
  end
end
