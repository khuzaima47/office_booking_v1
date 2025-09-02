defmodule OfficeBooking.MessagingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `OfficeBooking.Messaging` context.
  """

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        content: "some content",
        read_at: ~U[2025-08-31 06:44:00Z],
        subject: "some subject"
      })
      |> OfficeBooking.Messaging.create_message()

    message
  end
end
