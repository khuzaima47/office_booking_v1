defmodule OfficeBooking.RoomsTest do
  use OfficeBooking.DataCase

  alias OfficeBooking.Rooms

  describe "rooms" do
    alias OfficeBooking.Rooms.Room

    import OfficeBooking.RoomsFixtures

    @invalid_attrs %{name: nil, description: nil, location: nil, capacity: nil, is_active: nil}

    test "list_rooms/0 returns all rooms" do
      room = room_fixture()
      assert Rooms.list_rooms() == [room]
    end

    test "get_room!/1 returns the room with given id" do
      room = room_fixture()
      assert Rooms.get_room!(room.id) == room
    end

    test "create_room/1 with valid data creates a room" do
      valid_attrs = %{name: "some name", description: "some description", location: "some location", capacity: 42, is_active: true}

      assert {:ok, %Room{} = room} = Rooms.create_room(valid_attrs)
      assert room.name == "some name"
      assert room.description == "some description"
      assert room.location == "some location"
      assert room.capacity == 42
      assert room.is_active == true
    end

    test "create_room/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rooms.create_room(@invalid_attrs)
    end

    test "update_room/2 with valid data updates the room" do
      room = room_fixture()
      update_attrs = %{name: "some updated name", description: "some updated description", location: "some updated location", capacity: 43, is_active: false}

      assert {:ok, %Room{} = room} = Rooms.update_room(room, update_attrs)
      assert room.name == "some updated name"
      assert room.description == "some updated description"
      assert room.location == "some updated location"
      assert room.capacity == 43
      assert room.is_active == false
    end

    test "update_room/2 with invalid data returns error changeset" do
      room = room_fixture()
      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(room, @invalid_attrs)
      assert room == Rooms.get_room!(room.id)
    end

    test "delete_room/1 deletes the room" do
      room = room_fixture()
      assert {:ok, %Room{}} = Rooms.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(room.id) end
    end

    test "change_room/1 returns a room changeset" do
      room = room_fixture()
      assert %Ecto.Changeset{} = Rooms.change_room(room)
    end
  end
end
