defmodule OfficeBookingWeb.MessageComponents do
  use Phoenix.Component

  def unread_badge(assigns) do
    ~H"""
    <%= if @count > 0 do %>
      <span class="absolute -top-1 -right-1 inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-500 text-white">
        <%= @count %>
      </span>
    <% end %>
    """
  end
end
