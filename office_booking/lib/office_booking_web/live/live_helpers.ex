defmodule OfficeBookingWeb.LiveHelpers do
  @moduledoc """
  Helper functions for LiveView templates
  """

  alias OfficeBooking.Messaging

  def unread_message_count(user) when is_nil(user), do: 0
  def unread_message_count(user), do: Messaging.unread_count(user)
end
