defmodule OfficeBookingWeb.RoomLive.FormComponent do
  use OfficeBookingWeb, :live_component

  alias OfficeBooking.Rooms
  alias OfficeBooking.Rooms.RoomPhoto
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage room records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="room-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
      <div class="grid grid-cols-3 gap-x-4 gap-y-4">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <.input field={@form[:capacity]} type="number" label="Capacity" />
        <.input field={@form[:location]} type="text" label="Location" />
      </div>
      <.input field={@form[:is_active]} type="checkbox" label="Is active" />

        <!-- Features Section -->
        <div class="border-t pt-6">
          <h3 class="text-lg font-semibold mb-4">Features</h3>
          <div id="features-list">
            <.inputs_for :let={feature_form} field={@form[:features]}>
              <div class="flex gap-2 mb-4 items-start">
                <div class="flex-1">
                  <.input field={feature_form[:feature_name]} type="text" label="Feature" />
                </div>
                <div class="flex-1">
                  <.input field={feature_form[:description]} type="text" label="Description (optional)" />
                </div>
                <.input field={feature_form[:_action]} type="hidden" />
                <button
                  type="button"
                  phx-target={@myself}
                  phx-click="remove_feature"
                  phx-value-index={feature_form.index}
                  class="px-3 py-2 bg-red-500 text-white rounded hover:bg-red-600 mt-6"
                >
                  Remove
                </button>
              </div>
            </.inputs_for>
          </div>

          <button
            type="button"
            phx-target={@myself}
            phx-click="add_feature"
            class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            Add Feature
          </button>
        </div>

        <!-- Photo Upload Section -->
        <div class="border-t pt-6">
          <h3 class="text-lg font-semibold mb-4">Photos</h3>

          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Upload Room Photos (Max 5 files, 10MB each)
            </label>
            <.live_file_input upload={@uploads.room_photos} class="block w-full" />
          </div>

          <!-- Photo Previews -->
          <div class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-4">
            <div :for={entry <- @uploads.room_photos.entries} class="relative">
              <.live_img_preview entry={entry} class="w-full h-24 object-cover rounded" />
              <button
                type="button"
                phx-target={@myself}
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs hover:bg-red-600"
              >
                ×
              </button>

              <!-- Upload Progress -->
              <div :if={entry.progress < 100} class="absolute bottom-0 left-0 right-0 bg-blue-600 h-1">
                <div class="bg-blue-400 h-full" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
          </div>

          <!-- Existing Photos (for edit mode) -->
          <%= if @room.id && @room.photos != [] do %>
            <div class="border-t pt-4">
              <h4 class="text-md font-medium mb-3">Current Photos</h4>
              <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div :for={photo <- @room.photos} class="relative">
                  <img
                    src={OfficeBooking.Rooms.RoomPhoto.web_path(photo)}
                    alt="Room photo"
                    class="w-full h-24 object-cover rounded"
                  />

                  <div class="absolute top-2 left-2">
                    <%= if photo.is_primary do %>
                      <span class="bg-green-600 text-white text-xs px-2 py-1 rounded">Primary</span>
                    <% else %>
                      <button
                        type="button"
                        phx-target={@myself}
                        phx-click="set_primary_photo"
                        phx-value-photo-id={photo.id}
                        class="bg-blue-600 text-white text-xs px-2 py-1 rounded hover:bg-blue-700"
                      >
                        Set Primary
                      </button>
                    <% end %>
                  </div>

                  <button
                    type="button"
                    phx-target={@myself}
                    phx-click="delete_photo"
                    phx-value-photo-id={photo.id}
                    data-confirm="Delete this photo?"
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs hover:bg-red-600"
                  >
                    ×
                  </button>
                </div>
              </div>
            </div>
          <% end %>
          <!-- Upload Errors -->
          <div :for={err <- upload_errors(@uploads.room_photos)} class="text-red-600 text-sm">
            <%= error_to_string(err) %>
          </div>
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">Save Room</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end


  @impl true
  def update(%{room: room} = assigns, socket) do
    changeset = Rooms.change_room_with_features(room)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> OfficeBookingWeb.UploadHelpers.validate_image_upload(:room_photos, max_entries: 5)}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset =
      socket.assigns.room
      |> Rooms.change_room_with_features(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("add_feature", _params, socket) do
    # Get current form params for features
    current_features_params = get_features_params(socket)

    # Add a new empty feature
    new_index = map_size(current_features_params)
    updated_features_params = Map.put(current_features_params, to_string(new_index), %{
      "feature_name" => "",
      "description" => ""
    })

    # Create new changeset with updated features
    room_params = socket.assigns.form.params || %{}
    room_params = Map.put(room_params, "features", updated_features_params)

    changeset =
      socket.assigns.room
      |> Rooms.change_room_with_features(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("remove_feature", %{"index" => index_str}, socket) do
    # Get current features params and remove the specified index
    current_features_params = get_features_params(socket)
    updated_features_params =
      current_features_params
      |> Enum.reject(fn {key, _value} -> key == index_str end)
      |> Enum.with_index()
      |> Enum.map(fn {{_old_key, value}, new_index} -> {to_string(new_index), value} end)
      |> Map.new()

    # Create new changeset with updated features
    room_params = socket.assigns.form.params || %{}
    room_params = Map.put(room_params, "features", updated_features_params)

    changeset =
      socket.assigns.room
      |> Rooms.change_room_with_features(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp get_features_params(socket) do
    case socket.assigns.form.params["features"] do
      features_map when is_map(features_map) -> features_map
      features_list when is_list(features_list) ->
        # Convert list back to map format for form handling
        features_list
        |> Enum.with_index()
        |> Enum.map(fn {feature, index} -> {to_string(index), feature} end)
        |> Map.new()
      _ -> %{}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :room_photos, ref)}
  end

  def handle_event("delete_photo", %{"photo-id" => photo_id}, socket) do
    photo = Enum.find(socket.assigns.room.photos, &(&1.id == String.to_integer(photo_id)))
    {:ok, _} = Rooms.delete_room_photo(photo)

    updated_room = Rooms.get_room!(socket.assigns.room.id)
    {:noreply, assign(socket, :room, updated_room)}
  end

  def handle_event("set_primary_photo", %{"photo-id" => photo_id}, socket) do
    photo = Enum.find(socket.assigns.room.photos, &(&1.id == String.to_integer(photo_id)))
    {:ok, _} = Rooms.set_primary_photo(photo)

    updated_room = Rooms.get_room!(socket.assigns.room.id)
    {:noreply, assign(socket, :room, updated_room)}
  end

  def handle_event("save", %{"room" => room_params}, socket) do
    result = save_room(socket, socket.assigns.action, room_params)
    Logger.debug("Save result: #{inspect(result)}")
    result
  end

  defp save_room(socket, :edit, room_params) do

    case Rooms.update_room_with_features(socket.assigns.room, room_params) do
      {:ok, room} ->

        # Handle photo uploads
        case OfficeBookingWeb.UploadHelpers.process_uploaded_images(socket, :room_photos, room) do
          {:ok, photos} ->
            Logger.debug("Photos processed successfully: #{inspect(photos)}")
            notify_parent({:saved, room})
            {:noreply,
             socket
             |> put_flash(:info, "Room updated successfully")
             |> push_patch(to: socket.assigns.patch)}

          {:error, errors} ->
            Logger.error("Failed to upload photos: #{inspect(errors)}")
            {:noreply, put_flash(socket, :error, "Failed to upload some photos")}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to update room: #{inspect(changeset.errors)}")
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_room(socket, :new, room_params) do

    case Rooms.create_room_with_features(room_params) do
      {:ok, room} ->

        # Handle photo uploads
        Logger.debug("Processing uploaded images...")
        Logger.debug("Upload entries: #{inspect(socket.assigns.uploads.room_photos.entries)}")

        case OfficeBookingWeb.UploadHelpers.process_uploaded_images(socket, :room_photos, room) do
          {:ok, photos} ->
            Logger.debug("Photos processed successfully: #{inspect(photos)}")
            notify_parent({:saved, room})
            {:noreply,
            socket
            |> put_flash(:info, "Room created successfully")
            |> push_patch(to: socket.assigns.patch)}

          {:error, errors} ->
            Logger.error("Failed to upload photos: #{inspect(errors)}")
            {:noreply, put_flash(socket, :error, "Failed to upload some photos")}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to create room: #{inspect(changeset.errors)}")
        {:noreply, assign_form(socket, changeset)}
    end
  end


   defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

   defp notify_parent(msg) do
    Logger.debug("Notifying parent: #{inspect(msg)}")
    send(self(), {__MODULE__, msg})
  end

  # # Helper to convert features to params format
  # defp features_to_params(features) do
  #   features
  #   |> Enum.with_index()
  #   |> Enum.map(fn {feature, index} ->
  #     {to_string(index), feature}
  #   end)
  #   |> Map.new()
  # end

  # Helper to convert upload errors to readable strings
  defp error_to_string(:too_large), do: "File too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (only JPG, PNG, WebP)"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
