defmodule OfficeBookingWeb.MessageLive.Index do
  use OfficeBookingWeb, :live_view

  alias OfficeBooking.Messaging

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      # Subscribe to message updates
      Messaging.subscribe_to_user_messages(socket.assigns.current_user.id)

      socket =
        socket
        |> assign(:page_title, "Messages")
        |> load_conversations()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  # Handle real-time message updates
  @impl true
  def handle_info({action, _message}, socket) when action in [:created, :read, :deleted] do
    socket = load_conversations(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_read, _user_id}, socket) do
    socket = load_conversations(socket)
    {:noreply, socket}
  end

  defp load_conversations(socket) do
    conversations = Messaging.list_user_conversations(socket.assigns.current_user)
    unread_count = Messaging.unread_count(socket.assigns.current_user)

    socket
    |> assign(:conversations, conversations)
    |> assign(:unread_count, unread_count)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 py-8">
      <.header>
        Messages
        <%= if @unread_count > 0 do %>
          <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
            <%= @unread_count %> unread
          </span>
        <% end %>
        <:subtitle>Your conversations</:subtitle>
        <:actions>
          <.link navigate={~p"/messages/new"}>
            <.button>New Message</.button>
          </.link>
        </:actions>
      </.header>

      <%= if @conversations != [] do %>
        <div class="mt-8 bg-white shadow rounded-lg divide-y divide-gray-200">
          <div
            :for={conv <- @conversations}
            class="p-6 hover:bg-gray-50 cursor-pointer"
            phx-click={JS.navigate(~p"/messages/conversation/#{conv.other_user.id}")}
          >
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <div class="flex items-center">
                  <h3 class="text-lg font-medium text-gray-900">
                    <%= OfficeBooking.Accounts.User.full_name(conv.other_user) %>
                  </h3>

                  <%= if conv.unread_count > 0 do %>
                    <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      <%= conv.unread_count %> unread
                    </span>
                  <% end %>
                </div>

                <p class="mt-1 text-sm font-medium text-gray-600">
                  <%= conv.latest_message.subject %>
                </p>

                <p class="mt-1 text-sm text-gray-500 truncate max-w-lg">
                  <%= String.slice(conv.latest_message.content, 0, 100) %><%= if String.length(conv.latest_message.content) > 100, do: "..." %>
                </p>

                <div class="mt-2 flex items-center text-xs text-gray-400">
                  <span><%= OfficeBooking.Messaging.Message.format_timestamp(conv.latest_message) %></span>
                  <span class="mx-2">•</span>
                  <span><%= conv.message_count %> messages</span>
                </div>
              </div>

              <div class="ml-4">
                <svg class="h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
                </svg>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="mt-8 text-center py-12">
          <svg class="h-16 w-16 text-gray-400 mx-auto mb-4" fill="currentColor" viewBox="0 0 20 20">
            <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z"></path>
            <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z"></path>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No conversations yet</h3>
          <p class="text-gray-500 mb-4">
            Start a conversation by messaging other users about room bookings.
          </p>
          <.link navigate={~p"/messages/new"} class="text-indigo-600 hover:text-indigo-800">
            Send your first message
          </.link>
        </div>
      <% end %>
    </div>
    """
  end
end
