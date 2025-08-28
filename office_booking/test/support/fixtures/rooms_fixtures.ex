defmodule OfficeBooking.RoomsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `OfficeBooking.Rooms` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    {:ok, room} =
      attrs
      |> Enum.into(%{
        capacity: 42,
        description: "some description",
        is_active: true,
        location: "some location",
        name: "some name"
      })
      |> OfficeBooking.Rooms.create_room()

    room
  end
end
